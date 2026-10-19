import Foundation
import GMCore

let usage = """
gmac: lanzador de juegos Windows para macOS (GamingMac)

  gmac doctor                          Revisa sistema, motores y bottles
  gmac profiles                        Lista los perfiles curados por juego
  gmac profile <id>                    Muestra el perfil resuelto (defaults + juego)
  gmac check <perfil|appid> [--backend B]  ¿Qué tan bien correría en esta Mac? (requisitos de Steam)
  gmac monitor <perfil> [--bottle B]   Graba la sesión de un juego que ya está abierto
  gmac sessions [perfil]               Sesiones grabadas: FPS, CPU, GPU, memoria y sugerencias
  gmac engines                         Lista motores instalados y sus traductores
  gmac bottles                         Lista bottles
  gmac bottle create <nombre> [--engine E] [--winver win10]
  gmac run <perfil> [--bottle B] [--engine E] [--backend d3dmetal|dxmt|dxvk|wined3d]
                    [--hud] [--debug CANALES] [--dry-run]
  gmac steam install <bottle> [--engine E]     Descarga e instala Steam (Windows) en el bottle
  gmac steam link <bottle> [--from Steam]      Enlaza juegos ya descargados en CrossOver (sin duplicar)
  gmac steam start <bottle> [--backend B]      Abre Steam en el bottle (no espera; UI con DXMT)
  gmac steam games <bottle>                    Juegos instalados en el Steam del bottle (y su perfil)
  gmac steam get <bottle> <appid>              Abre el diálogo de instalación de Steam para ese juego
  gmac exec <bottle> [--engine E] -- <args de wine…>
"""

struct Args {
    var positional: [String] = []
    var options: [String: String] = [:]
    var flags: Set<String> = []
    var passthrough: [String] = []

