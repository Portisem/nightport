import Foundation
import CoreGraphics

/// Revisión del sistema: qué tenemos listo y qué falta para jugar.
public enum Doctor {
    public struct Check {
        public let ok: Bool?   // nil = informativo
        public let title: String
        public let detail: String
    }

    /// Sin pantalla activa (Mac bloqueada o en reposo) no llega vsync: la UI de Steam (CEF) y los juegos se congelan.
    public static var displayAsleep: Bool { CGDisplayIsAsleep(CGMainDisplayID()) != 0 }

    public static func run() -> [Check] {
        var checks: [Check] = []
        let fm = FileManager.default

        let arch = Shell.output("/usr/bin/uname", ["-m"]) ?? "?"
        let cpu = Shell.output("/usr/sbin/sysctl", ["-n", "machdep.cpu.brand_string"]) ?? "?"
        let mem = (Shell.output("/usr/sbin/sysctl", ["-n", "hw.memsize"]).flatMap(Double.init) ?? 0) / 1_073_741_824
        checks.append(Check(ok: arch == "arm64", title: "Hardware", detail: "\(cpu), \(Int(mem)) GB, \(arch)"))

        let os = ProcessInfo.processInfo.operatingSystemVersion
        checks.append(Check(ok: os.majorVersion >= 15, title: "macOS", detail: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion) (DXMT pide 15+ para Metal 3.2)"))

        let rosetta = Shell.output("/usr/bin/arch", ["-x86_64", "/usr/bin/true"]) != nil
            && fm.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
        checks.append(Check(ok: rosetta, title: "Rosetta 2", detail: rosetta ? "instalado" : "falta: softwareupdate --install-rosetta"))

        let lowPower = (Shell.output("/usr/bin/pmset", ["-g"]) ?? "").contains("lowpowermode         1")
        checks.append(Check(ok: !lowPower, title: "Modo bajo consumo", detail: lowPower ? "ACTIVO: limita GPU/CPU, desactívalo para jugar" : "desactivado"))

        if let values = try? Paths.home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let free = values.volumeAvailableCapacityForImportantUsage {
            let gb = Double(free) / 1_000_000_000
            checks.append(Check(ok: gb > 60, title: "Disco libre", detail: String(format: "%.0f GB", gb)))
        }

        let engines = Engine.list()
        checks.append(Check(ok: !engines.isEmpty, title: "Motores",
                            detail: engines.isEmpty ? "ninguno en \(Paths.engines.path)"
                                : engines.map { "\($0.name) [\($0.manifest.flavor)] → \($0.availableBackends.map(\.rawValue).joined(separator: ","))" }.joined(separator: "; ")))

        let gptk = engines.contains { $0.backendDirectory(.d3dmetal) != nil }
        checks.append(Check(ok: gptk, title: "D3DMetal (Apple GPTK)", detail: gptk ? "disponible" : "no instalado: necesario para DX12 (Wukong)"))

        let bottles = Bottle.list()
        checks.append(Check(ok: nil, title: "Bottles GamingMac", detail: bottles.isEmpty ? "ninguno" : bottles.map(\.name).joined(separator: ", ")))

        let cxBottles = (try? fm.contentsOfDirectory(atPath: Paths.crossOverBottles.path)) ?? []
        checks.append(Check(ok: nil, title: "Bottles CrossOver (referencia)", detail: cxBottles.isEmpty ? "ninguno" : cxBottles.joined(separator: ", ")))

        let asleep = displayAsleep
        checks.append(Check(ok: !asleep, title: "Pantalla / sesión",
                            detail: asleep ? "pantalla dormida o sesión bloqueada: Steam y los juegos se congelan sin pantalla activa"
                                           : "activa"))

        return checks
    }
}
