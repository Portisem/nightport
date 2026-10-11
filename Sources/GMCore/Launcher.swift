import Foundation

/// Todo lo necesario para lanzar un juego, calculado antes de ejecutar nada (sirve para --dry-run).
public struct LaunchPlan {
    public var engine: Engine
    public var bottle: Bottle
    public var profile: GameProfile
    public var backend: GraphicsBackend
    public var arguments: [String]
    public var environment: [String: String]
    /// Comandos wine previos (p. ej. ajustes de registro).
    public var preSteps: [[String]]
    /// DLLs del traductor a copiar al prefix (solo motores "upstream").
    public var dllCopies: [(from: URL, to: URL)]
    public var logFile: URL
}

public enum Launcher {
    static let steamExe = #"C:\Program Files (x86)\Steam\steam.exe"#
    static let steamCommon = #"C:\Program Files (x86)\Steam\steamapps\common\"#

    public struct Overrides {
        public var backend: GraphicsBackend?
        public var metalHUD: Bool?
        public var wineDebug: String?
        public init(backend: GraphicsBackend? = nil, metalHUD: Bool? = nil, wineDebug: String? = nil) {
            self.backend = backend
            self.metalHUD = metalHUD
            self.wineDebug = wineDebug
        }
    }

    public static func plan(profile: GameProfile, engine: Engine, bottle: Bottle, overrides: Overrides = .init()) throws -> LaunchPlan {
        let backend = overrides.backend ?? profile.graphics?.backend ?? .d3dmetal

        // 1. Qué ejecutar
        var args: [String]
        let launch = profile.launch ?? .init(mode: .steam, exe: nil, args: nil)
        switch launch.mode {
        case .steam:
            guard let appId = profile.steamAppId else { throw GMError("El perfil \(profile.id) usa Steam pero no tiene steamAppId") }
            args = [steamExe, "-applaunch", String(appId)]
        case .exe:
            guard let exe = launch.exe else { throw GMError("El perfil \(profile.id) no define launch.exe") }
            args = [exe.contains(":\\") ? exe : steamCommon + exe]
        }
        args += launch.args ?? []

        // 2. Entorno: las perillas de rendimiento
        var env: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": overrides.wineDebug ?? profile.wineDebug ?? "-all",
            // Fix de CrossOver para apps .NET 7/8 bajo Rosetta
            "DOTNET_EnableWriteXorExecute": "0",
        ]
        switch profile.sync ?? .msync {
        case .msync: env["WINEMSYNC"] = "1"
        case .esync: env["WINEESYNC"] = "1"
        case .none: break
        }
        if profile.rosettaAVX ?? true { env["ROSETTA_ADVERTISE_AVX"] = "1" }
        if overrides.metalHUD ?? profile.metalHUD ?? false { env["MTL_HUD_ENABLED"] = "1" }

