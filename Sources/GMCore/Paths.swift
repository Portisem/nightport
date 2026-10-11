import Foundation

/// Ubicaciones en disco. Todo lo pesado (motores, bottles, logs) vive fuera del repo.
public enum Paths {
    public static let home = FileManager.default.homeDirectoryForCurrentUser
    public static let appSupport = home.appendingPathComponent("Library/Application Support/GamingMac")
    public static let engines = appSupport.appendingPathComponent("Engines")
    public static let bottles = appSupport.appendingPathComponent("Bottles")
    public static let logs = home.appendingPathComponent("Library/Logs/GamingMac")
    public static let crossOverBottles = home.appendingPathComponent("Library/Application Support/CrossOver/Bottles")

    /// Carpeta `profiles/` del repo: $GMAC_PROFILES, o se busca hacia arriba desde el cwd y desde el ejecutable.
    public static func profilesDirectory() -> URL? {
        let fm = FileManager.default
        if let custom = ProcessInfo.processInfo.environment["GMAC_PROFILES"] {
            return URL(fileURLWithPath: custom)
        }
        // Dentro de GamingMac.app los perfiles van en Contents/Resources/profiles
        if let res = Bundle.main.resourceURL?.appendingPathComponent("profiles"),
           fm.fileExists(atPath: res.appendingPathComponent("_defaults.json").path) {
            return res
        }
        let starts = [
            URL(fileURLWithPath: fm.currentDirectoryPath),
            URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent(),
        ]
        for start in starts {
            var dir = start
            for _ in 0..<6 {
                let candidate = dir.appendingPathComponent("profiles")
                if fm.fileExists(atPath: candidate.appendingPathComponent("_defaults.json").path) {
                    return candidate
                }
                dir = dir.deletingLastPathComponent()
            }
        }
        return nil
    }

    public static func ensure(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