    init(_ raw: [String]) {
        var i = 0
        while i < raw.count {
            let a = raw[i]
            if a == "--" { passthrough = Array(raw[(i + 1)...]); break }
            if a.hasPrefix("--") {
                let key = String(a.dropFirst(2))
                if ["hud", "dry-run", "no-record"].contains(key) {
                    flags.insert(key)
                } else if i + 1 < raw.count {
                    options[key] = raw[i + 1]
                    i += 1
                }
            } else {
                positional.append(a)
            }
            i += 1
        }
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("error: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

func pretty<T: Encodable>(_ value: T) -> String {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return (try? String(data: enc.encode(value), encoding: .utf8) ?? "") ?? ""
}

func bottleForRun(_ name: String?) throws -> Bottle {
    if let name {
        let b = Bottle.named(name)
        guard FileManager.default.fileExists(atPath: b.url.path) else { throw GMError("No existe el bottle '\(name)'") }
        return b
    }
    guard let first = Bottle.list().first else { throw GMError("No hay bottles. Crea uno: gmac bottle create Steam") }
    return first
}

let args = Args(Array(CommandLine.arguments.dropFirst()))

func warnIfDisplayAsleep() {
    if Doctor.displayAsleep {
        print("⚠️  La pantalla está dormida o la sesión bloqueada: Steam y los juegos se congelan hasta que la desbloquees.")
    }
}
func printSession(_ s: SessionSummary, candidates: [GraphicsBackend] = []) {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    let mins = Int(s.duration / 60)
    var parts = ["\(f.string(from: s.start))", "\(mins) min", s.backend]
    if let a = s.avgFPS { parts.append("\(Int(a)) FPS (5% bajo \(Int(s.lowFPS ?? a)))") }
    parts.append("CPU \(Int(s.avgCPU))%")
    if let g = s.avgGPU { parts.append("GPU \(Int(g))%") }
    parts.append("mem \(String(format: "%.1f", s.peakMemoryMB / 1024)) GB")
    if s.maxThermal >= 2 { parts.append("🔥") }
    if s.crashed { parts.append("💥 error") }
    print("  \(s.name): " + parts.joined(separator: " · "))
    for i in SessionInsights.analyze(s, candidates: candidates) { print("     → \(i.text)") }
}

/// Graba en un hilo aparte; `wait()` bloquea hasta que el juego se cierra.
func startRecording(_ recorder: SessionRecorder?, live: Bool) -> DispatchGroup {
    let group = DispatchGroup()
    guard let recorder else { return group }
    group.enter()
    Thread.detachNewThread {
        defer { group.leave() }
        do {
            let summary = try recorder.run { sample in
                guard live else { return }
                let fps = sample.fps.map { "\(Int($0)) FPS · " } ?? ""
                print("  \(Int(sample.t))s · \(fps)CPU \(Int(sample.cpu))% · GPU \(sample.gpu.map { "\(Int($0))%" } ?? "?") · \(Int(sample.memoryMB)) MB")
            }
            if let summary {
                print("\nSesión grabada:")
                printSession(summary, candidates: recorder.profile.graphics?.candidates ?? [])
            } else {
                print("No se grabó sesión (el juego no apareció o duró menos de 10 s).")
            }
        } catch {
            print("No se pudo grabar la sesión: \(error)")
        }
    }
    return group
}

guard let command = args.positional.first else { print(usage); exit(0) }

do {
    switch command {
    case "doctor":
        for c in Doctor.run() {
            let mark = c.ok == nil ? "·" : (c.ok! ? "✓" : "✗")
            print("\(mark) \(c.title.padding(toLength: 38, withPad: " ", startingAt: 0)) \(c.detail)")
        }

    case "profiles":
        for p in try ProfileStore.loadAll() where p.id != "_defaults" {
            let backend = p.graphics?.backend.rawValue ?? "default"
            print("\(p.id.padding(toLength: 26, withPad: " ", startingAt: 0)) \((p.status ?? "?").padding(toLength: 10, withPad: " ", startingAt: 0)) \(backend.padding(toLength: 9, withPad: " ", startingAt: 0)) \(p.name)")
        }

    case "profile":
        guard args.positional.count > 1 else { fail("uso: gmac profile <id>") }
        print(pretty(try ProfileStore.resolved(args.positional[1])))

    case "check":
        guard args.positional.count > 1 else { fail("uso: gmac check <perfil|appid>") }
        let bottle = try? bottleForRun(args.options["bottle"])
        let key = args.positional[1]
        let profile = try ProfileStore.resolved(Int(key).map(GameProfile.autoID) ?? key, bottle: bottle)
        let backend = args.options["backend"].flatMap(GraphicsBackend.init(rawValue:)) ?? profile.graphics?.backend ?? .d3dmetal
        let mac = MacSpecs.current()
        let installed = profile.steamAppId.map { id in bottle.map { Steam.installedApps(in: $0).contains { $0.appId == id } } ?? false } ?? true
        var requirements: GameRequirements?
        if let appId = profile.steamAppId {
            // main.swift sin await: así el resto del CLI puede bloquear esperando al grabador
            let done = DispatchSemaphore(value: 0)
            Task.detached { requirements = await Requirements.load(appId: appId); done.signal() }
            done.wait()
        }
        let r = Capability.report(profile: profile, requirements: requirements, mac: mac, backend: backend, installed: installed)
        print("▶ \(profile.name)  [traductor \(backend.rawValue), ×\(Capability.overhead(backend)) de costo]")
        print("  Tu Mac: \(Capability.macSummary(mac))")
        print("  \(r.level?.label ?? "Sin veredicto"): \(r.summary)")
        for row in r.rows {
            print("  · \(row.resource.padding(toLength: 15, withPad: " ", startingAt: 0)) \(row.level?.label ?? "—")")
            print("      tu Mac: \(row.mac)")
            if let m = row.minimum { print("      mínimo: \(m)") }
            if let rec = row.recommended { print("      recomendado: \(rec)") }
        }
        if let m = r.recommendedMac { print("  Mac recomendada: \(m)") }
        r.warnings.forEach { print("  ⚠️  \($0)") }

    case "monitor":
        guard args.positional.count > 1 else { fail("uso: gmac monitor <perfil>") }
        let bottle = try bottleForRun(args.options["bottle"])
        let profile = try ProfileStore.resolved(args.positional[1], bottle: bottle)
        guard let recorder = SessionRecorder.attach(profile: profile, bottle: bottle) else { fail("No sé qué proceso buscar para \(profile.id)") }
        print("▶ Grabando \(profile.name) (proceso: \(recorder.processMatch)). Ctrl-C para cancelar.")
        startRecording(recorder, live: true).wait()

    case "sessions":
        let sessions = SessionStore.list(profileId: args.positional.count > 1 ? args.positional[1] : nil)
        if sessions.isEmpty { print("Sin sesiones grabadas todavía en \(SessionStore.directory.path)") }
        let profiles = (try? ProfileStore.loadAll()) ?? []
        for s in sessions {
            printSession(s, candidates: profiles.first { $0.id == s.profileId }?.graphics?.candidates ?? [])
        }
        for (id, list) in Dictionary(grouping: sessions, by: \.profileId) {
            if let cmp = SessionInsights.backendComparison(list) { print("  \(id): \(cmp)") }
        }

    case "engines":
        let engines = Engine.list()
        if engines.isEmpty { print("Sin motores en \(Paths.engines.path). Ver docs/MOTOR.md") }
        for e in engines {
            print("\(e.name) [\(e.manifest.flavor)] wine \(e.manifest.wineVersion ?? "?") → \(e.availableBackends.map(\.rawValue).joined(separator: ", "))")
            print("  \(e.root.path)")
        }

    case "bottles":
        for b in Bottle.list() {
            let meta = b.metadata.map { "\($0.engine), \($0.windowsVersion)" } ?? "sin metadata"
            print("\(b.name)  (\(meta))  steam: \(b.steamInstalled ? "sí" : "no")")
        }

    case "bottle":
        guard args.positional.count > 2, args.positional[1] == "create" else { fail("uso: gmac bottle create <nombre>") }
        let engine = try Engine.find(args.options["engine"])
        let b = try Bottle.create(args.positional[2], engine: engine, windowsVersion: args.options["winver"] ?? "win10")
        print("Bottle listo: \(b.url.path)")

    case "run":
        guard args.positional.count > 1 else { fail("uso: gmac run <perfil>") }
        let profile = try ProfileStore.resolved(args.positional[1], bottle: try? bottleForRun(args.options["bottle"]))
        var overrides = Launcher.Overrides(metalHUD: args.flags.contains("hud") ? true : nil, wineDebug: args.options["debug"])
        if let b = args.options["backend"] {
            guard let backend = GraphicsBackend(rawValue: b) else { fail("backend inválido: \(b)") }
            overrides.backend = backend
        }
        let dry = args.flags.contains("dry-run")
        let engine: Engine
        let bottle: Bottle
        if dry && Engine.list().isEmpty {
            // Permite revisar el plan aunque todavía no haya motor instalado
            engine = Engine(root: Paths.engines.appendingPathComponent("(sin-motor)"),
                            manifest: .init(name: "(sin-motor)", flavor: "crossover", wineVersion: nil, notes: nil))
            bottle = (try? bottleForRun(args.options["bottle"])) ?? Bottle.named(args.options["bottle"] ?? "Steam")
        } else {
            engine = try Engine.find(args.options["engine"])
            bottle = try bottleForRun(args.options["bottle"])
        }
        let plan = try Launcher.plan(profile: profile, engine: engine, bottle: bottle, overrides: overrides)
        print("▶ \(profile.name)  [backend: \(plan.backend.rawValue), motor: \(engine.name), bottle: \(bottle.name)]")
        for n in profile.notes ?? [] { print("  • \(n)") }
        if dry {
            for step in plan.preSteps { print("\npre: wine " + step.joined(separator: " ")) }
            for c in plan.dllCopies { print("copiar: \(c.from.lastPathComponent) → \(c.to.path)") }
            print("\n" + Shell.describe(engine.wine, plan.arguments, environment: plan.environment))
            exit(0)
        }
        warnIfDisplayAsleep()
        print("  log: \(plan.logFile.path)")
        // El grabador busca el log de Steam después de lanzar: se crea antes de que el juego aparezca.
        let recording = args.flags.contains("no-record") ? DispatchGroup() : startRecording(SessionRecorder(plan: plan), live: false)
        let code = try Launcher.execute(plan)
        print("Terminó con código \(code)")
        recording.wait()

    case "steam":
        guard args.positional.count > 2 else { fail("uso: gmac steam install|link|start|games|get <bottle>") }
        let bottle = try bottleForRun(args.positional[2])
        switch args.positional[1] {
        case "install":
            try Steam.install(into: bottle, engine: try Engine.find(args.options["engine"]))
            print("Steam instalado en \(bottle.name)")
        case "link":
            let linked = try Steam.linkLibrary(from: args.options["from"] ?? "Steam", into: bottle)
            print("Enlazados \(linked.count) juegos:")
            linked.forEach { print("  • \($0)") }
        case "start":
            warnIfDisplayAsleep()
            let engine = try Engine.find(args.options["engine"])
            var overrides = Launcher.Overrides(wineDebug: args.options["debug"])
            if let b = args.options["backend"] {
                guard let backend = GraphicsBackend(rawValue: b) else { fail("backend inválido: \(b)") }
                overrides.backend = backend
            }
            let plan = try Steam.start(bottle: bottle, engine: engine, overrides: overrides)
            print("Steam iniciado (traductor \(plan.backend.rawValue)). Log: \(plan.logFile.path)")
        case "games":
            let curated = try ProfileStore.loadAll()
            for app in Steam.installedApps(in: bottle) {
                let id = curated.first { $0.steamAppId == app.appId }?.id ?? GameProfile.autoID(app.appId)
                print("\(String(app.appId).padding(toLength: 9, withPad: " ", startingAt: 0)) \(id.padding(toLength: 26, withPad: " ", startingAt: 0)) \(app.name)")
            }
        case "get":
            guard args.positional.count > 3, let appId = Int(args.positional[3]) else { fail("uso: gmac steam get <bottle> <appid>") }
            warnIfDisplayAsleep()
            try Steam.requestInstall(appId: appId, bottle: bottle, engine: try Engine.find(args.options["engine"]))
            print("Confirma la instalación en la ventana de Steam.")
        default:
            fail("uso: gmac steam install|link|start|games|get <bottle>")
        }

    case "exec":
        guard args.positional.count > 1, !args.passthrough.isEmpty else { fail("uso: gmac exec <bottle> -- <args>") }
        let engine = try Engine.find(args.options["engine"])
        let bottle = try bottleForRun(args.positional[1])
        let env = Steam.engineEnvironment(engine).merging(["WINEPREFIX": bottle.url.path, "WINEMSYNC": "1"]) { _, n in n }
        let code = try Shell.run(engine.wine, args.passthrough, environment: env)
        exit(code)

    default:
        print(usage)
        exit(1)
    }
} catch {
    fail("\(error)")
}
