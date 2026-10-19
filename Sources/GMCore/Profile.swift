import Foundation

/// Traductor de gráficos: cómo se convierte DirectX a Metal.
public enum GraphicsBackend: String, Codable, CaseIterable {
    case d3dmetal   // Apple GPTK: DX11/DX12 -> Metal (cerrado, lo provee el usuario)
    case dxmt       // DX10/DX11 -> Metal (abierto)
    case dxvk       // DX9/10/11 -> Vulkan -> MoltenVK -> Metal (abierto)
    case wined3d    // DX1-11 -> OpenGL (fallback de Wine)
}

public enum SyncMode: String, Codable {
    case msync, esync, none
}

/// Perfil curado por juego. Los campos nil heredan de `_defaults.json`.
public struct GameProfile: Codable {
    public var id: String
    public var name: String
    public var steamAppId: Int?
    public var status: String?
    public var api: String?
    public var launch: Launch?
    public var graphics: Graphics?
    public var sync: SyncMode?
    public var rosettaAVX: Bool?
    public var retina: Bool?
    public var metalHUD: Bool?
    /// Contador de FPS para el registro de sesiones fuera de wined3d: el HUD de Metal, oculto,
    /// escribe en el log el intervalo de cada cuadro (MTL_HUD_LOG_ENABLED).
    public var frameStats: Bool?
    /// D3DMetal: traducir DLSS a MetalFX (D3DM_ENABLE_METALFX, apagado por defecto en GPTK).
    public var metalFX: Bool?
    /// D3DMetal: exponer DirectX Raytracing (D3DM_SUPPORT_DXR).
    public var dxr: Bool?
    public var windowsVersion: String?
    public var wineDebug: String?
    public var env: [String: String]?
    public var dllOverrides: [String: String]?
    public var notes: [String]?

    public struct Launch: Codable {
        public var mode: LaunchMode
        /// Ruta Windows (C:\...) o relativa a steamapps/common cuando mode == exe.
        public var exe: String?
        public var args: [String]?
    }

    public enum LaunchMode: String, Codable {
        case steam  // steam.exe -applaunch <appid>
        case exe    // ejecutable directo
    }

    public struct Graphics: Codable {
        public var backend: GraphicsBackend
        /// Otros traductores que vale la pena comparar en benchmarks.
        public var candidates: [GraphicsBackend]?
    }

    public static func autoID(_ appId: Int) -> String { "steam-\(appId)" }

    public var isAutoDetected: Bool { steamAppId.map { id == Self.autoID($0) } ?? false }

    /// Perfil genérico para un juego de Steam sin perfil curado: lo lanza el propio Steam.
    static func autoDetected(_ app: Steam.InstalledApp) -> GameProfile {
        GameProfile(
            id: autoID(app.appId), name: app.name, steamAppId: app.appId, status: nil, api: nil,
            launch: Launch(mode: .steam, exe: nil, args: nil),
            graphics: Graphics(backend: .wined3d, candidates: nil),
            sync: nil, rosettaAVX: nil, retina: nil, metalHUD: nil, frameStats: nil, metalFX: nil, dxr: nil,
            windowsVersion: nil, wineDebug: nil, env: nil, dllOverrides: nil,
            notes: ["Detectado en tu biblioteca de Steam, sin perfil curado todavía.",
                    "Lo lanza Steam (como su botón Jugar), así que usa el traductor del cliente de Steam (OpenGL)."])
    }

    /// Aplica `other` encima de `self` (other gana; env y dllOverrides se combinan).
    public func overlaid(with other: GameProfile) -> GameProfile {
        var r = self
        r.id = other.id
        r.name = other.name
        r.steamAppId = other.steamAppId ?? steamAppId
        r.status = other.status ?? status
        r.api = other.api ?? api
        r.launch = other.launch ?? launch
        r.graphics = other.graphics ?? graphics
        r.sync = other.sync ?? sync
        r.rosettaAVX = other.rosettaAVX ?? rosettaAVX
        r.retina = other.retina ?? retina
        r.metalHUD = other.metalHUD ?? metalHUD
        r.frameStats = other.frameStats ?? frameStats
        r.metalFX = other.metalFX ?? metalFX
        r.dxr = other.dxr ?? dxr
        r.windowsVersion = other.windowsVersion ?? windowsVersion
        r.wineDebug = other.wineDebug ?? wineDebug
        r.env = (env ?? [:]).merging(other.env ?? [:]) { _, new in new }
        r.dllOverrides = (dllOverrides ?? [:]).merging(other.dllOverrides ?? [:]) { _, new in new }
        r.notes = other.notes
        return r
    }
}

public enum ProfileStore {
    public static func loadAll() throws -> [GameProfile] {
        guard let dir = Paths.profilesDirectory() else { throw GMError("No encuentro la carpeta profiles/ (usa GMAC_PROFILES)") }
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { try decode($0) }
    }

    public static func defaults() throws -> GameProfile {
        guard let dir = Paths.profilesDirectory() else { throw GMError("No encuentro la carpeta profiles/") }
        return try decode(dir.appendingPathComponent("_defaults.json"))
    }

    /// Perfil final listo para lanzar: defaults + perfil del juego. Con `bottle`, también resuelve
    /// los juegos instalados en su Steam que aún no tienen perfil curado (id `steam-<appid>`).
    public static func resolved(_ id: String, bottle: Bottle? = nil) throws -> GameProfile {
        let base = try defaults()
        if id == base.id { return base }
        let all = try loadAll()
        // steam-<appid> de un juego que ya tiene perfil curado → el curado
        if let game = all.first(where: { $0.id == id }) ?? all.first(where: { $0.steamAppId.map(GameProfile.autoID) == id }) {
            return base.overlaid(with: game)
        }
        if let bottle, let app = Steam.installedApps(in: bottle).first(where: { GameProfile.autoID($0.appId) == id }) {
            return base.overlaid(with: .autoDetected(app))
        }
        throw GMError("No existe el perfil '\(id)'. Usa `gmac profiles` para ver la lista.")
    }

    /// Juegos instalados en el Steam del bottle sin perfil curado, ya resueltos sobre los defaults.
    public static func autoDetected(in bottle: Bottle, excluding curated: [GameProfile]) throws -> [GameProfile] {
        let base = try defaults()
        let known = Set(curated.compactMap(\.steamAppId))
        return Steam.installedApps(in: bottle).filter { !known.contains($0.appId) }
            .map { base.overlaid(with: .autoDetected($0)) }
    }

    private static func decode(_ url: URL) throws -> GameProfile {
        do {
            return try JSONDecoder().decode(GameProfile.self, from: Data(contentsOf: url))
        } catch {
            throw GMError("Perfil inválido \(url.lastPathComponent): \(error)")
        }
    }
}

public struct GMError: Error, CustomStringConvertible {
    public let description: String
    public init(_ message: String) { description = message }
}
