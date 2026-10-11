import AppKit
import GMCore
import SwiftUI

@main
struct NightportApp: App {
    @StateObject private var model = AppModel()

    init() {
        NP.registerFonts()
    }

    var body: some Scene {
        WindowGroup("Nightport") {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 1000, minHeight: 640)
                .preferredColorScheme(.dark)
                .background(NP.background)
        }
        .defaultSize(width: 1320, height: 860)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Abrir Steam") { model.openSteam() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(model.steamRunning)
            }
            CommandMenu("Juegos") {
                Button("Ver logs") { model.openLogs() }
                Button("Cerrar Steam y juegos") { model.stopAll() }
                    .keyboardShortcut("q", modifiers: [.command, .shift])
            }
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "Todos", steam = "Steam", other = "Ejecutables"
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    enum Screen: Hashable {
        case library
        case settings
        case game(String)
    }

    @Published var screen: Screen = .library
    @Published var games: [GameProfile] = []
    @Published var overrides: [String: GameOverrides] = OverrideStore.load()
    @Published var search = ""
    @Published var filter: LibraryFilter = .all
    @Published var featuredID: String?
    @Published var status = "Listo"
    @Published var engineName = "—"
    @Published var steamRunning = false
    @Published var displayAsleep = false
    @Published var checks: [Doctor.Check] = []

    private var timer: Timer?
    /// Perfiles internos que no son juegos.
    private static let hidden: Set<String> = ["_defaults", "steam-client"]

    init() {
        reload()
        // Para desarrollo/capturas: `open Nightport.app --args -NPScreen settings|<perfil>`
        if let start = UserDefaults.standard.string(forKey: "NPScreen") {
            screen = start == "settings" ? .settings : (profile(start) != nil ? .game(start) : .library)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    // MARK: Datos

    func reload() {
        do {
            games = try ProfileStore.loadAll()
                .filter { !Self.hidden.contains($0.id) && !$0.id.hasPrefix("gmtest") }
                .map { try ProfileStore.resolved($0.id) }
                .sorted { $0.name < $1.name }
        } catch {
            status = "No pude leer los perfiles de juegos: \(error)"
        }
        engineName = (try? Engine.find(nil).name) ?? "sin motor"
        refreshStatus()
    }

    func refreshStatus() {
        steamRunning = Steam.isRunning
        displayAsleep = Doctor.displayAsleep
    }

    func refreshChecks() {
        Task.detached {
            let result = Doctor.run()
            await MainActor.run { self.checks = result }
        }
    }

    func profile(_ id: String) -> GameProfile? { games.first { $0.id == id } }

    var visibleGames: [GameProfile] {
        games.filter { game in
            let matchesSearch = search.isEmpty || game.name.localizedCaseInsensitiveContains(search)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .steam: matchesFilter = game.steamAppId != nil
            case .other: matchesFilter = game.steamAppId == nil
            }
            return matchesSearch && matchesFilter
        }
    }

    /// Juego destacado: el que el usuario eligió, si no el último jugado, si no el primero.
    var featured: GameProfile? {
        if let id = featuredID, let p = profile(id) { return p }
        if let id = UserDefaults.standard.string(forKey: "lastPlayedProfile"), let p = profile(id) { return p }
        return games.first
    }

    var featuredIsLastPlayed: Bool {
        featuredID == nil || featuredID == UserDefaults.standard.string(forKey: "lastPlayedProfile")
    }

    func lastSession(_ id: String) -> Date? {
        UserDefaults.standard.object(forKey: "lastSession.\(id)") as? Date
    }

    // MARK: Ajustes por juego

    func userOverrides(_ id: String) -> GameOverrides { overrides[id] ?? GameOverrides() }

    func updateOverrides(_ id: String, _ change: (inout GameOverrides) -> Void) {
        var o = userOverrides(id)
        change(&o)
        overrides[id] = o.isEmpty ? nil : o
        OverrideStore.save(overrides)
    }

    func resetOverrides(_ id: String) {
        overrides[id] = nil
        OverrideStore.save(overrides)
    }

    func backend(for p: GameProfile) -> GraphicsBackend {
        userOverrides(p.id).backend ?? p.graphics?.backend ?? .d3dmetal
    }

    // MARK: Acciones

    func openSteam() {
        perform("Abriendo Steam en su espacio aislado…") {
            let plan = try Steam.start(bottle: try Self.bottle(), engine: try Engine.find(nil))
            return "Steam abierto · traductor \(plan.backend.label)"
        }
    }

    func play(_ profile: GameProfile) {
        UserDefaults.standard.set(profile.id, forKey: "lastPlayedProfile")
        UserDefaults.standard.set(Date(), forKey: "lastSession.\(profile.id)")
        let user = Launcher.Overrides(userOverrides(profile.id))
        let needsSteam = profile.steamAppId != nil && !steamRunning
        perform("Preparando \(profile.name)…") {
            let engine = try Engine.find(nil)
            let bottle = try Self.bottle()
            if needsSteam {
                try Steam.start(bottle: bottle, engine: engine)
                Thread.sleep(forTimeInterval: 8)  // que Steam inicie sesión antes del juego
            }
            let plan = try Launcher.plan(profile: try ProfileStore.resolved(profile.id),
                                         engine: engine, bottle: bottle, overrides: user)
            _ = try Launcher.spawn(plan)
            return "\(profile.name) en marcha · \(plan.backend.label)"
        }
    }

    func stopAll() {
        perform("Cerrando Steam y juegos…") {
            let engine = try Engine.find(nil)
            let env = Steam.engineEnvironment(engine).merging(["WINEPREFIX": try Self.bottle().url.path]) { _, n in n }
            try Shell.run(engine.wineserver, ["-k"], environment: env)
            return "Steam y juegos cerrados"
        }
    }

    func openLogs() {
        try? Paths.ensure(Paths.logs)
        NSWorkspace.shared.open(Paths.logs)
    }

    private static func bottle() throws -> Bottle {
        let bottles = Bottle.list()
        guard let b = bottles.first(where: { $0.name == "Steam" }) ?? bottles.first else {
            throw GMError("Aún no hay un espacio aislado para Steam.")
        }
        return b
    }

    private func perform(_ message: String, _ work: @escaping () throws -> String) {
        status = message
        Task.detached {
            let result: String
            do { result = try work() } catch { result = "No se pudo: \(error)" }
            await MainActor.run {
                self.status = result
                self.refreshStatus()
            }
        }
    }
}

extension GraphicsBackend {
    var label: String {
        switch self {
        case .d3dmetal: return "D3DMetal"
        case .dxmt: return "DXMT"
        case .dxvk: return "DXVK"
        case .wined3d: return "OpenGL"
        }
    }
}

extension GameProfile {
    var sourceLabel: String { steamAppId != nil ? "Steam" : "Ejecutable" }
    var compat: CompatStatus { CompatStatus(profileStatus: status) }
}
