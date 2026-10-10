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

    /// Perfil final listo para lanzar: defaults + perfil del juego.
    public static func resolved(_ id: String) throws -> GameProfile {
        let base = try defaults()
        if id == base.id { return base }
        guard let game = try loadAll().first(where: { $0.id == id }) else {
            throw GMError("No existe el perfil '\(id)'. Usa `gmac profiles` para ver la lista.")
        }
        return base.overlaid(with: game)
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
