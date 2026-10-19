import GMCore
import SwiftUI

/// Actividad: lo que se midió en cada sesión de juego y qué mejorar.
struct ActivityView: View {
    @EnvironmentObject var model: AppModel

    private var totalHours: Double { model.sessions.reduce(0) { $0 + $1.duration } / 3600 }

    private var byGame: [(id: String, name: String, sessions: [SessionSummary])] {
        Dictionary(grouping: model.sessions, by: \.profileId)
            .map { (id: $0.key, name: $0.value.first?.name ?? $0.key, sessions: $0.value) }
            .sorted { $0.sessions.reduce(0) { $0 + $1.duration } > $1.sessions.reduce(0) { $0 + $1.duration } }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Actividad").font(NP.display(30, .bold))

                    if let live = model.live { LiveSessionCard(profile: live.profile, sample: live.sample) }

                    if model.sessions.isEmpty {
                        empty
                    } else {
                        stats
                        Text("Por juego").npOverline()
                        ForEach(byGame, id: \.id) { g in GameActivityCard(name: g.name, sessions: g.sessions) }
                        Text("Sesiones recientes").npOverline()
                        sessionList
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill").foregroundStyle(NP.textSecondary)
                        Text("Todo se guarda solo en tu Mac. Nada sale de ella.")
                            .font(NP.ui(13)).foregroundStyle(NP.textSecondary)
                        Spacer()
                        Button("Abrir carpeta de datos") { model.openSessionsFolder() }
                            .buttonStyle(NPSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 34)
                .padding(.bottom, 24)
            }
            StatusLine()
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aún no hay sesiones").font(NP.ui(18, .bold))
            Text("Mientras Nightport esté abierto, cada partida de tu biblioteca (desde aquí o desde Steam) queda registrada: duración, FPS, CPU, GPU, memoria y temperatura. Con eso te decimos qué ajustar.")
                .font(NP.ui(14)).foregroundStyle(NP.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .npCard(radius: NP.Radius.panel)
    }

    private var stats: some View {
        let fpsSessions = model.sessions.compactMap(\.avgFPS)
        return HStack(spacing: 16) {
            StatTile(label: "Tiempo jugado", value: totalHours >= 1 ? String(format: "%.1f h", totalHours) : "\(Int(totalHours * 60)) min")
            StatTile(label: "Sesiones", value: "\(model.sessions.count)")
            StatTile(label: "Más jugado", value: byGame.first?.name ?? "—", small: true)
            StatTile(label: "FPS promedio", value: fpsSessions.isEmpty ? "—" : "\(Int(fpsSessions.reduce(0, +) / Double(fpsSessions.count)))")
        }
    }

    private var sessionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.sessions.prefix(30).enumerated()), id: \.element.id) { i, s in
                if i > 0 { RowDivider() }
                SessionRow(session: s)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .npCard(radius: NP.Radius.panel)
    }
}

struct StatTile: View {
    let label: LocalizedStringKey
    let value: String
    var small = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(NP.mono(11, .medium)).foregroundStyle(NP.textSecondary).textCase(.uppercase)
            Text(value)
                .font(small ? NP.ui(17, .bold) : NP.mono(26, .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .npCard(radius: NP.Radius.card)
        .accessibilityElement(children: .combine)
    }
}

/// Lo que se está midiendo en este momento.
struct LiveSessionCard: View {
    let profile: GameProfile
    let sample: SessionSample?

    var body: some View {
        HStack(spacing: 18) {
            Circle().fill(NP.support).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text("Grabando ahora").npOverline(NP.support)
                Text(profile.name).font(NP.ui(17, .bold))
            }
            Spacer()
            if let s = sample {
                metric("FPS", s.fps.map { "\(Int($0))" } ?? "—")
                metric("CPU", "\(Int(s.cpu))%")
                metric("GPU", s.gpu.map { "\(Int($0))%" } ?? "—")
                metric("MEMORIA", String(format: "%.1f GB", s.memoryMB / 1024))
                metric("TIEMPO", "\(Int(s.t / 60)) min")
            } else {
                Text("Esperando la primera muestra…").font(NP.ui(13)).foregroundStyle(NP.textSecondary)
            }
        }
        .padding(22)
        .npCard(radius: NP.Radius.panel)
        .overlay(RoundedRectangle(cornerRadius: NP.Radius.panel, style: .continuous).strokeBorder(NP.support.opacity(0.6)))
    }

