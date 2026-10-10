import Foundation

/// Un bottle = un WINEPREFIX (un "Windows" aislado) + metadata.
public struct Bottle {
    public struct Metadata: Codable {
        public var engine: String
        public var windowsVersion: String
        public var created: Date
    }

    public let url: URL
    public var name: String { url.lastPathComponent }
    public var driveC: URL { url.appendingPathComponent("drive_c") }
    public var steamDirectory: URL { driveC.appendingPathComponent("Program Files (x86)/Steam") }
    public var steamInstalled: Bool { FileManager.default.fileExists(atPath: steamDirectory.appendingPathComponent("steam.exe").path) }

    private var metadataURL: URL { url.appendingPathComponent("gamingmac.json") }

    public var metadata: Metadata? {
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(Metadata.self, from: data)
    }

    public init(url: URL) { self.url = url }

    public static func named(_ name: String) -> Bottle {
        Bottle(url: Paths.bottles.appendingPathComponent(name))
    }

    public static func list() -> [Bottle] {
        let dirs = (try? FileManager.default.contentsOfDirectory(at: Paths.bottles, includingPropertiesForKeys: nil)) ?? []
        return dirs.filter { $0.hasDirectoryPath }.map(Bottle.init).sorted { $0.name < $1.name }
    }

    /// Crea el prefix (wineboot) y fija la versión de Windows.
    public static func create(_ name: String, engine: Engine, windowsVersion: String = "win10") throws -> Bottle {
        let bottle = Bottle.named(name)
        guard !FileManager.default.fileExists(atPath: bottle.url.path) else {
            throw GMError("Ya existe el bottle '\(name)' en \(bottle.url.path)")
        }
        try Paths.ensure(bottle.url)
        try Paths.ensure(Paths.logs)
        let log = Paths.logs.appendingPathComponent("bottle-\(name)-create.log")
        let env = Steam.engineEnvironment(engine).merging(["WINEPREFIX": bottle.url.path, "WINEDEBUG": "-all", "WINEARCH": "win64"]) { _, n in n }

        print("Inicializando prefix con \(engine.name)… (log: \(log.path))")
        let boot = try Shell.run(engine.wine, ["wineboot", "--init"], environment: env, log: log)
        guard boot == 0 else { throw GMError("wineboot falló (código \(boot)). Revisa \(log.path)") }
        try Shell.run(engine.wine, ["winecfg", "/v", windowsVersion], environment: env, log: log)
        try Shell.run(engine.wineserver, ["-w"], environment: env, log: log)

        let meta = Metadata(engine: engine.name, windowsVersion: windowsVersion, created: Date())
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(meta).write(to: bottle.metadataURL)
        return bottle
    }
}
