import GMCore
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    if model.displayAsleep {
                        NoticeBanner(text: "La pantalla está dormida o la sesión bloqueada: Steam y los juegos se pausan hasta que vuelvas.")
                    }

                    if let game = model.featured {
                        HeroCard(profile: game, lastPlayed: model.featuredIsLastPlayed)
                    }

                    filters

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 20)], spacing: 20) {
                        ForEach(model.visibleGames, id: \.id) { game in
                            GameCard(profile: game, selected: game.id == model.featured?.id)
                        }
                    }

                    if model.visibleGames.isEmpty {
                        Text("No hay juegos que coincidan con “\(model.search)”.")
                            .font(NP.ui(15))
                            .foregroundStyle(NP.textSecondary)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 34)
                .padding(.bottom, 24)
            }
            StatusLine()
        }
    }

    private var header: some View {
        // En ventanas angostas, la píldora y el botón se compactan para no desbordar.
        ViewThatFits(in: .horizontal) {
            headerRow(compact: false)
            headerRow(compact: true)
        }
    }

    private func headerRow(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Text("Biblioteca").font(NP.display(30, .bold)).lineLimit(1).fixedSize()
            Spacer(minLength: 16)
            if compact {
                Circle().fill(model.steamRunning ? NP.support : NP.textSecondary)
                    .frame(width: 10, height: 10)
                    .frame(width: NP.minTarget, height: NP.minTarget)
                    .help(model.steamRunning ? "Steam abierto" : "Steam cerrado")
                    .accessibilityLabel(model.steamRunning ? "Steam abierto" : "Steam cerrado")
            } else {
                SteamPill(running: model.steamRunning)
            }
            SearchField(text: $model.search)
            Button { model.openSteam() } label: {
                if compact {
                    Image(systemName: "arrow.up.forward.app").accessibilityLabel("Abrir Steam")
                } else {
                    Label("Abrir Steam", systemImage: "arrow.up.forward.app")
                }
            }
            .buttonStyle(NPPrimaryButtonStyle())
            .help("Abrir Steam")
            .disabled(model.steamRunning)
            .opacity(model.steamRunning ? 0.45 : 1)
        }
    }

    private var filters: some View {
        HStack(spacing: 10) {
            ForEach(LibraryFilter.allCases) { f in
                let count = f == .all ? " · \(model.games.count)" : ""
                FilterPill(title: f.rawValue + count, selected: model.filter == f) { model.filter = f }
            }
        }
    }
}

struct HeroCard: View {
    @EnvironmentObject var model: AppModel
    let profile: GameProfile
    let lastPlayed: Bool

    private var sessionText: String {
        var parts: [String] = []
        if let when = relativeSession(model.lastSession(profile.id)) { parts.append("Última sesión: \(when).") }
        parts.append(model.userOverrides(profile.id).isEmpty ? "Perfil recomendado aplicado." : "Con tus ajustes personalizados.")
        return parts.joined(separator: " ")
    }

    var body: some View {
        HStack(spacing: 0) {
            CoverArt(profile: profile)
                .frame(minWidth: 180, idealWidth: 380, maxWidth: 380)
                .frame(maxHeight: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 14) {
                Text(lastPlayed ? "Continúa jugando" : "Seleccionado").npOverline(NP.support)
                Text(profile.name)
                    .font(NP.display(30, .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    CompatBadge(status: profile.compat)
                    NPChip(text: profile.sourceLabel)
                    NPChip(text: model.backend(for: profile).label, mono: true)
                    if let api = profile.api?.split(separator: " ").first {
                        NPChip(text: String(api), mono: true)
                    }
                }
                Text(sessionText)
                    .font(NP.ui(15, .regular))
                    .foregroundStyle(NP.textSecondary)
                HStack(spacing: 12) {
                    Button { model.play(profile) } label: {
                        Label("Jugar", systemImage: "play.fill")
                    }
                    .buttonStyle(NPPlayButtonStyle())
                    Button("Ajustes del juego") { model.screen = .game(profile.id) }
                        .buttonStyle(NPSecondaryButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .frame(height: 290)
        .background(NP.surface)
        .clipShape(RoundedRectangle(cornerRadius: NP.Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NP.Radius.panel, style: .continuous).strokeBorder(NP.elevated))
    }
}

struct GameCard: View {
    @EnvironmentObject var model: AppModel
    let profile: GameProfile
    let selected: Bool
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverArt(profile: profile)
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 10) {
                Text(profile.name)
                    .font(NP.ui(16, .bold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    CompatBadge(status: profile.compat)
                    Text(profile.sourceLabel).font(NP.ui(13)).foregroundStyle(NP.textSecondary)
                }
            }
            .padding(16)
        }
        .background(NP.surface)
        .clipShape(RoundedRectangle(cornerRadius: NP.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NP.Radius.card, style: .continuous)
            .strokeBorder(selected ? NP.accent : (hover ? NP.border : NP.elevated), lineWidth: selected ? 2 : 1))
        .scaleEffect(hover ? 1.015 : 1)
        .animation(.easeOut(duration: 0.15), value: hover)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(count: 2) { model.play(profile) }
        .onTapGesture { model.featuredID = profile.id }
        .contextMenu {
            Button("Jugar") { model.play(profile) }
            Button("Ajustes del juego") { model.screen = .game(profile.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Selecciona el juego. Doble clic para jugar.")
    }
}

/// Línea de estado inferior (mono, secundaria).
struct StatusLine: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack {
            Text(model.status)
            Spacer()
            Text("motor \(model.engineName)")
        }
        .font(NP.mono(12))
        .foregroundStyle(NP.textSecondary)
        .padding(.horizontal, 36)
        .frame(height: 34)
        .overlay(alignment: .top) { Rectangle().fill(NP.elevated).frame(height: 1) }
    }
}
