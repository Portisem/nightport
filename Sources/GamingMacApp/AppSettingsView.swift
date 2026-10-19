import GMCore
import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject var model: AppModel

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Ajustes").font(NP.display(30, .bold))

                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Estado de tu Mac").npOverline().padding(.vertical, 16)
                            if model.checks.isEmpty {
                                HStack(spacing: 10) {
                                    ProgressView().controlSize(.small)
                                    Text("Revisando…").font(NP.ui(14)).foregroundStyle(NP.textSecondary)
                                }
                                .padding(.bottom, 16)
                            }
                            ForEach(Array(model.checks.enumerated()), id: \.offset) { i, check in
                                if i > 0 { RowDivider() }
                                CheckRow(check: check)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        .npCard(radius: NP.Radius.panel)
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Steam y juegos").npOverline()
                                SteamPill(running: model.steamRunning)
                                Button("Abrir Steam") { model.openSteam() }
                                    .buttonStyle(NPPrimaryButtonStyle())
                                    .disabled(model.steamRunning)
                                    .opacity(model.steamRunning ? 0.45 : 1)
                                Button("Cerrar Steam y juegos") { model.stopAll() }
                                    .buttonStyle(NPSecondaryButtonStyle())
                                Button("Ver logs") { model.openLogs() }
                                    .buttonStyle(NPSecondaryButtonStyle())
                            }
                            .padding(22)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .npCard(radius: NP.Radius.panel)

                            if let mac = model.mac {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Tu Mac para juegos").npOverline()
                                    Text("\(mac.chip) · \(mac.gpuCores) núcleos de GPU · \(Int(mac.memoryGB)) GB")
                                        .font(NP.ui(15, .bold))
                                    Text("Rinde como una \(Capability.nativeEquivalent(mac)) en juegos nativos y como una \(Capability.translatedEquivalent(mac, backend: .d3dmetal)) con traducción (D3DMetal). Estimación.")
                                        .font(NP.ui(13))
                                        .foregroundStyle(NP.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(22)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .npCard(radius: NP.Radius.panel)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                NightportLockup(markSize: 26)
                                Text("Versión \(version) · motor \(model.engineName)")
                                    .font(NP.mono(12))
                                    .foregroundStyle(NP.textSecondary)
                                Text("Tus juegos de Windows, en casa en tu Mac.")
                                    .font(NP.ui(13, .regular))
                                    .foregroundStyle(NP.textSecondary)
                            }
                            .padding(22)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .npCard(radius: NP.Radius.panel)
                        }
                        .frame(width: 300)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 34)
                .padding(.bottom, 24)
            }
            StatusLine()
        }
        .onAppear { model.refreshChecks() }
    }
}

struct CheckRow: View {
    let check: Doctor.Check

    /// Sin jerga: "Bottles" pasa a "Espacios aislados".
    private var title: String {
        check.title
            .replacingOccurrences(of: "Bottles GamingMac", with: "Espacios aislados")
            .replacingOccurrences(of: "Bottles CrossOver (referencia)", with: "Juegos compartidos con CrossOver")
            .replacingOccurrences(of: "Motores", with: "Motor de compatibilidad")
    }

    private var detail: String {
        check.detail.replacingOccurrences(of: " [crossover]", with: "").replacingOccurrences(of: " [upstream]", with: "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: check.ok == nil ? "info.circle" : (check.ok! ? "checkmark.circle.fill" : "exclamationmark.circle.fill"))
                .foregroundStyle(check.ok == nil ? NP.textSecondary : (check.ok! ? NP.support : NP.energy))
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NP.ui(15, .bold))
                Text(detail).font(NP.ui(13, .regular)).foregroundStyle(NP.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
