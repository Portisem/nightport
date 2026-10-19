import Foundation

// Registro de sesiones de juego: mientras el juego corre se muestrea CPU, memoria, GPU, FPS y
// temperatura cada pocos segundos. Al cerrar queda un resumen + las muestras en
// ~/Library/Application Support/GamingMac/Sessions/. Todo es local: nada sale de la Mac.

public struct SessionSample: Codable {
    public var t: Double              // segundos desde el inicio
    public var cpu: Double            // % de CPU del juego (100 = un núcleo completo)
    public var memoryMB: Double       // memoria residente del juego
    public var gpu: Double?           // % de uso de la GPU (de todo el sistema)
    public var gpuMemoryMB: Double?   // memoria que la GPU tiene en uso
    public var fps: Double?
    public var thermal: Int           // 0 normal · 1 templado · 2 serio · 3 crítico
}

public struct SessionSummary: Codable, Identifiable {
    public var id: String
    public var profileId: String
    public var name: String
    public var backend: String
    public var start: Date
    public var end: Date
    public var duration: Double
    public var avgFPS: Double?
    public var lowFPS: Double?        // percentil 5 de las muestras de 1 s (≈ "1% low")
    public var minFPS: Double?
    public var avgCPU: Double
    public var peakCPU: Double
    public var peakMemoryMB: Double
    public var avgGPU: Double?
    public var peakGPU: Double?
    public var maxThermal: Int
    public var crashed: Bool
    public var mac: String
    public var macMemoryGB: Double
    public var samples: Int
}

public enum SessionStore {
    public static var directory: URL { Paths.appSupport.appendingPathComponent("Sessions") }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Resúmenes, del más reciente al más viejo.
    public static func list(profileId: String? = nil) -> [SessionSummary] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.lastPathComponent.hasSuffix(".summary.json") }
            .compactMap { try? decoder.decode(SessionSummary.self, from: Data(contentsOf: $0)) }
            .filter { profileId == nil || $0.profileId == profileId }
            .sorted { $0.start > $1.start }
    }

    public static func samplesURL(_ id: String) -> URL { directory.appendingPathComponent("\(id).samples.jsonl") }

    static func save(_ s: SessionSummary) throws {
        try Paths.ensure(directory)
        try encoder.encode(s).write(to: directory.appendingPathComponent("\(s.id).summary.json"))
    }
}

/// Graba una sesión: espera a que aparezca el proceso del juego y muestrea hasta que se cierre.
public final class SessionRecorder {
    public let profile: GameProfile
    public let backend: GraphicsBackend
    /// Fragmento (sin mayúsculas) de la línea de comandos de los procesos del juego.
    public let processMatch: String
    /// Log donde aparecen los FPS: trazas `fps` de wined3d o líneas `metal-HUD:` del HUD de Metal
    /// (el log del juego, o el de Steam si lo lanza Steam).
    let fpsLog: URL?
    public var interval: TimeInterval = 2

    public init(profile: GameProfile, backend: GraphicsBackend, processMatch: String, fpsLog: URL?) {
        self.profile = profile
        self.backend = backend
        self.processMatch = processMatch.lowercased()
        self.fpsLog = fpsLog
    }

    /// Para un plan de lanzamiento: identifica los procesos por la carpeta del juego.
    public convenience init?(plan: LaunchPlan) {
        guard let match = Self.processMatch(for: plan.profile, bottle: plan.bottle) else { return nil }
        let viaSteam = (plan.profile.launch?.mode ?? .steam) == .steam
        self.init(profile: plan.profile, backend: viaSteam ? .wined3d : plan.backend, processMatch: match,
                  fpsLog: viaSteam ? Self.latestSteamLog() : plan.logFile)
    }

    /// Para un juego que ya está corriendo (o por arrancar): proceso + log de FPS según cómo se lanza.
    public static func attach(profile: GameProfile, bottle: Bottle) -> SessionRecorder? {
        guard let match = processMatch(for: profile, bottle: bottle) else { return nil }
        let viaSteam = (profile.launch?.mode ?? .steam) == .steam
        let log = viaSteam ? latestSteamLog() : latestLog(prefix: profile.id + "-")
        return SessionRecorder(profile: profile, backend: viaSteam ? .wined3d : (profile.graphics?.backend ?? .d3dmetal),
                               processMatch: match, fpsLog: log)
    }