    private func metric(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(NP.mono(10, .medium)).foregroundStyle(NP.textSecondary)
            Text(value).font(NP.mono(18, .medium))
        }
        .frame(minWidth: 64, alignment: .leading)
    }
}

/// Resumen por juego + sugerencias de la sesión más reciente.
struct GameActivityCard: View {
    @EnvironmentObject var model: AppModel
    let name: String
    let sessions: [SessionSummary]

    var body: some View {
        let last = sessions[0]
        let hours = sessions.reduce(0) { $0 + $1.duration } / 3600
        let candidates = model.profile(last.profileId)?.graphics?.candidates ?? []
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name).font(NP.ui(17, .bold))
                Spacer()
                let count = sessions.count == 1 ? String(localized: "\(sessions.count) sesión") : String(localized: "\(sessions.count) sesiones")
                Text(count + " · " + (hours >= 1 ? String(format: "%.1f h", hours) : "\(Int(hours * 60)) min"))
                    .font(NP.mono(12)).foregroundStyle(NP.textSecondary)
            }
            InsightList(insights: SessionInsights.analyze(last, candidates: candidates),
                        comparison: SessionInsights.backendComparison(sessions))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .npCard(radius: NP.Radius.panel)
    }
}

struct InsightList: View {
    let insights: [SessionInsights.Insight]
    var comparison: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if insights.isEmpty && comparison == nil {
                Text("Sin observaciones: la sesión no mostró problemas.").font(NP.ui(14)).foregroundStyle(NP.textSecondary)
            }
            ForEach(insights, id: \.self) { i in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbol(i.kind)).foregroundStyle(color(i.kind)).frame(width: 16).padding(.top, 2)
                    Text(i.text).font(NP.ui(14)).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let comparison {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "chart.bar.fill").foregroundStyle(NP.portalSoft).frame(width: 16).padding(.top, 2)
                    Text(comparison).font(NP.ui(14)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func symbol(_ k: SessionInsights.Insight.Kind) -> String {
        switch k { case .good: return "checkmark.circle.fill"; case .tip: return "lightbulb.fill"; case .problem: return "exclamationmark.triangle.fill" }
    }
    private func color(_ k: SessionInsights.Insight.Kind) -> Color {
        switch k { case .good: return NP.support; case .tip: return NP.portalSoft; case .problem: return NP.energy }
    }
}

struct SessionRow: View {
    let session: SessionSummary

    private var when: String {
        let f = DateFormatter()
        f.locale = appLocale
        f.setLocalizedDateFormatFromTemplate("dMMMHHmm")
        return f.string(from: session.start)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.name).font(NP.ui(15, .bold)).lineLimit(1)
                Text("\(when) · \(Int(session.duration / 60)) min").font(NP.ui(12)).foregroundStyle(NP.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            NPChip(text: session.backend.uppercased(), mono: true)
            cell("FPS", session.avgFPS.map { "\(Int($0)) / \(Int(session.lowFPS ?? $0))" } ?? "—", help: "Promedio / 5% más lento")
            cell("CPU", "\(Int(session.avgCPU))%")
            cell("GPU", session.avgGPU.map { "\(Int($0))%" } ?? "—")
            cell("MEM", String(format: "%.1f GB", session.peakMemoryMB / 1024))
            if session.crashed { Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(NP.energy).help(Text("Terminó con error")) }
            if session.maxThermal >= 2 { Image(systemName: "thermometer.high").foregroundStyle(NP.energy).help(Text("Se calentó")) }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func cell(_ label: LocalizedStringKey, _ value: String, help: LocalizedStringKey? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(NP.mono(10, .medium)).foregroundStyle(NP.textSecondary)
            Text(value).font(NP.mono(13, .medium))
        }
        .frame(width: 74, alignment: .leading)
        .help(help.map { Text($0) } ?? Text(verbatim: ""))
    }
}
