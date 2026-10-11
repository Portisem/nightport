import GameController
import GMCore
import SwiftUI

struct GameSettingsView: View {
    @EnvironmentObject var model: AppModel
    let profile: GameProfile

    enum Tab: String, CaseIterable, Identifiable {
        case general = "General", graphics = "Gráficos", controls = "Controles", advanced = "Avanzado"
        var id: String { rawValue }
    }
    @State private var tab: Tab = .graphics

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    tabs
                    switch tab {
                    case .general: GeneralTab(profile: profile)
                    case .graphics: GraphicsTab(profile: profile)
                    case .controls: ControlsTab()
                    case .advanced: AdvancedTab(profile: profile)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 30)
                .padding(.bottom, 24)
            }
            StatusLine()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Button { model.screen = .library } label: {
                    Label("Biblioteca", systemImage: "arrow.left")
                        .font(NP.ui(14, .semibold))
                        .foregroundStyle(NP.portalSoft)
                }
                .buttonStyle(.plain)
                Text("\(profile.name) · Ajustes")
                    .font(NP.display(28, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            Button { model.play(profile) } label: { Label("Jugar", systemImage: "play.fill") }
                .buttonStyle(NPPlayButtonStyle())
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    VStack(spacing: 10) {
                        Text(t.rawValue)
                            .font(NP.ui(15, tab == t ? .bold : .medium))
                            .foregroundStyle(tab == t ? NP.textPrimary : NP.textSecondary)
                            .padding(.horizontal, 16)
                        Rectangle().fill(tab == t ? NP.accent : Color.clear).frame(height: 2)
                    }
                    .fixedSize()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: NP.minTarget)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { Rectangle().fill(NP.elevated).frame(height: 1) }
    }
}

// MARK: - Gráficos

struct GraphicsTab: View {
    @EnvironmentObject var model: AppModel
    let profile: GameProfile

    private var user: GameOverrides { model.userOverrides(profile.id) }
    private var backend: GraphicsBackend { model.backend(for: profile) }
    private var candidates: [GraphicsBackend] {
        profile.graphics?.candidates ?? [profile.graphics?.backend ?? .d3dmetal]
    }

