import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: NP.sidebarWidth)
                .background(NP.surface)
                .overlay(alignment: .trailing) { Rectangle().fill(NP.elevated).frame(width: 1) }

            Group {
                switch model.screen {
                case .library:
                    LibraryView()
                case .activity:
                    ActivityView()
                case .settings:
                    AppSettingsView()
                case .game(let id):
                    if let profile = model.profile(id) {
                        GameSettingsView(profile: profile)
                    } else {
                        LibraryView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NP.background)
        }
        .ignoresSafeArea()
        .foregroundStyle(NP.textPrimary)
    }
}

struct Sidebar: View {
    @EnvironmentObject var model: AppModel

    private var inLibrary: Bool {
        switch model.screen {
        case .library, .game: return true
        default: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NightportLockup(markSize: 30)
                .padding(.leading, 14)
                .padding(.top, 52)       // deja libre la zona de los semáforos de la ventana
                .padding(.bottom, 26)

            SidebarItem(title: "Biblioteca", symbol: "square.grid.2x2", active: inLibrary) {
                model.screen = .library
            }
            SidebarItem(title: "Actividad", symbol: "waveform.path.ecg", active: model.screen == .activity) {
                model.screen = .activity
            }
            SidebarItem(title: "Agregar juego", symbol: "plus", soon: true)
            SidebarItem(title: "Compatibilidad", symbol: "magnifyingglass", soon: true)
            SidebarItem(title: "Descargas", symbol: "arrow.down.to.line", soon: true)
            SidebarItem(title: "Ajustes", symbol: "gearshape", active: model.screen == .settings) {
                model.screen = .settings
                model.refreshChecks()
            }

            Spacer()

            SupportCard()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct SidebarItem: View {
    let title: LocalizedStringKey
    let symbol: String
    var active = false
    var soon = false
    var action: () -> Void = {}
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(active ? NP.portalSoft : NP.textSecondary)
                Text(title)
                    .lineLimit(1)
                    .font(NP.ui(15, active ? .bold : .medium))
                    .foregroundStyle(active ? NP.textPrimary : NP.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: NP.minTarget)
            .background((active || (hover && !soon)) ? NP.elevated : Color.clear,
                        in: RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous))
            .contentShape(Rectangle())
            .opacity(soon ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(soon)
        .help(soon ? Text("Próximamente") : Text(verbatim: ""))
        .onHover { hover = $0 }
        .accessibilityHint(soon ? Text("Próximamente") : Text(verbatim: ""))
    }
}

struct SupportCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nightport es open source").font(NP.ui(15, .bold))
            Text("Tu aporte mantiene el motor y los perfiles de la comunidad.")
                .font(NP.ui(13, .regular))
                .foregroundStyle(NP.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {} label: {
                Text("Apoyar").frame(maxWidth: .infinity)
            }
            .help("Próximamente")
            .buttonStyle(NPSecondaryButtonStyle())
            .disabled(true)
            .opacity(0.7)
        }
        .padding(16)
        .npCard(radius: NP.Radius.control + 4)
    }
}
