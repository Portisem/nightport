import Foundation

// ¿Qué tan capaz es esta Mac de correr un juego? Comparamos los requisitos de Windows que publica
// Steam con la GPU, la memoria y el disco de la Mac, descontando el costo de traducir DirectX a Metal.
//
// La escala común es un "índice de GPU": TFLOPS FP32 equivalentes a Pascal/Turing (GTX 1060 ≈ 4.4).
// Ampere/Ada y VLIW de AMD reportan TFLOPS inflados para juegos, así que se ajustaron a su
// rendimiento real relativo. Todo es estimación: los benchmarks de cada perfil mandan sobre esto.

/// Hardware de la Mac relevante para juegos.
public struct MacSpecs: Codable, Equatable {
    public var chip: String          // "Apple M5 Pro"
    public var gpuCores: Int
    public var memoryGB: Double      // memoria unificada (la comparten CPU y GPU)
    public var freeDiskGB: Double

    /// Índice de GPU nativo en Metal (sin traducción).
    public var gpuIndex: Double { Double(gpuCores) * AppleGPU.perCore(chip: chip) }

    public static func current() -> MacSpecs {
        let chip = Shell.output("/usr/sbin/sysctl", ["-n", "machdep.cpu.brand_string"]) ?? "Apple"
        let mem = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        var cores = 0
        if let io = Shell.output("/usr/sbin/ioreg", ["-rc", "AGXAccelerator", "-d1"]),
           let line = io.split(separator: "\n").first(where: { $0.contains("\"gpu-core-count\"") }),
           let n = line.split(separator: "=").last.flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }) {
            cores = n
        }
        var free = 0.0
        if let values = try? Paths.home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let bytes = values.volumeAvailableCapacityForImportantUsage {
            free = Double(bytes) / 1_000_000_000
        }
        return MacSpecs(chip: chip, gpuCores: cores, memoryGB: mem.rounded(), freeDiskGB: free)
    }
}

enum AppleGPU {
    /// Índice por núcleo de GPU según la generación (reloj × 128 ALU × 2, con margen por arquitectura).
    static func perCore(chip: String) -> Double {
        switch generation(chip) {
        case 1: return 0.32
        case 2: return 0.36
        case 3: return 0.40
        case 4: return 0.43
        default: return 0.47   // M5 en adelante: estimación conservadora
        }
    }

    static func generation(_ chip: String) -> Int {
        guard let r = chip.range(of: #"M(\d+)"#, options: .regularExpression) else { return 1 }
        return Int(chip[r].dropFirst()) ?? 1
    }

    /// Configuraciones de Mac (GPU completa de cada chip), de menor a mayor índice.
    static let lineup: [(name: String, cores: Int)] = [
        ("M1", 8), ("M2", 10), ("M3", 10), ("M4", 10), ("M5", 10),
        ("M1 Pro", 16), ("M2 Pro", 19), ("M3 Pro", 18), ("M4 Pro", 20),
        ("M1 Max", 32), ("M2 Max", 38), ("M3 Max", 40), ("M4 Max", 40),
        ("M1 Ultra", 64), ("M2 Ultra", 76), ("M3 Ultra", 80),
    ]

    static let memorySteps: [Double] = [8, 16, 24, 32, 48, 64, 96, 128, 192]
}

/// Requisitos de Windows (mínimo y recomendado) leídos de la tienda de Steam.
public struct GameRequirements: Codable, Equatable {
    public struct Tier: Codable, Equatable {
        public var text: String          // texto original de Steam, limpio
        public var gpu: String?          // línea de gráficos
        public var gpuIndex: Double?
        public var ramGB: Double?
        public var vramGB: Double?
        public var diskGB: Double?
    }
    public var appId: Int
    public var minimum: Tier?
    public var recommended: Tier?
    public var fetched: Date
}

public enum Requirements {
    static var cacheDir: URL { Paths.home.appendingPathComponent("Library/Caches/GamingMac/requirements") }