    var body: some View {
        // Con espacio: dos columnas como el mockup. En ventanas angostas, la lateral baja.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                mainColumn.frame(minWidth: 520, idealWidth: 520, maxWidth: .infinity)
                sideColumn.frame(width: 300)
            }
            VStack(spacing: 16) {
                mainColumn
                HStack(alignment: .top, spacing: 16) { sideColumn }
            }
        }
    }

    private var sideColumn: some View {
        Group {
            HUDPreview()
            ControllerCard()
        }
    }

    private var mainColumn: some View {
        VStack(spacing: 16) {
            recommendedBanner
            VStack(spacing: 0) {
                SettingRow(title: "Traducción gráfica",
                           detail: "Cómo convertimos los gráficos de Windows para tu Mac.") {
                    Picker("", selection: backendBinding) {
                        Text("Automático (perfil: \(profile.graphics?.backend.label ?? "—"))").tag(GraphicsBackend?.none)
                        ForEach(candidates, id: \.self) { b in Text(b.label).tag(GraphicsBackend?.some(b)) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                RowDivider()
                SettingRow(title: "Límite de FPS",
                           detail: "Un tope estable se siente mejor que FPS altos con caídas. Próximamente.") {
                    FPSLimitPicker()
                }
                if backend == .d3dmetal {
                    RowDivider()
                    ToggleRow(title: "DLSS → MetalFX",
                              detail: "Si el juego usa DLSS, lo traducimos al escalado de Apple. Solo con D3DMetal.",
                              isOn: binding(\.metalFX, profileValue: profile.metalFX ?? false))
                }
                RowDivider()
                ToggleRow(title: "HUD de Metal",
                          detail: "Muestra FPS y tiempo de frame mientras juegas.",
                          isOn: binding(\.metalHUD, profileValue: profile.metalHUD ?? false))
                if backend == .d3dmetal {
                    RowDivider()
                    ToggleRow(title: "Raytracing (DXR)",
                              detail: "Expone DirectX Raytracing al juego. Experimental.",
                              isOn: binding(\.dxr, profileValue: profile.dxr ?? true))
                }
                RowDivider()
                ToggleRow(title: "Modo Retina",
                          detail: "Resolución completa de la pantalla. Más nítido, más exigente.",
                          isOn: binding(\.retina, profileValue: profile.retina ?? false))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .npCard(radius: NP.Radius.panel)
        }
    }

    private var recommendedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: user.isEmpty ? "checkmark.shield" : "slider.horizontal.3")
                .foregroundStyle(user.isEmpty ? NP.support : NP.portalSoft)
            Group {
                if user.isEmpty {
                    Text("Estás usando el ") + Text("perfil recomendado").bold()
                        + Text(". Si cambias algo, siempre puedes volver a él.")
                } else {
                    Text("Estás usando ") + Text("tus ajustes").bold()
                        + Text(" encima del perfil recomendado.")
                }
            }
            .font(NP.ui(14))
            Spacer()
            Button("Restaurar") { model.resetOverrides(profile.id) }
                .buttonStyle(NPSecondaryButtonStyle())
                .disabled(user.isEmpty)
                .opacity(user.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .npCard(radius: NP.Radius.card)
    }

    private var backendBinding: Binding<GraphicsBackend?> {
        Binding(get: { user.backend },
                set: { value in model.updateOverrides(profile.id) { $0.backend = value } })
    }

    /// Interruptor que guarda un override solo si difiere del perfil curado.
    private func binding(_ key: WritableKeyPath<GameOverrides, Bool?>, profileValue: Bool) -> Binding<Bool> {
        Binding(get: { user[keyPath: key] ?? profileValue },
                set: { value in model.updateOverrides(profile.id) { $0[keyPath: key] = (value == profileValue) ? nil : value } })
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(NP.ui(16, .bold))
                Text(detail).font(NP.ui(13, .regular)).foregroundStyle(NP.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            control.fixedSize()
        }
        .padding(.vertical, 16)
    }
}

struct ToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var body: some View {
        SettingRow(title: title, detail: detail) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(NP.accent)
        }
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(NP.elevated).frame(height: 1) }
}

/// 40 / 60 / 120 / Sin tope. El motor aún no aplica topes: se muestra deshabilitado.
struct FPSLimitPicker: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(["40", "60", "120", "Sin tope"], id: \.self) { v in
                Text(v)
                    .font(v == "Sin tope" ? NP.ui(13, .semibold) : NP.mono(13, .medium))
                    .foregroundStyle(v == "Sin tope" ? NP.textPrimary : NP.textSecondary)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(v == "Sin tope" ? NP.elevated : Color.clear,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(4)
        .background(NP.background.opacity(0.4), in: RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous).strokeBorder(NP.elevated))
        .opacity(0.55)
        .accessibilityLabel("Límite de FPS: próximamente")
    }
}

struct HUDPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vista previa del HUD").npOverline()
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
                GridRow {
                    metric("FPS", "58", NP.support, big: true)
                    metric("FRAME", "17.2 ms", NP.textPrimary, big: true)
                }
                GridRow {
                    metric("GPU", "71%", NP.textPrimary)
                    metric("MEMORIA", "6.1 GB", NP.textPrimary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NP.background, in: RoundedRectangle(cornerRadius: NP.Radius.control + 2, style: .continuous))
            Text("Valores de ejemplo. Se muestra en una esquina mientras juegas.")
                .font(NP.ui(12, .regular))
                .foregroundStyle(NP.textSecondary)
        }
        .padding(22)
        .npCard(radius: NP.Radius.panel)
        .accessibilityElement(children: .combine)
    }

    private func metric(_ label: String, _ value: String, _ color: Color, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(NP.mono(10, .medium)).foregroundStyle(NP.textSecondary)
            Text(value).font(NP.mono(big ? 24 : 17, .medium)).foregroundStyle(color)
        }
    }
}