    /// El primero de `profiles` que tiene procesos corriendo ahora (una sola llamada a ps).
    public static func runningGame(among profiles: [GameProfile], bottle: Bottle) -> GameProfile? {
        let candidates = profiles.compactMap { p in processMatch(for: p, bottle: bottle).map { (p, $0.lowercased()) } }
        guard !candidates.isEmpty, let ps = Shell.output("/bin/ps", ["-axo", "command="]) else { return nil }
        let wine = ps.lowercased().split(separator: "\n").filter { $0.range(of: #"^[a-z]:\\"#, options: .regularExpression) != nil }
        return candidates.first { c in wine.contains { $0.contains(c.1) && !$0.contains("start.exe") } }?.0
    }

    /// `steamapps\common\<carpeta>\` o la ruta del ejecutable propio.
    public static func processMatch(for profile: GameProfile, bottle: Bottle) -> String? {
        if let exe = profile.launch?.exe, profile.launch?.mode == .exe {
            if exe.contains(":\\") { return (exe as NSString).lastPathComponent }
            return #"steamapps\common\"# + (exe.split(separator: "\\").first.map(String.init) ?? exe) + "\\"
        }
        guard let appId = profile.steamAppId,
              let app = Steam.installedApps(in: bottle).first(where: { $0.appId == appId }) else { return nil }
        return #"steamapps\common\"# + app.installdir + "\\"
    }

    /// Los juegos que lanza Steam escriben en el log del cliente de Steam.
    public static func latestSteamLog() -> URL? { latestLog(prefix: "steam-client-") }

    static func latestLog(prefix: String) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: Paths.logs, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.lastPathComponent.hasPrefix(prefix) }
            .max { (mod($0) ?? .distantPast) < (mod($1) ?? .distantPast) }
    }