    /// Requisitos de Steam con caché de 30 días. nil si Steam no los publica o no hay red y no hay caché.
    public static func load(appId: Int) async -> GameRequirements? {
        let file = cacheDir.appendingPathComponent("\(appId).json")
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let cached = (try? Data(contentsOf: file)).flatMap { try? dec.decode(GameRequirements.self, from: $0) }
        if let cached, Date().timeIntervalSince(cached.fetched) < 30 * 86_400 { return cached }

        guard let url = URL(string: "https://store.steampowered.com/api/appdetails?appids=\(appId)&l=english"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = json["\(appId)"] as? [String: Any],
              let info = entry["data"] as? [String: Any],
              let pc = info["pc_requirements"] as? [String: Any]
        else { return cached }

        let minimum = (pc["minimum"] as? String).flatMap(parseTier)
        var recommended = (pc["recommended"] as? String).flatMap(parseTier)
        // Lo que el recomendado no dice, lo hereda del mínimo (nunca pide menos que él).
        if var rec = recommended, let min = minimum {
            if rec.gpuIndex == nil { rec.gpu = rec.gpu ?? min.gpu; rec.gpuIndex = min.gpuIndex }
            rec.ramGB = max(rec.ramGB ?? 0, min.ramGB ?? 0).nonZero
            rec.vramGB = max(rec.vramGB ?? 0, min.vramGB ?? 0).nonZero
            rec.diskGB = max(rec.diskGB ?? 0, min.diskGB ?? 0).nonZero
            recommended = rec
        }
        let req = GameRequirements(appId: appId, minimum: minimum, recommended: recommended, fetched: Date())
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        try? Paths.ensure(cacheDir)
        try? enc.encode(req).write(to: file)
        return req
    }

    /// Convierte el HTML de Steam ("<strong>Memory:</strong> 16 GB RAM<br>…") en un nivel.
    static func parseTier(_ html: String) -> GameRequirements.Tier? {
        let text = html
            .replacingOccurrences(of: #"<br\s*/?>|</li>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .filter { !["Minimum:", "Recommended:"].contains($0) }
            .joined(separator: "\n")
        guard !text.isEmpty else { return nil }

        func field(_ names: [String]) -> String? {
            for line in text.split(separator: "\n") {
                for name in names where line.lowercased().hasPrefix(name.lowercased() + ":") {
                    return line.dropFirst(name.count + 1).trimmingCharacters(in: .whitespaces)
                }
            }
            return nil
        }

        let gpu = field(["Graphics", "Video Card", "Video"])
        // Juegos viejos ponen todo en una línea ("500 mhz processor, 96mb ram, 16mb video card…")
        let memoryText = field(["Memory", "RAM"]) ?? firstMatch(#"[\d.]+\s*(gb|mb)\s*ram"#, in: text)
        let diskText = field(["Storage", "Hard Drive", "Hard Disk Space", "Disk Space"])
        let gpuSource = gpu ?? firstMatch(#"[\d.]+\s*mb\+?\s*video card"#, in: text)
        return .init(text: text,
                     gpu: gpu ?? gpuSource,
                     gpuIndex: gpuSource.flatMap(GPUCatalog.index),
                     ramGB: memoryText.flatMap(sizeGB),
                     vramGB: gpu.flatMap(vramGB),
                     diskGB: diskText.flatMap(sizeGB))
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]).map { String(text[$0]) }
    }

    /// "16 GB RAM" → 16, "96mb ram" → 0.09
    static func sizeGB(_ s: String) -> Double? {
        guard let m = firstMatch(#"[\d.]+\s*(gb|mb|tb)"#, in: s) else { return nil }
        let lower = m.lowercased()
        guard let n = Double(lower.filter { "0123456789.".contains($0) }) else { return nil }
        if lower.hasSuffix("tb") { return n * 1000 }
        return lower.hasSuffix("mb") ? n / 1024 : n
    }

    /// VRAM pedida en la línea de gráficos ("GTX 1060 6GB / RX 580 8GB" → 6: basta cualquiera).
    static func vramGB(_ gpu: String) -> Double? {
        let sizes = gpu.matches(#"(\d+)\s*(gb|mb)"#).compactMap(sizeGB).filter { $0 <= 24 }
        return sizes.min()
    }
}

/// Índice de GPUs de Windows comunes en requisitos de Steam.
enum GPUCatalog {
    static let table: [String: Double] = [
        // NVIDIA
        "nv 6600": 0.02, "nv 6800": 0.03, "nv 7600": 0.03, "nv 7800": 0.05, "nv 7900": 0.06,
        "nv 8600": 0.1, "nv 8800": 0.35, "nv 9600": 0.2, "nv 9800": 0.4,
        "gts 250": 0.45, "gts 450": 0.6, "gtx 260": 0.5, "gtx 275": 0.6, "gtx 285": 0.7,
        "gtx 460": 0.9, "gtx 470": 1.1, "gtx 480": 1.3, "gtx 550 ti": 0.7, "gtx 560": 1.1, "gtx 560 ti": 1.26,
        "gtx 570": 1.4, "gtx 580": 1.6, "gt 640": 0.6, "gtx 650": 0.8, "gtx 650 ti": 1.1, "gtx 660": 1.9,
        "gtx 660 ti": 2.4, "gtx 670": 2.5, "gtx 680": 3.1, "gtx 750": 1.1, "gtx 750 ti": 1.4, "gtx 760": 2.3,
        "gtx 770": 3.2, "gtx 780": 4.0, "gtx 780 ti": 5.0, "gtx 950": 1.8, "gtx 960": 2.3, "gtx 970": 3.9,
        "gtx 980": 4.6, "gtx 980 ti": 5.6, "gtx 1050": 1.9, "gtx 1050 ti": 2.1, "gtx 1060": 4.4,
        "gtx 1070": 6.5, "gtx 1070 ti": 7.8, "gtx 1080": 8.9, "gtx 1080 ti": 11.3, "gtx 1630": 1.8,
        "gtx 1650": 3.0, "gtx 1650 super": 4.4, "gtx 1660": 5.0, "gtx 1660 super": 5.0, "gtx 1660 ti": 5.4,
        "rtx 2060": 6.5, "rtx 2060 super": 7.2, "rtx 2070": 7.5, "rtx 2070 super": 9.0, "rtx 2080": 10.1,
        "rtx 2080 super": 11.2, "rtx 2080 ti": 13.4, "rtx 3050": 6.0, "rtx 3060": 8.5, "rtx 3060 ti": 10.5,
        "rtx 3070": 12.5, "rtx 3070 ti": 13.5, "rtx 3080": 16.0, "rtx 3080 ti": 18.0, "rtx 3090": 19.0,
        "rtx 4060": 9.5, "rtx 4060 ti": 11.5, "rtx 4070": 15.0, "rtx 4070 super": 17.5, "rtx 4070 ti": 18.5,
        "rtx 4080": 22.0, "rtx 4090": 30.0, "rtx 5060": 11.5, "rtx 5070": 18.0, "rtx 5080": 25.0, "rtx 5090": 38.0,
        // AMD / ATI
        "ati 9600": 0.01, "ati 9800": 0.02, "ati x800": 0.02, "ati x1600": 0.03, "ati x1800": 0.05, "ati x1900": 0.08,
        "hd 2600": 0.1, "hd 3850": 0.3, "hd 3870": 0.35, "hd 4670": 0.3, "hd 4850": 0.6, "hd 4870": 0.7,
        "hd 5670": 0.4, "hd 5750": 0.6, "hd 5770": 0.75, "hd 5850": 1.2, "hd 5870": 1.5, "hd 6670": 0.5,
        "hd 6770": 0.75, "hd 6850": 0.8, "hd 6870": 1.1, "hd 6950": 1.4, "hd 6970": 1.6, "hd 7750": 0.8,
        "hd 7770": 1.1, "hd 7790": 1.6, "hd 7850": 1.7, "hd 7870": 2.5, "hd 7950": 2.9, "hd 7970": 3.8,
        "r7 260x": 1.9, "r7 370": 1.9, "r9 270": 2.4, "r9 270x": 2.6, "r9 280": 3.3, "r9 280x": 4.1,
        "r9 290": 4.8, "r9 290x": 5.4, "r9 380": 3.5, "r9 390": 5.1, "r9 fury": 6.0,
        "rx 460": 2.0, "rx 470": 3.8, "rx 480": 4.2, "rx 550": 1.1, "rx 560": 2.2, "rx 570": 4.0, "rx 580": 4.4,
        "rx 590": 4.7, "rx vega 56": 6.4, "rx vega 64": 7.5, "rx 5500 xt": 4.5, "rx 5600 xt": 6.5,
        "rx 5700": 7.2, "rx 5700 xt": 7.9, "rx 6500 xt": 3.5, "rx 6600": 8.0, "rx 6600 xt": 9.0,
        "rx 6650 xt": 9.5, "rx 6700 xt": 11.5, "rx 6750 xt": 12.0, "rx 6800": 15.0, "rx 6800 xt": 17.0,
        "rx 6900 xt": 19.0, "rx 7600": 9.0, "rx 7700 xt": 14.0, "rx 7800 xt": 17.0, "rx 7900 xt": 22.0,
        "rx 7900 xtx": 25.0, "rx 9070": 21.0, "rx 9070 xt": 24.0,
        // Intel
        "arc a380": 3.5, "arc a580": 7.0, "arc a750": 8.0, "arc a770": 8.5, "arc b580": 10.0,
        "intel hd": 0.4, "intel uhd": 0.45, "iris xe": 1.5,
    ]

    /// Índice de la línea de gráficos. Las alternativas ("RTX 2060 / RX 5700 XT") son "cualquiera de":
    /// basta con alcanzar la menos exigente.
    static func index(_ line: String) -> Double? {
        let s = " " + line.lowercased()
            .replacingOccurrences(of: #"[®™(),/;]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "geforce", with: "")
            .replacingOccurrences(of: "radeon", with: "")
            .replacingOccurrences(of: "nvidia", with: "nv")
            .replacingOccurrences(of: "amd", with: "ati") + " "
        var found: [Double] = []
        let families: [(pattern: String, prefix: String)] = [
            (#"\brtx\s*(\d{4})(\s*(ti|super))?"#, "rtx"),
            (#"\bgtx\s*(\d{3,4})(\s*(ti|super))?"#, "gtx"),
            (#"\bgts\s*(\d{3})"#, "gts"),
            (#"\bgt\s*(\d{3,4})"#, "gt"),
            (#"\brx\s*vega\s*(56|64)"#, "rx vega"),
            (#"\brx\s*(\d{3,4})(\s*(xtx|xt))?"#, "rx"),
            (#"\bhd\s*(\d{4})"#, "hd"),
            (#"\br[79]\s*(\d{3}x?|fury)"#, ""),
            (#"\barc\s*([ab]\d{3})"#, "arc"),
            (#"\b(?:nv|ati)\s*(x?\d{3,4})"#, ""),
        ]
        for (pattern, prefix) in families {
            for m in s.matches(pattern) {
                let compact = m.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                var key = compact
                if !prefix.isEmpty, let r = compact.range(of: #"^[a-z]+(\s*vega)?"#, options: .regularExpression) {
                    key = prefix + " " + compact[r.upperBound...].trimmingCharacters(in: .whitespaces)
                }
                key = key.replacingOccurrences(of: #"^(rtx|gtx|gts|gt|rx|hd|arc|nv|ati|r7|r9)(\d)"#, with: "$1 $2", options: .regularExpression)
                if let v = table[key] { found.append(v) }
            }
        }
        for name in ["intel uhd", "intel hd", "iris xe"] where s.contains(name) { found.append(table[name]!) }
        if let best = found.min() { return best }
        // Requisitos antiguos sin modelo: "Shader model 2.0", "16mb video card", "128 MB"
        if s.contains("shader model") || s.contains("directx 9") { return 0.05 }
        if let mb = Requirements.vramGB(line), mb <= 0.5 { return 0.03 }
        return nil
    }

    /// GPU de Windows con índice más cercano (para "equivale a…").
    static func nearestName(_ index: Double) -> String {
        let named = table.filter { $0.key.hasPrefix("gtx") || $0.key.hasPrefix("rtx") }
        let best = named.min { abs($0.value - index) < abs($1.value - index) }!.key
        return "GeForce " + best.uppercased().replacingOccurrences(of: " TI", with: " Ti").replacingOccurrences(of: " SUPER", with: " Super")
    }
}

/// Veredicto: qué tan bien correría un juego en esta Mac.
/// Los textos usan `String(localized:)` con `Bundle.main`: Nightport.app trae la traducción al inglés;
/// `gmac` suelto no trae tablas y se queda en español.
public struct CapabilityReport {
    public enum Level: Int, Comparable {
        case insuficiente = 0, minimo, recomendado, holgado
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
        public var label: String {
            switch self {
            case .holgado: return String(localized: "Va sobrado")
            case .recomendado: return String(localized: "Cumple lo recomendado")
            case .minimo: return String(localized: "Cumple el mínimo")
            case .insuficiente: return String(localized: "Por debajo del mínimo")
            }
        }
    }

    public struct Row {
        public var resource: String      // "Gráficos", "Memoria", "Almacenamiento"
        public var mac: String
        public var minimum: String?
        public var recommended: String?
        public var level: Level?
    }

    /// nil = no hay datos suficientes para opinar.
    public var level: Level?
    public var summary: String
    public var rows: [Row]
    public var recommendedMac: String?
    public var warnings: [String]
    /// Índice de la Mac ya descontando la traducción del traductor elegido.
    public var effectiveGPUIndex: Double
}

public enum Capability {
    /// Costo aproximado de traducir DirectX → Metal con cada traductor (1.0 = nativo).
    public static func overhead(_ backend: GraphicsBackend) -> Double {
        switch backend {
        case .d3dmetal: return 1.35
        case .dxmt: return 1.3
        case .dxvk: return 1.5
        case .wined3d: return 1.6
        }
    }

    /// Memoria que se lleva macOS + Wine además de lo que pide el juego.
    static let systemReserveGB = 4.0

    public static func macSummary(_ mac: MacSpecs) -> String {
        String(localized: "\(mac.chip) · \(mac.gpuCores) núcleos de GPU · \(Int(mac.memoryGB)) GB · rinde como una \(nativeEquivalent(mac)) en juegos nativos")
    }

    public static func nativeEquivalent(_ mac: MacSpecs) -> String { GPUCatalog.nearestName(mac.gpuIndex) }

    public static func translatedEquivalent(_ mac: MacSpecs, backend: GraphicsBackend) -> String {
        GPUCatalog.nearestName(mac.gpuIndex / overhead(backend))
    }

    public static func report(profile: GameProfile, requirements: GameRequirements?, mac: MacSpecs,
                              backend: GraphicsBackend, installed: Bool) -> CapabilityReport {
        let eff = mac.gpuIndex / overhead(backend)
        let minT = requirements?.minimum
        let recT = requirements?.recommended
        var rows: [CapabilityReport.Row] = []
        var warnings: [String] = []

        func level(_ have: Double, min: Double?, rec: Double?) -> CapabilityReport.Level? {
            if let rec, have >= rec * 1.5 { return .holgado }
            if let rec, have >= rec { return .recomendado }
            if let min, rec == nil { return have >= min * 3 ? .holgado : (have >= min ? .recomendado : .insuficiente) }
            if let min, have >= min { return .minimo }
            if min != nil || rec != nil { return .insuficiente }
            return nil
        }

        // Gráficos
        let gpuLevel = level(eff, min: minT?.gpuIndex, rec: recT?.gpuIndex)
        rows.append(.init(resource: String(localized: "Gráficos"),
                          mac: String(localized: "\(mac.chip), \(mac.gpuCores) núcleos ≈ \(GPUCatalog.nearestName(eff))"),
                          minimum: minT?.gpu, recommended: recT?.gpu, level: gpuLevel))

        // Memoria: en Apple Silicon la RAM y la VRAM del juego salen de la misma memoria unificada.
        func need(_ t: GameRequirements.Tier?) -> Double? {
            guard let t, t.ramGB != nil || t.vramGB != nil else { return nil }
            return (t.ramGB ?? 0) + (t.vramGB ?? 0) + systemReserveGB
        }
        let memMin = need(minT), memRec = need(recT)
        let memLevel = level(mac.memoryGB, min: memMin, rec: memRec)
        func memText(_ t: GameRequirements.Tier?) -> String? {
            guard let t, let total = need(t) else { return nil }
            var parts: [String] = []
            if let r = t.ramGB { parts.append("\(gb(r)) RAM") }
            if let v = t.vramGB { parts.append("\(gb(v)) VRAM") }
            return String(localized: "\(parts.joined(separator: " + ")) → \(gb(total)) unificada")
        }
        rows.append(.init(resource: String(localized: "Memoria"), mac: String(localized: "\(gb(mac.memoryGB)) unificada"),
                          minimum: memText(minT), recommended: memText(recT), level: memLevel))

        // Almacenamiento (solo importa si falta descargarlo)
        let disk = recT?.diskGB ?? minT?.diskGB
        var diskLevel: CapabilityReport.Level?
        if let disk {
            diskLevel = installed || mac.freeDiskGB >= disk ? .recomendado : .insuficiente
            if diskLevel == .insuficiente {
                warnings.append(String(localized: "Faltan \(gb(disk - mac.freeDiskGB)) libres para descargarlo."))
            }
        }
        rows.append(.init(resource: String(localized: "Almacenamiento"),
                          mac: installed ? String(localized: "Instalado") : String(localized: "\(gb(mac.freeDiskGB)) libres"),
                          minimum: minT?.diskGB.map(gb), recommended: recT?.diskGB.map(gb), level: diskLevel))

        let overall = [gpuLevel, memLevel].compactMap { $0 }.min()
        if gpuLevel == nil, requirements != nil {
            warnings.append(String(localized: "No reconocí la tarjeta gráfica que pide Steam; el veredicto solo considera la memoria."))
        }

        var summary: String
        if ProfileStatus.blocked(profile.status) {
            summary = String(localized: "Tu Mac tiene la potencia, pero el anti-cheat del juego no funciona fuera de Windows.")
            warnings.insert(String(localized: "Bloqueado por anti-cheat."), at: 0)
        } else {
            switch overall {
            case .holgado?: summary = String(localized: "Tu Mac va sobrada: calidad alta, incluso con el costo de la traducción.")
            case .recomendado?: summary = String(localized: "Tu Mac cumple lo recomendado: calidad media-alta.")
            case .minimo?: summary = String(localized: "Tu Mac cumple el mínimo: calidad baja y resolución reducida.")
            case .insuficiente?: summary = String(localized: "Tu Mac queda por debajo del mínimo: puede abrir, pero no se jugará bien.")
            case nil: summary = requirements == nil
                ? String(localized: "Steam no publica requisitos para este juego.")
                : String(localized: "No hay datos suficientes para estimarlo.")
            }
        }

        return CapabilityReport(level: ProfileStatus.blocked(profile.status) ? nil : overall, summary: summary, rows: rows,
                                recommendedMac: recommendedMac(gpu: recT?.gpuIndex ?? minT?.gpuIndex,
                                                               memory: memRec ?? memMin, backend: backend),
                                warnings: warnings, effectiveGPUIndex: eff)
    }

    /// La Mac más modesta que cumple lo recomendado (o el mínimo si no hay recomendado).
    static func recommendedMac(gpu: Double?, memory: Double?, backend: GraphicsBackend) -> String? {
        guard gpu != nil || memory != nil else { return nil }
        var chip = AppleGPU.lineup.first?.name
        if let gpu {
            let needed = gpu * overhead(backend)
            chip = AppleGPU.lineup
                .map { ($0.name, Double($0.cores) * AppleGPU.perCore(chip: $0.name)) }
                .sorted { $0.1 < $1.1 }
                .first { $0.1 >= needed }?.0
        }
        let mem = memory.flatMap { m in AppleGPU.memorySteps.first { $0 >= m } }
        guard let chip else { return String(localized: "Ninguna Mac actual alcanza lo recomendado con traducción.") }
        return mem.map { String(localized: "\(chip) o superior, con \(Int($0)) GB") } ?? String(localized: "\(chip) o superior")
    }

    static func gb(_ v: Double) -> String {
        if v < 1 { return "\(Int((v * 1024).rounded())) MB" }
        return v.rounded() == v || v >= 10 ? "\(Int(v.rounded())) GB" : String(format: "%.1f GB", v)
    }
}

/// Lectura mínima del estado del perfil (el enum de la app vive en la capa de UI).
enum ProfileStatus {
    static func blocked(_ status: String?) -> Bool {
        ["bloqueado", "anti-cheat"].contains(status?.lowercased() ?? "")
    }
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

extension String {
    func matches(_ pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return re.matches(in: self, range: NSRange(startIndex..., in: self)).compactMap { Range($0.range, in: self).map { String(self[$0]) } }
    }
}
