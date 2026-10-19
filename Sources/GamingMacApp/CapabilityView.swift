import GMCore
import SwiftUI

extension CapabilityReport.Level {
    /// (fondo, texto, borde), con texto propio en cada nivel: nunca solo color.
    var colors: (bg: Color, fg: Color, border: Color) {
        switch self {
        case .holgado: return (NP.tide, NP.onAccent, NP.tide)
        case .recomendado: return (.clear, NP.tide, NP.tide)
        case .minimo: return (.clear, NP.ember, NP.ember)
        case .insuficiente: return (NP.ember, NP.onAccent, NP.ember)
        }
    }

    var symbol: String {
        switch self {
        case .holgado: return "bolt.fill"
        case .recomendado: return "checkmark"
        case .minimo: return "minus"
        case .insuficiente: return "exclamationmark"
        }
    }
}

/// Píldora con el veredicto ("Va sobrado").
struct CapabilityBadge: View {
    let level: CapabilityReport.Level?
    var body: some View {
        let c = level?.colors ?? (.clear, NP.mist, NP.line)
        HStack(spacing: 5) {
            Image(systemName: level?.symbol ?? "questionmark").font(.system(size: 10, weight: .heavy))
            Text(level?.label ?? String(localized: "Sin datos"))
        }
        .font(NP.ui(12, .bold))
        .foregroundStyle(c.fg)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(c.bg, in: Capsule())
        .overlay(Capsule().strokeBorder(c.border))
        .fixedSize()
        .accessibilityLabel("En tu Mac: \(level?.label ?? String(localized: "sin datos"))")
    }
}

/// Tarjeta "¿Corre en tu Mac?": tu Mac contra los requisitos de Windows que publica Steam.
struct CapabilityCard: View {
    @EnvironmentObject var model: AppModel
    let profile: GameProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("¿Corre en tu Mac?").font(NP.ui(18, .bold))
                Spacer()
                if let r = model.capability(profile) { CapabilityBadge(level: r.level) }
            }
            .padding(.top, 20)
            .padding(.bottom, 6)

            if let r = model.capability(profile) {
                Text(r.summary)
                    .font(NP.ui(14))
                    .foregroundStyle(NP.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
                table(r)
                footer(r)
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Comparando tu Mac con los requisitos de Steam…").font(NP.ui(14)).foregroundStyle(NP.textSecondary)
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .npCard(radius: NP.Radius.panel)
        .onAppear { model.loadRequirements(profile) }
    }

    private func table(_ r: CapabilityReport) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 0) {
            GridRow {
                Text(verbatim: "")
                header("Tu Mac")
                header("Mínimo")
                header("Recomendado")
            }
            .padding(.bottom, 8)
            ForEach(r.rows, id: \.resource) { row in
                Divider().overlay(NP.elevated).gridCellColumns(4)
                GridRow {
                    HStack(spacing: 8) {
                        Image(systemName: row.level.map { $0 >= .recomendado ? "checkmark.circle.fill" : "exclamationmark.circle.fill" } ?? "circle.dashed")
                            .foregroundStyle(row.level.map { $0 >= .recomendado ? NP.support : NP.energy } ?? NP.textSecondary)
                        Text(row.resource).font(NP.ui(14, .bold))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(verbatim: "\(row.resource): \(row.level?.label ?? String(localized: "sin datos"))"))
                    cell(row.mac, primary: true)
                    cell(row.minimum ?? "—")
                    cell(row.recommended ?? "—")
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func footer(_ r: CapabilityReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(r.warnings, id: \.self) { w in
                Label(w, systemImage: "exclamationmark.triangle.fill")
                    .font(NP.ui(13))
                    .foregroundStyle(NP.energy)
            }
            if let rec = r.recommendedMac {
                HStack(spacing: 6) {
                    Text("Mac recomendada:").font(NP.ui(13, .bold))
                    Text(rec).font(NP.ui(13))
                }
            }
            Text("Estimación con los requisitos de Windows de Steam y el costo de traducir con \(model.backend(for: profile).label). Los benchmarks del perfil, cuando existan, mandan sobre esto.")
                .font(NP.ui(12))
                .foregroundStyle(NP.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private func header(_ s: LocalizedStringKey) -> some View {
        Text(s).font(NP.mono(11, .medium)).foregroundStyle(NP.textSecondary).textCase(.uppercase)
    }

    private func cell(_ s: String, primary: Bool = false) -> some View {
        Text(s)
            .font(NP.ui(13, primary ? .semibold : .regular))
            .foregroundStyle(primary ? NP.textPrimary : NP.textSecondary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
