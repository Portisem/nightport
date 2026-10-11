import AppKit
import GMCore
import SwiftUI

@main
struct GamingMacApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("GamingMac") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var games: [GameProfile] = []
    @Published var backendChoice: [String: GraphicsBackend] = [:]
    @Published var hud = false
    @Published var status = "Listo"
    @Published var engineName = "—"
    @Published var steamRunning = false
    @Published var displayAsleep = false
    private var timer: Timer?

    /// Perfiles internos que no son juegos.
    private static let hidden: Set<String> = ["_defaults", "steam-client"]

    init() {
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    func reload() {
        do {
            games = try ProfileStore.loadAll().filter { !Self.hidden.contains($0.id) && !$0.id.hasPrefix("gmtest") }
        } catch {
            status = "Error al leer perfiles: \(error)"
        }
        engineName = (try? Engine.find(nil).name) ?? "sin motor"
        refreshStatus()
    }

    func refreshStatus() {
        steamRunning = Steam.isRunning
        displayAsleep = Doctor.displayAsleep
    }

    func openSteam() {
        perform("Abriendo Steam…") {
            let plan = try Steam.start(bottle: try Self.bottle(), engine: try Engine.find(nil))
            return "Steam abierto (\(plan.backend.label))"
        }
    }

    func play(_ profile: GameProfile) {
        let backend = backendChoice[profile.id]
        let hud = self.hud
        perform("Lanzando \(profile.name)…") {
            let plan = try Launcher.plan(profile: try ProfileStore.resolved(profile.id),
                                         engine: try Engine.find(nil),
                                         bottle: try Self.bottle(),
                                         overrides: .init(backend: backend, metalHUD: hud ? true : nil))
            _ = try Launcher.spawn(plan)
            return "\(profile.name) iniciado con \(plan.backend.label)"
        }
    }

    func stopAll() {
        perform("Cerrando Steam y juegos…") {
            let engine = try Engine.find(nil)
            let env = Steam.engineEnvironment(engine).merging(["WINEPREFIX": try Self.bottle().url.path]) { _, n in n }
            try Shell.run(engine.wineserver, ["-k"], environment: env)
            return "Todo cerrado"
        }
    }

    func openLogs() {
        try? Paths.ensure(Paths.logs)
        NSWorkspace.shared.open(Paths.logs)
    }

    private static func bottle() throws -> Bottle {
        let bottles = Bottle.list()
        guard let b = bottles.first(where: { $0.name == "Steam" }) ?? bottles.first else {
            throw GMError("No hay bottles. Crea uno con: gmac bottle create Steam")
        }
        return b
    }

    private func perform(_ message: String, _ work: @escaping () throws -> String) {
        status = message
        Task.detached {
            let result: String
            do { result = try work() } catch { result = "Error: \(error)" }
            await MainActor.run {
                self.status = result
                self.refreshStatus()
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GamingMac").font(.title2.bold())
                    Text("Motor \(model.engineName)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label(model.steamRunning ? "Steam abierto" : "Steam cerrado",
                      systemImage: model.steamRunning ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(model.steamRunning ? Color.green : Color.secondary)
                    .font(.callout)
                Button { model.openSteam() } label: {
                    Label("Abrir Steam", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.steamRunning)
            }
            .padding()

            if model.displayAsleep {
                Label("La pantalla está dormida o la sesión bloqueada: Steam y los juegos se congelan.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Divider()

            List(model.games, id: \.id) { profile in
                GameRow(profile: profile)
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Toggle("Mostrar FPS (HUD de Metal)", isOn: $model.hud)
                Spacer()
                Button("Ver logs") { model.openLogs() }
                Button("Cerrar todo", role: .destructive) { model.stopAll() }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Text(model.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
    }
}

struct GameRow: View {
    @EnvironmentObject var model: AppModel
    let profile: GameProfile

    private var options: [GraphicsBackend] {
        profile.graphics?.candidates ?? [profile.graphics?.backend ?? .d3dmetal]
    }

    private var selection: Binding<GraphicsBackend> {
        Binding(get: { model.backendChoice[profile.id] ?? profile.graphics?.backend ?? .d3dmetal },
                set: { model.backendChoice[profile.id] = $0 })
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name).font(.headline)
                Text([profile.api, profile.status].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = profile.notes?.first {
                    Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            Picker("Traductor", selection: selection) {
                ForEach(options, id: \.self) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .frame(width: 120)
            .disabled(options.count < 2)
            Button("Jugar") { model.play(profile) }
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
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