struct ControllerCard: View {
    @State private var controllers: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill").foregroundStyle(NP.portalSoft)
                Text(controllers.isEmpty ? "Sin control conectado" : "Control conectado").font(NP.ui(16, .bold))
            }
            Text(controllers.isEmpty
                 ? "Conecta un control por Bluetooth o USB y aparecerá aquí."
                 : "\(controllers.joined(separator: ", ")). Botones mapeados al estilo Xbox.")
                .font(NP.ui(14, .regular))
                .foregroundStyle(NP.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .npCard(radius: NP.Radius.panel)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in refresh() }
    }

    private func refresh() {
        controllers = GCController.controllers().compactMap { $0.vendorName }
    }
}

// MARK: - General / Controles / Avanzado

struct GeneralTab: View {
    @EnvironmentObject var model: AppModel
    let profile: GameProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InfoRow(label: "Compatibilidad") { CompatBadge(status: profile.compat) }
            RowDivider()
            InfoRow(label: "Gráficos del juego") { NPChip(text: profile.api ?? "—", mono: true) }
            RowDivider()
            InfoRow(label: "Origen") { NPChip(text: profile.sourceLabel) }
            if let when = relativeSession(model.lastSession(profile.id)) {
                RowDivider()
                InfoRow(label: "Última sesión") { Text(when).font(NP.ui(14)).foregroundStyle(NP.textSecondary) }
            }
            if let notes = profile.notes, !notes.isEmpty {
                RowDivider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notas del perfil").font(NP.ui(16, .bold))
                    ForEach(notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(NP.portal).frame(width: 6, height: 6).padding(.top, 7)
                            Text(note).font(NP.ui(14, .regular)).foregroundStyle(NP.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .npCard(radius: NP.Radius.panel)
    }
}

struct InfoRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value
    var body: some View {
        HStack {
            Text(label).font(NP.ui(16, .bold))
            Spacer()
            value
        }
        .frame(minHeight: 56)
    }
}

struct ControlsTab: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mapeo de controles").font(NP.ui(16, .bold))
                Text("Por ahora los controles se mapean al estilo Xbox automáticamente. Pronto podrás ajustar cada botón por juego.")
                    .font(NP.ui(14, .regular))
                    .foregroundStyle(NP.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .npCard(radius: NP.Radius.panel)
            ControllerCard().frame(width: 300)
        }
    }
}

struct AdvancedTab: View {
    @EnvironmentObject var model: AppModel
    let profile: GameProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InfoRow(label: "Ejecutable") {
                Text(profile.launch?.exe ?? "Lanzado por Steam (\(profile.steamAppId.map(String.init) ?? "—"))")
                    .font(NP.mono(12))
                    .foregroundStyle(NP.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            RowDivider()
            InfoRow(label: "Sincronización") { NPChip(text: (profile.sync ?? .msync).rawValue.uppercased(), mono: true) }
            RowDivider()
            InfoRow(label: "AVX en Rosetta") { NPChip(text: (profile.rosettaAVX ?? true) ? "Activado" : "Desactivado") }
            if let env = profile.env, !env.isEmpty {
                RowDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Variables del perfil").font(NP.ui(16, .bold))
                    ForEach(env.keys.sorted(), id: \.self) { key in
                        Text("\(key)=\(env[key] ?? "")").font(NP.mono(12)).foregroundStyle(NP.textSecondary)
                    }
                }
                .padding(.vertical, 16)
            }
            RowDivider()
            InfoRow(label: "Registros de cada partida") {
                Button("Ver logs") { model.openLogs() }.buttonStyle(NPSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .npCard(radius: NP.Radius.panel)
    }
}
