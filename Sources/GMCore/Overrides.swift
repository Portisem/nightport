import Foundation

/// Ajustes que el usuario cambia para un juego encima de su perfil curado.
/// Se guardan aparte (Application Support/GamingMac/overrides.json): los perfiles de profiles/ nunca se tocan.
public struct GameOverrides: Codable, Equatable {
    public var backend: GraphicsBackend?
    public var metalHUD: Bool?
    public var metalFX: Bool?
    public var dxr: Bool?
    public var retina: Bool?

    public init() {}

    public var isEmpty: Bool { self == GameOverrides() }
}

public enum OverrideStore {
    static var url: URL { Paths.appSupport.appendingPathComponent("overrides.json") }

    public static func load() -> [String: GameOverrides] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: GameOverrides].self, from: data)) ?? [:]
    }

    public static func save(_ all: [String: GameOverrides]) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(all) else { return }
        try? Paths.ensure(Paths.appSupport)
        try? data.write(to: url, options: .atomic)
    }
}