    private static func mod(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Bloquea hasta que el juego termina. nil si el juego nunca apareció (o duró menos de 10 s).
    public func run(waitForStart: TimeInterval = 180, onSample: ((SessionSample) -> Void)? = nil) throws -> SessionSummary? {
        let deadline = Date().addingTimeInterval(waitForStart)
        while gameProcesses().isEmpty {
            if Date() > deadline { return nil }
            Thread.sleep(forTimeInterval: 1)
        }

        let start = Date()
        let stamp = ISO8601DateFormatter().string(from: start).replacingOccurrences(of: ":", with: "-")
        let id = "\(profile.id)-\(stamp)"
        try Paths.ensure(SessionStore.directory)
        let samplesURL = SessionStore.samplesURL(id)
        FileManager.default.createFile(atPath: samplesURL.path, contents: nil)
        let out = try FileHandle(forWritingTo: samplesURL)
        defer { try? out.close() }
        let enc = JSONEncoder()

        var logOffset = fpsLog.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? UInt64 } ?? 0
        let crashMarkers = ["unhandled exception", "page fault on", "wine: unhandled", "backtrace:"]
        var crashed = false
        var samples: [SessionSample] = []
        var allFPS: [Double] = []
        var hudFrames: [Int: Int] = [:]
        var missing = 0

        while true {
            Thread.sleep(forTimeInterval: interval)
            let procs = gameProcesses()
            if procs.isEmpty {
                missing += 1
                if missing >= 3 { break }   // ~6 s sin procesos: se cerró
                continue
            }
            missing = 0

            var fps: [Double] = []
            if let log = fpsLog, let (text, newOffset) = Self.read(log, from: logOffset) {
                logOffset = newOffset
                let lower = text.lowercased()
                if crashMarkers.contains(where: lower.contains) { crashed = true }
                fps = Self.metalHUDFPS(text, pids: Set(procs.map(\.pid)), lastFrame: &hudFrames)
                if fps.isEmpty {
                    fps = text.matches(#"approx\s+[\d.]+fps"#).compactMap { Double($0.filter { "0123456789.".contains($0) }) }
                }
                allFPS += fps
            }
            let gpu = Self.gpuStats()
            let sample = SessionSample(
                t: Date().timeIntervalSince(start),
                cpu: procs.reduce(0) { $0 + $1.cpu },
                memoryMB: procs.reduce(0) { $0 + $1.rssMB },
                gpu: gpu.utilization, gpuMemoryMB: gpu.memoryMB,
                fps: fps.isEmpty ? nil : fps.reduce(0, +) / Double(fps.count),
                thermal: ProcessInfo.processInfo.thermalState.rawValue)
            samples.append(sample)
            if let line = try? enc.encode(sample) { out.write(line + Data("\n".utf8)) }
            onSample?(sample)
        }

        let end = Date()
        guard end.timeIntervalSince(start) >= 10, !samples.isEmpty else {
            try? FileManager.default.removeItem(at: samplesURL)
            return nil
        }
        let mac = MacSpecs.current()
        let sortedFPS = allFPS.sorted()
        let gpus = samples.compactMap(\.gpu)
        let summary = SessionSummary(
            id: id, profileId: profile.id, name: profile.name, backend: backend.rawValue,
            start: start, end: end, duration: end.timeIntervalSince(start),
            avgFPS: allFPS.isEmpty ? nil : allFPS.reduce(0, +) / Double(allFPS.count),
            lowFPS: sortedFPS.isEmpty ? nil : sortedFPS[Int(Double(sortedFPS.count - 1) * 0.05)],
            minFPS: sortedFPS.first,
            avgCPU: samples.map(\.cpu).reduce(0, +) / Double(samples.count),
            peakCPU: samples.map(\.cpu).max() ?? 0,
            peakMemoryMB: samples.map(\.memoryMB).max() ?? 0,
            avgGPU: gpus.isEmpty ? nil : gpus.reduce(0, +) / Double(gpus.count),
            peakGPU: gpus.max(),
            maxThermal: samples.map(\.thermal).max() ?? 0,
            crashed: crashed, mac: mac.chip, macMemoryGB: mac.memoryGB, samples: samples.count)
        try SessionStore.save(summary)
        return summary
    }

    // MARK: Fuentes

    struct Proc { let pid: Int; let cpu: Double; let rssMB: Double }

    /// Procesos del juego (sin start.exe ni el cliente de Steam).
    func gameProcesses() -> [Proc] {
        guard let ps = Shell.output("/bin/ps", ["-axo", "pid=,%cpu=,rss=,command="]) else { return [] }
        return ps.split(separator: "\n").compactMap { line in
            let lower = line.lowercased()
            guard lower.contains(processMatch), !lower.contains("start.exe"), !lower.contains("steam.exe -applaunch")
            else { return nil }
            let f = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            // Solo procesos de Wine (su argv[0] es una ruta de Windows), no shells que mencionen la ruta
            guard f.count == 4, f[3].range(of: #"^[A-Za-z]:\\"#, options: .regularExpression) != nil else { return nil }
            // ps respeta el idioma del sistema: en español el % de CPU llega como "12,5"
            guard f.count >= 3, let pid = Int(f[0]), let cpu = Double(f[1].replacingOccurrences(of: ",", with: ".")),
                  let rss = Double(f[2]) else { return nil }
            return Proc(pid: pid, cpu: cpu, rssMB: rss / 1024)
        }
    }

    /// Uso de GPU del sistema según el driver (sin sudo).
    static func gpuStats() -> (utilization: Double?, memoryMB: Double?) {
        guard let io = Shell.output("/usr/sbin/ioreg", ["-rc", "AGXAccelerator", "-d1"]) else { return (nil, nil) }
        func value(_ key: String) -> Double? {
            guard let r = io.range(of: "\"\(key)\"=") else { return nil }
            return Double(io[r.upperBound...].prefix { $0.isNumber })
        }
        return (value("Device Utilization %"), value("In use system memory").map { $0 / 1_048_576 })
    }

    /// FPS de cada línea del HUD de Metal en `text` (una cada ~0.8 s con el HUD oculto). Formato
    /// (libMTLHud, macOS 26): `metal-HUD: <cuadro>,<MB Metal>,<MB app>,<intervalo ms>,<GPU ms>,…`
    /// con un par intervalo/GPU por cada cuadro que llegó a la pantalla desde la línea anterior.
    /// Los intervalos suman el tiempo transcurrido; el contador de cuadros cuenta cada Present, también
    /// los que no se mostraron (por encima de los Hz de la pantalla), igual que `trace+fps` de wined3d.
    /// NSLog antepone `proceso[pid:tid]`: con `pids` se ignoran otras apps que escriban al mismo log.
    /// `lastFrame` guarda el último contador por pid entre lecturas.
    static func metalHUDFPS(_ text: String, pids: Set<Int> = [], lastFrame: inout [Int: Int]) -> [Double] {
        text.split(separator: "\n").compactMap { line in
            guard let r = line.range(of: "metal-HUD: ") else { return nil }
            let pid = line[..<r.lowerBound].range(of: #"\[\d+:"#, options: [.regularExpression, .backwards])
                .flatMap { Int(line[$0].dropFirst().dropLast()) } ?? 0
            if !pids.isEmpty, pid != 0, !pids.contains(pid) { return nil }
            let values = line[r.upperBound...].split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard values.count >= 5, (values.count - 3) % 2 == 0, let frame = values[0].map(Int.init) else { return nil }
            let intervals = stride(from: 3, to: values.count, by: 2).compactMap { values[$0] }
            let ms = intervals.reduce(0, +)
            guard intervals.count == (values.count - 3) / 2, ms > 0 else { return nil }
            defer { lastFrame[pid] = frame }
            // La primera línea de cada proceso solo sirve de referencia para el contador
            guard let previous = lastFrame[pid] else { return nil }
            // Si el contador se reinició (swapchain nueva) solo se conocen los cuadros mostrados
            let frames = frame > previous ? frame - previous : intervals.count
            return Double(frames) * 1000 / ms
        }
    }

    /// Lo nuevo del log desde `offset`, hasta el último salto de línea (una línea a medio escribir
    /// se lee completa en la siguiente vuelta).
    static func read(_ url: URL, from offset: UInt64) -> (String, UInt64)? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        guard size > offset else { return ("", size) }
        try? h.seek(toOffset: offset)
        var data = (try? h.readToEnd()) ?? Data()
        if let nl = data.lastIndex(of: 0x0A) {
            data = data[..<data.index(after: nl)]
        } else if data.count < 1 << 20 {
            return ("", offset)
        }
        return (String(decoding: data, as: UTF8.self), offset + UInt64(data.count))
    }
}

/// Qué mejorar, a partir de lo que se midió.
public enum SessionInsights {
    public struct Insight: Hashable {
        public enum Kind { case good, tip, problem }
        public let kind: Kind
        public let text: String
    }

    public static func analyze(_ s: SessionSummary, candidates: [GraphicsBackend] = []) -> [Insight] {
        var out: [Insight] = []
        if s.crashed {
            out.append(.init(kind: .problem, text: "Terminó con un error de Windows. El log de la sesión tiene el detalle."))
        }
        if let avg = s.avgFPS {
            if let low = s.lowFPS, low < avg * 0.6 {
                out.append(.init(kind: .tip, text: "Tirones: promedio \(Int(avg)) FPS, pero el 5% más lento baja a \(Int(low)). Suele ser compilación de shaders (mejora al seguir jugando) o carga de texturas; si persiste, un tope de FPS estabiliza."))
            } else if avg >= 55 {
                out.append(.init(kind: .good, text: "Fluido: \(Int(avg)) FPS de promedio y sin caídas grandes."))
            }
            if avg < 30 {
                out.append(.init(kind: .problem, text: "Por debajo de 30 FPS: baja la resolución o la calidad dentro del juego."))
            }
        } else if s.backend != GraphicsBackend.wined3d.rawValue {
            out.append(.init(kind: .tip, text: "Sin FPS medidos: el contador (HUD de Metal oculto) solo se activa cuando Nightport lanza el juego. Si ya estaba abierto o lo abrió Steam, ciérralo y lánzalo desde aquí."))
        }
        if let gpu = s.avgGPU {
            if gpu >= 90 {
                out.append(.init(kind: .tip, text: "La GPU fue al \(Int(gpu))%: es el límite. Desactiva Modo Retina o baja la resolución para ganar FPS."))
            } else if gpu < 50, let avg = s.avgFPS, avg < 50 {
                let others = candidates.filter { $0.rawValue != s.backend }.map(\.rawValue)
                out.append(.init(kind: .tip, text: "La GPU iba sobrada (\(Int(gpu))%) pero con pocos FPS: el freno es la CPU o la traducción."
                                 + (others.isEmpty ? "" : " Prueba otro traductor: \(others.joined(separator: ", ")).")))
            }
        }
        if s.peakMemoryMB / 1024 > s.macMemoryGB * 0.75 {
            out.append(.init(kind: .problem, text: "Usó \(Int(s.peakMemoryMB / 1024)) GB de \(Int(s.macMemoryGB)) GB: cierra otras apps mientras juegas."))
        }
        if s.maxThermal >= 2 {
            out.append(.init(kind: .problem, text: "La Mac se calentó al punto de bajar velocidad. Un tope de FPS reduce el calor."))
        }
        return out
    }

    /// Compara traductores con las sesiones del mismo juego.
    public static func backendComparison(_ sessions: [SessionSummary]) -> String? {
        let byBackend = Dictionary(grouping: sessions.filter { $0.avgFPS != nil }, by: \.backend)
        guard byBackend.count >= 2 else { return nil }
        let avgs = byBackend.mapValues { list in list.compactMap(\.avgFPS).reduce(0, +) / Double(list.count) }
            .sorted { $0.value > $1.value }
        return "Mejor traductor medido: \(avgs[0].key) (\(Int(avgs[0].value)) FPS) contra "
            + avgs.dropFirst().map { "\($0.key) (\(Int($0.value)))" }.joined(separator: ", ") + "."
    }
}