        var dllCopies: [(URL, URL)] = []
        var overridesDLL = profile.dllOverrides ?? [:]
        if backend == .d3dmetal {
            if let fx = profile.metalFX { env["D3DM_ENABLE_METALFX"] = fx ? "1" : "0" }
            if let dxr = profile.dxr { env["D3DM_SUPPORT_DXR"] = dxr ? "1" : "0" }
        }
        if engine.isCrossOverFlavor {
            // Motor propio: el traductor se elige anteponiendo su carpeta a la búsqueda de DLLs
            // (patches/wine/0001-dllpath-priority.patch, equivalente al prepend_dll_path de CrossOver).
            env["CX_ROOT"] = engine.root.path
            env["CX_ACTIVE_GRAPHICS_BACKEND"] = backend.rawValue
            let lib64 = engine.root.appendingPathComponent("lib64")
            env["DYLD_FALLBACK_LIBRARY_PATH"] = lib64.path + ":/usr/lib"
            env["GST_PLUGIN_SYSTEM_PATH"] = lib64.appendingPathComponent("gstreamer-1.0").path
            // DLLs que el motor agrega después de crear el bottle: sin su copia en system32
            // Wine no las considera instaladas (p. ej. winemetal.dll de DXMT).
            for (arch, dir) in [("x86_64-windows", "system32"), ("i386-windows", "syswow64")] {
                let src = engine.root.appendingPathComponent("lib/wine/\(arch)/winemetal.dll")
                if FileManager.default.fileExists(atPath: src.path) {
                    dllCopies.append((src, bottle.driveC.appendingPathComponent("windows/\(dir)/winemetal.dll")))
                }
            }
            if backend != .wined3d {
                guard let dir = engine.backendDirectory(backend) else {
                    throw GMError("El motor \(engine.name) no trae \(backend.rawValue). Disponibles: \(engine.availableBackends.map(\.rawValue))")
                }
                env["WINEDLLPATH_PRIORITY"] = dir.path
            }
            if backend == .d3dmetal, let dir = engine.backendDirectory(.d3dmetal) {
                env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = dir.deletingLastPathComponent()
                    .appendingPathComponent("external/libd3dshared.dylib").path
                // Read Me del GPTK: nvngx.dll (DLSS→MetalFX) y nvapi64.dll deben estar en system32
                if profile.metalFX == true {
                    let system32 = bottle.driveC.appendingPathComponent("windows/system32")
                    for name in ["nvngx.dll", "nvapi64.dll"] {
                        dllCopies.append((dir.appendingPathComponent("x86_64-windows/\(name)"), system32.appendingPathComponent(name)))
                    }
                }
            }
        } else {
            guard backend != .d3dmetal else {
                throw GMError("D3DMetal necesita un motor 'crossover' (Wine con parches CX). Usa --backend dxmt|dxvk o cambia de motor.")
            }
            if backend != .wined3d, let dir = engine.backendDirectory(backend) {
                let pairs = [("x86_64-windows", "windows/system32"), ("i386-windows", "windows/syswow64")]
                for (src, dst) in pairs {
                    let srcDir = dir.appendingPathComponent(src)
                    let dlls = (try? FileManager.default.contentsOfDirectory(at: srcDir, includingPropertiesForKeys: nil)) ?? []
                    for dll in dlls where dll.pathExtension == "dll" {
                        dllCopies.append((dll, bottle.driveC.appendingPathComponent(dst).appendingPathComponent(dll.lastPathComponent)))
                        overridesDLL[dll.deletingPathExtension().lastPathComponent] = "n,b"
                    }
                }
            }
        }
        if !overridesDLL.isEmpty {
            env["WINEDLLOVERRIDES"] = overridesDLL.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
        }
        env.merge(profile.env ?? [:]) { _, new in new }

        // 3. Ajustes de registro previos
        var pre: [[String]] = []
        if let retina = profile.retina {
            pre.append(["reg", "add", #"HKCU\Software\Wine\Mac Driver"#, "/v", "RetinaMode", "/t", "REG_SZ", "/d", retina ? "y" : "n", "/f"])
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let log = Paths.logs.appendingPathComponent("\(profile.id)-\(backend.rawValue)-\(stamp).log")
        return LaunchPlan(engine: engine, bottle: bottle, profile: profile, backend: backend,
                          arguments: args, environment: env, preSteps: pre, dllCopies: dllCopies, logFile: log)
    }

    public static func execute(_ plan: LaunchPlan) throws -> Int32 {
        try prepare(plan)
        return try Shell.run(plan.engine.wine, plan.arguments, environment: plan.environment, log: plan.logFile)
    }

    /// Lanza sin esperar (p. ej. Steam). Devuelve el pid.
    public static func spawn(_ plan: LaunchPlan) throws -> Int32 {
        try prepare(plan)
        return try Shell.spawn(plan.engine.wine, plan.arguments, environment: plan.environment, log: plan.logFile)
    }

    /// Copia DLLs, escribe la cabecera del log y corre los pasos previos.
    static func prepare(_ plan: LaunchPlan) throws {
        try Paths.ensure(Paths.logs)
        let fm = FileManager.default
        for (from, to) in plan.dllCopies {
            if fm.contentsEqual(atPath: from.path, andPath: to.path) { continue }
            if fm.fileExists(atPath: to.path) {
                let backup = to.appendingPathExtension("gmac-orig")
                if !fm.fileExists(atPath: backup.path) { try fm.copyItem(at: to, to: backup) }
                try fm.removeItem(at: to)
            }
            try fm.copyItem(at: from, to: to)
        }
        let header = "# gmac \(plan.profile.id) backend=\(plan.backend.rawValue) engine=\(plan.engine.name)\n"
            + Shell.describe(plan.engine.wine, plan.arguments, environment: plan.environment) + "\n\n"
        try header.write(to: plan.logFile, atomically: true, encoding: .utf8)
        // Mismo entorno que el juego: si el wineserver arranca sin WINEMSYNC, el juego ya no puede conectarse.
        let baseEnv = plan.environment.merging(["WINEDEBUG": "-all"]) { _, n in n }
        for step in plan.preSteps {
            try Shell.run(plan.engine.wine, step, environment: baseEnv, log: plan.logFile)
        }
    }
}
