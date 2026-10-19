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
        case activity
        case settings
        case game(String)
    }

    @Published var screen: Screen = .library
    @Published var games: [GameProfile] = []
    /// AppIDs instalados por completo en el Steam del bottle.
    @Published var installedAppIds: Set<Int> = []
    @Published var overrides: [String: GameOverrides] = OverrideStore.load()
    @Published var search = ""
    @Published var filter: LibraryFilter = .all
    @Published var featuredID: String?
    @Published var status = "Listo"
    @Published var engineName = "—"
    @Published var steamRunning = false
    @Published var displayAsleep = false
    @Published var checks: [Doctor.Check] = []
    @Published var mac: MacSpecs?
    /// Sesiones grabadas (más reciente primero) y la que se está grabando ahora.
    @Published var sessions: [SessionSummary] = SessionStore.list()
    @Published var live: (profile: GameProfile, sample: SessionSample?)?
    /// Requisitos de Steam por AppID (se piden al ver el juego).
    @Published var requirements: [Int: GameRequirements] = [:]
    private var requirementsRequested: Set<Int> = []

    private var timer: Timer?
    private var curated: [GameProfile] = []
    /// Perfiles internos que no son juegos.
    private static let hidden: Set<String> = ["_defaults", "steam-client"]

    init() {
        reload()
        // Para desarrollo/capturas: `open Nightport.app --args -NPScreen settings|<perfil>`
        if let start = UserDefaults.standard.string(forKey: "NPScreen") {
            screen = start == "settings" ? .settings : start == "activity" ? .activity
                : (profile(start) != nil ? .game(start) : .library)
        }
        Task.detached {
            let specs = MacSpecs.current()
            await MainActor.run { self.mac = specs }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    // MARK: Datos

    func reload() {
        do {
            curated = try ProfileStore.loadAll()
                .filter { !Self.hidden.contains($0.id) && !$0.id.hasPrefix("gmtest") }
                .map { try ProfileStore.resolved($0.id) }
        } catch {
            status = "No pude leer los perfiles de juegos: \(error)"
        }
        engineName = (try? Engine.find(nil).name) ?? "sin motor"
        games = []  // fuerza a refreshLibrary a reconstruir con los perfiles nuevos
        refreshStatus()
    }

    func refreshStatus() {
        steamRunning = Steam.isRunning
        displayAsleep = Doctor.displayAsleep
        refreshLibrary()
        watchForGames()
    }

    // MARK: Actividad

    /// Si hay un juego de la biblioteca corriendo (lanzado desde aquí o desde Steam), graba su sesión.
    private func watchForGames() {
        guard live == nil, steamRunning || games.contains(where: { $0.steamAppId == nil }),
              let bottle = try? Self.bottle() else { return }
        let candidates = games.filter(isInstalled)
        Task.detached {
            guard let game = SessionRecorder.runningGame(among: candidates, bottle: bottle),
                  let recorder = SessionRecorder.attach(profile: game, bottle: bottle) else { return }
            let claimed = await MainActor.run { () -> Bool in
                guard self.live == nil else { return false }
                self.live = (game, nil)
                return true
            }
            guard claimed else { return }
            // La sesión dura lo que dure el juego: hilo propio, no uno del pool de tareas.
            let summary: SessionSummary? = await withCheckedContinuation { done in
                Thread.detachNewThread {
                    let result = try? recorder.run(waitForStart: 10) { sample in
                        Task { @MainActor in self.live = (game, sample) }
                    }
                    done.resume(returning: result ?? nil)
                }
            }
            await MainActor.run {
                self.live = nil
                self.sessions = SessionStore.list()
                if let summary {
                    let fps = summary.avgFPS.map { " · \(Int($0)) FPS de promedio" } ?? ""
                    self.status = "Sesión de \(game.name) guardada: \(Int(summary.duration / 60)) min\(fps)"
                }
            }
        }
    }

    func sessions(for id: String) -> [SessionSummary] { sessions.filter { $0.profileId == id } }

    func openSessionsFolder() {
        try? Paths.ensure(SessionStore.directory)
        NSWorkspace.shared.open(SessionStore.directory)
    }

    /// Curados + juegos instalados en Steam sin perfil. Solo reconstruye si cambió lo instalado
    /// (p. ej. terminó una descarga).
    private func refreshLibrary() {
        guard let bottle = try? Self.bottle() else {
            if games.isEmpty { games = curated.sorted { $0.name < $1.name } }
            return
        }
        let installed = Set(Steam.installedApps(in: bottle).map(\.appId))
        guard installed != installedAppIds || games.isEmpty else { return }
        installedAppIds = installed
        let auto = (try? ProfileStore.autoDetected(in: bottle, excluding: curated)) ?? []
        games = (curated + auto).sorted { $0.name < $1.name }
    }

    /// Sin steamAppId es un ejecutable propio: se asume presente.
    func isInstalled(_ p: GameProfile) -> Bool {
        p.steamAppId.map { installedAppIds.contains($0) } ?? true
    }

    /// Jugar si está instalado; si no, pedirle a Steam que lo instale.
    func primaryAction(_ p: GameProfile) {
        isInstalled(p) ? play(p) : install(p)
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

    // MARK: Capacidad de la Mac

    func loadRequirements(_ p: GameProfile) {
        guard let appId = p.steamAppId, !requirementsRequested.contains(appId) else { return }
        requirementsRequested.insert(appId)
        Task {
            if let req = await Requirements.load(appId: appId) { requirements[appId] = req }
            else { failedRequirements.insert(appId) }
        }
    }

    /// Veredicto para el juego con el traductor que se usaría al jugar. nil mientras carga.
    func capability(_ p: GameProfile) -> CapabilityReport? {
        guard let mac else { return nil }
        let req = p.steamAppId.flatMap { requirements[$0] }
        if p.steamAppId != nil, req == nil, !requirementsFailed(p) { return nil }
        return Capability.report(profile: p, requirements: req, mac: mac, backend: backend(for: p), installed: isInstalled(p))
    }

    /// Ya se pidió y no llegó nada (sin red o Steam no publica requisitos).
    @Published private var failedRequirements: Set<Int> = []
    private func requirementsFailed(_ p: GameProfile) -> Bool { p.steamAppId.map(failedRequirements.contains) ?? true }

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
            let plan = try Launcher.plan(profile: try ProfileStore.resolved(profile.id, bottle: bottle),
                                         engine: engine, bottle: bottle, overrides: user)
            _ = try Launcher.spawn(plan)
            return "\(profile.name) en marcha · \(plan.backend.label)"
        }
    }

    func install(_ profile: GameProfile) {
        guard let appId = profile.steamAppId else { return }
        perform("Abriendo la instalación de \(profile.name) en Steam…") {
            try Steam.requestInstall(appId: appId, bottle: try Self.bottle(), engine: try Engine.find(nil))
            return "Confirma la instalación de \(profile.name) en la ventana de Steam"
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
