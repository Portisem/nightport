import Foundation

public enum Steam {
    public static let installerURL = URL(string: "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe")!

    /// Descarga SteamSetup.exe (oficial de Valve) y lo instala en silencio dentro del bottle.
    public static func install(into bottle: Bottle, engine: Engine) throws {
        if bottle.steamInstalled { print("Steam ya está instalado en \(bottle.name)"); return }
        let dir = Paths.appSupport.appendingPathComponent("Downloads/steam")
        try Paths.ensure(dir)
        try Paths.ensure(Paths.logs)
        let setup = dir.appendingPathComponent("SteamSetup.exe")
        if !FileManager.default.fileExists(atPath: setup.path) {
            print("Descargando SteamSetup.exe…")
            guard try Shell.run(URL(fileURLWithPath: "/usr/bin/curl"), ["-fsSL", "-o", setup.path, installerURL.absoluteString]) == 0 else {
                throw GMError("No se pudo descargar SteamSetup.exe")
            }
        }
        let log = Paths.logs.appendingPathComponent("steam-install-\(bottle.name).log")
        print("Instalando Steam en \(bottle.name)… (log: \(log.path))")
        let env = engineEnvironment(engine).merging(["WINEPREFIX": bottle.url.path, "WINEMSYNC": "1"]) { _, n in n }
        let code = try Shell.run(engine.wine, [setup.path, "/S"], environment: env, log: log)
        try Shell.run(engine.wineserver, ["-w"], environment: env, log: log)
        guard code == 0, bottle.steamInstalled else { throw GMError("La instalación de Steam falló (código \(code)). Revisa \(log.path)") }
    }

    /// Enlaza los juegos ya descargados en un bottle de CrossOver: symlink de la carpeta del juego
    /// + copia del appmanifest. Steam los ve como instalados y solo verifica archivos.
    @discardableResult
    public static func linkLibrary(from crossOverBottle: String, into bottle: Bottle) throws -> [String] {
        let fm = FileManager.default
        let src = Paths.crossOverBottles.appendingPathComponent(crossOverBottle)
            .appendingPathComponent("drive_c/Program Files (x86)/Steam/steamapps")
        guard fm.fileExists(atPath: src.path) else { throw GMError("No encuentro la biblioteca de Steam en \(src.path)") }
        let dst = bottle.steamDirectory.appendingPathComponent("steamapps")
        try Paths.ensure(dst.appendingPathComponent("common"))

        var linked: [String] = []
        let manifests = try fm.contentsOfDirectory(atPath: src.path).filter { $0.hasPrefix("appmanifest_") && $0.hasSuffix(".acf") }
        for manifest in manifests.sorted() {
            let text = try String(contentsOf: src.appendingPathComponent(manifest), encoding: .utf8)
            guard let installdir = value(of: "installdir", in: text) else { continue }
            let gameSrc = src.appendingPathComponent("common/\(installdir)")
            let gameDst = dst.appendingPathComponent("common/\(installdir)")
            guard fm.fileExists(atPath: gameSrc.path) else { continue }
            if (try? fm.destinationOfSymbolicLink(atPath: gameDst.path)) == nil, !fm.fileExists(atPath: gameDst.path) {
                try fm.createSymbolicLink(at: gameDst, withDestinationURL: gameSrc)
            }
            let acfDst = dst.appendingPathComponent(manifest)
            if !fm.fileExists(atPath: acfDst.path) {
                try fm.copyItem(at: src.appendingPathComponent(manifest), to: acfDst)
            }
            linked.append("\(value(of: "name", in: text) ?? installdir) (\(manifest))")
        }
        return linked
    }

    /// Abre el cliente de Steam con el perfil steam-client (UI de CEF configurada como CrossOver).
    @discardableResult
    public static func start(bottle: Bottle, engine: Engine, overrides: Launcher.Overrides = .init()) throws -> LaunchPlan {
        let plan = try Launcher.plan(profile: try ProfileStore.resolved("steam-client"), engine: engine, bottle: bottle, overrides: overrides)
        _ = try Launcher.spawn(plan)
        return plan
    }

    /// ¿Hay un steam.exe corriendo (en cualquier bottle)?
    public static var isRunning: Bool {
        (Shell.output("/usr/bin/pgrep", ["-f", #"Steam\\steam\.exe"#]) ?? "").isEmpty == false
    }

    /// Variables que el motor necesita para encontrar sus dylibs (también fuera de un juego).
    public static func engineEnvironment(_ engine: Engine) -> [String: String] {
        guard engine.isCrossOverFlavor else { return [:] }
        let lib64 = engine.root.appendingPathComponent("lib64")
        return ["DYLD_FALLBACK_LIBRARY_PATH": lib64.path + ":/usr/lib",
                "GST_PLUGIN_SYSTEM_PATH": lib64.appendingPathComponent("gstreamer-1.0").path]
    }

    /// Lee `"clave"   "valor"` de un archivo VDF/ACF de Steam.
    static func value(of key: String, in vdf: String) -> String? {
        for line in vdf.split(separator: "\n") {
            let parts = line.split(separator: "\"", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if parts.count >= 2, parts[0] == key { return parts[1] }
        }
        return nil
    }
}
