import Foundation

/// Un motor = una instalación de Wine + traductores gráficos, en Engines/<nombre>/.
///
/// Layout esperado (igual al de CrossOver para que su Wine encuentre todo con CX_ROOT):
///   bin/wine, bin/wineserver
///   lib/wine/{x86_64-unix,x86_64-windows,i386-windows}
///   lib/dxmt/..., lib/dxvk/..., lib64/apple_gptk/...   (opcionales)
///   engine.json   (manifiesto)
public struct Engine {
    public struct Manifest: Codable {
        public var name: String
        /// "crossover": Wine de las fuentes FOSS de CodeWeavers + parches GamingMac (WINEDLLPATH_PRIORITY).
        /// "upstream": Wine de WineHQ; el traductor se instala copiando DLLs al prefix.
        public var flavor: String
        public var wineVersion: String?
        public var notes: String?

        public init(name: String, flavor: String, wineVersion: String?, notes: String?) {
            self.name = name
            self.flavor = flavor
            self.wineVersion = wineVersion
            self.notes = notes
        }
    }

    public let root: URL
    public let manifest: Manifest

    public init(root: URL, manifest: Manifest) {
        self.root = root
        self.manifest = manifest
    }

    public var name: String { manifest.name }
    public var isCrossOverFlavor: Bool { manifest.flavor == "crossover" }

    public var wine: URL {
        let bin = root.appendingPathComponent("bin")
        for candidate in ["wine", "wine64"] {
            let url = bin.appendingPathComponent(candidate)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        return bin.appendingPathComponent("wine")
    }

    public var wineserver: URL { root.appendingPathComponent("bin/wineserver") }

    /// Carpeta con las DLLs de un traductor, si este motor lo trae.
    public func backendDirectory(_ backend: GraphicsBackend) -> URL? {
        let rel: String
        switch backend {
        case .dxmt: rel = "lib/dxmt"
        case .dxvk: rel = "lib/dxvk"
        case .d3dmetal: rel = "lib64/apple_gptk/wine"
        case .wined3d: return root.appendingPathComponent("lib/wine")
        }
        let url = root.appendingPathComponent(rel)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public var availableBackends: [GraphicsBackend] {
        GraphicsBackend.allCases.filter { backendDirectory($0) != nil }
    }

    public static func list() -> [Engine] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: Paths.engines, includingPropertiesForKeys: nil) else { return [] }
        return dirs.compactMap { dir in
            let manifestURL = dir.appendingPathComponent("engine.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return nil }
            return Engine(root: dir, manifest: manifest)
        }.sorted { $0.name < $1.name }
    }

    /// Busca por nombre; sin nombre, el único/primer motor instalado.
    public static func find(_ name: String?) throws -> Engine {
        let all = list()
        if let name {
            guard let e = all.first(where: { $0.name == name }) else {
                throw GMError("No existe el motor '\(name)'. Instalados: \(all.map(\.name).joined(separator: ", "))")
            }
            return e
        }
        guard let first = all.first else {
            throw GMError("No hay motores instalados en \(Paths.engines.path). Ver docs/MOTOR.md")
        }
        return first
    }
}
