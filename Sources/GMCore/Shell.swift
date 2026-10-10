import Foundation

public enum Shell {
    /// Ejecuta y espera. Si `log` se indica, stdout+stderr van a ese archivo (append).
    @discardableResult
    public static func run(_ executable: URL, _ arguments: [String],
                           environment: [String: String] = [:], log: URL? = nil) throws -> Int32 {
        let p = Process()
        p.executableURL = executable
        p.arguments = arguments
        p.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        if let log {
            if !FileManager.default.fileExists(atPath: log.path) {
                FileManager.default.createFile(atPath: log.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: log)
            handle.seekToEndOfFile()
            p.standardOutput = handle
            p.standardError = handle
        }
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    /// Lanza sin esperar (p. ej. Steam). Devuelve el pid.
    public static func spawn(_ executable: URL, _ arguments: [String],
                             environment: [String: String] = [:], log: URL) throws -> Int32 {
        if !FileManager.default.fileExists(atPath: log.path) {
            FileManager.default.createFile(atPath: log.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: log)
        handle.seekToEndOfFile()
        let p = Process()
        p.executableURL = executable
        p.arguments = arguments
        p.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        p.standardOutput = handle
        p.standardError = handle
        try p.run()
        return p.processIdentifier
    }

    /// Ejecuta y devuelve stdout recortado (para checks rápidos).
    public static func output(_ path: String, _ arguments: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Representación copiable en terminal de un comando con su entorno.
    public static func describe(_ executable: URL, _ arguments: [String], environment: [String: String]) -> String {
        let env = environment.sorted { $0.key < $1.key }.map { "\($0.key)=\(quote($0.value))" }
        return (env + [quote(executable.path)] + arguments.map(quote)).joined(separator: " \\\n  ")
    }

    static func quote(_ s: String) -> String {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./=:,+@%"))
        return s.unicodeScalars.allSatisfy(safe.contains) ? s : "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
