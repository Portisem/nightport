// NightportTheme.swift
// Tokens de marca de Nightport para SwiftUI (macOS 13+). Fuente de verdad: brand/tokens/tokens.json.
// Copiar a Sources/GamingMacApp/ (o al target de la interfaz). No depende de GMCore.

import AppKit
import CoreText
import SwiftUI

// MARK: - Color

extension Color {
    /// Color sRGB desde un entero 0xRRGGBB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum NP {
    // Paleta
    static let midnight   = Color(hex: 0x0B0D1A)
    static let harbor     = Color(hex: 0x151833)
    static let harborHi   = Color(hex: 0x1B1E3A)
    static let dusk       = Color(hex: 0x24284A)
    static let line       = Color(hex: 0x2A2F57)
    static let portal     = Color(hex: 0x7C6CFF)
    static let portalSoft = Color(hex: 0xA99FFF)
    static let portalDeep = Color(hex: 0x5B48E8)
    static let tide       = Color(hex: 0x3DDBD0)
    static let ember      = Color(hex: 0xFF7A45)
    static let moonlight  = Color(hex: 0xEEF0FF)
    static let mist       = Color(hex: 0x9AA0C3)

    // Semántica: usa estos nombres en las vistas, no la paleta directa.
    static let background    = midnight
    static let surface       = harbor
    static let surfaceInset  = harborHi
    static let elevated      = dusk
    static let border        = line
    static let textPrimary   = moonlight
    static let textSecondary = mist
    static let accent        = portal   // confianza, selección, navegación
    static let support       = tide     // funciona, progreso
    static let energy        = ember    // solo "Jugar" y acciones clave
    static let onAccent      = midnight // texto encima de portal / tide / ember

    enum Radius {
        static let chip: CGFloat = 14
        static let control: CGFloat = 12
        static let card: CGFloat = 20
        static let panel: CGFloat = 24
        static let hero: CGFloat = 28
    }

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    static let sidebarWidth: CGFloat = 232
    static let minTarget: CGFloat = 44
}

// MARK: - Tipografía

extension NP {
    enum Weight { case regular, medium, semibold, bold, extrabold }

    /// Unbounded: títulos y logotipo.
    static func display(_ size: CGFloat, _ weight: Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .regular, .medium: name = "Unbounded-Medium"
        case .semibold: name = "Unbounded-SemiBold"
        case .bold, .extrabold: name = "Unbounded-Bold"
        }
        return .custom(name, size: size, relativeTo: .title)
    }

    /// Manrope: toda la interfaz y el texto.
    static func ui(_ size: CGFloat, _ weight: Weight = .medium) -> Font {
        let name: String
        switch weight {
        case .regular: name = "Manrope-Regular"
        case .medium: name = "Manrope-Medium"
        case .semibold: name = "Manrope-SemiBold"
        case .bold: name = "Manrope-Bold"
        case .extrabold: name = "Manrope-ExtraBold"
        }
        return .custom(name, size: size, relativeTo: .body)
    }

    /// JetBrains Mono: FPS, versiones, rutas, etiquetas técnicas.
    static func mono(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        .custom(weight == .regular ? "JetBrainsMono-Regular" : "JetBrainsMono-Medium", size: size, relativeTo: .caption)
    }

    /// Registra las fuentes de marca para este proceso.
    /// En la .app: Contents/Resources/Fonts (build-app.sh las copia).
    /// En desarrollo (`swift run`): brand/fonts del repo, buscando hacia arriba desde el directorio actual.
    /// Si no las encuentra, SwiftUI cae en la fuente del sistema sin romper nada.
    static func registerFonts() {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("Fonts")) }
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<4 {
            dirs.append(dir.appendingPathComponent("brand/fonts"))
            dir.deleteLastPathComponent()
        }
        guard let fontsDir = dirs.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let files = try? FileManager.default.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil)
        else { return }
        for url in files where url.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Botones

/// El único botón naranja de la pantalla: Jugar.
struct NPPlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NP.ui(17, .extrabold))
            .foregroundStyle(NP.onAccent)
            .padding(.horizontal, 26)
            .frame(minHeight: 52)
            .background(NP.energy.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Acción principal no-juego (Agregar juego, Abrir Steam).
struct NPPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NP.ui(15, .extrabold))
            .foregroundStyle(NP.onAccent)
            .padding(.horizontal, 18)
            .frame(minHeight: NP.minTarget)
            .background(NP.accent.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous))
    }
}

/// Acción secundaria con borde (Ajustes del juego, Ver logs).
struct NPSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NP.ui(15, .bold))
            .foregroundStyle(NP.textPrimary)
            .padding(.horizontal, 18)
            .frame(minHeight: NP.minTarget)
            .background(configuration.isPressed ? NP.elevated : Color.clear,
                        in: RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous).strokeBorder(NP.border))
    }
}

// MARK: - Superficies

struct NPCard: ViewModifier {
    var radius: CGFloat = NP.Radius.card
    func body(content: Content) -> some View {
        content
            .background(NP.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(NP.elevated))
    }
}

extension View {
    func npCard(radius: CGFloat = NP.Radius.card) -> some View { modifier(NPCard(radius: radius)) }

    /// Etiqueta técnica en mayúsculas (CONTINÚA JUGANDO, VISTA PREVIA DEL HUD).
    func npOverline(_ color: Color = NP.textSecondary) -> some View {
        self.font(NP.mono(12, .medium)).tracking(1).textCase(.uppercase).foregroundStyle(color)
    }
}

// MARK: - Compatibilidad

/// Estado de compatibilidad que ve el usuario. Se deriva de `GameProfile.status`.
enum CompatStatus: String, CaseIterable {
    case excelente, jugable, enPruebas, sinProbar, bloqueado

    init(profileStatus: String?) {
        switch profileStatus?.lowercased() {
        case "verificado", "funciona", "excelente": self = .excelente
        case "jugable": self = .jugable
        case "probando", "smoke-test": self = .enPruebas
        case "bloqueado", "anti-cheat": self = .bloqueado
        default: self = .sinProbar
        }
    }

    var label: String {
        switch self {
        case .excelente: return "Excelente"
        case .jugable: return "Jugable"
        case .enPruebas: return "En pruebas"
        case .sinProbar: return "Sin probar"
        case .bloqueado: return "Bloqueado"
        }
    }

    var symbol: String? {
        switch self {
        case .excelente: return "checkmark"
        case .bloqueado: return "lock.fill"
        default: return nil
        }
    }

    /// (fondo, texto, borde). Cada estado tiene texto propio: nunca se distingue solo por color.
    var colors: (bg: Color, fg: Color, border: Color) {
        switch self {
        case .excelente: return (NP.tide, NP.onAccent, NP.tide)
        case .jugable: return (NP.portal, NP.onAccent, NP.portal)
        case .enPruebas: return (.clear, NP.ember, NP.ember)
        case .sinProbar: return (.clear, NP.mist, NP.line)
        case .bloqueado: return (.clear, NP.mist, NP.mist)
        }
    }
}

struct CompatBadge: View {
    let status: CompatStatus
    var body: some View {
        let c = status.colors
        HStack(spacing: 5) {
            if let s = status.symbol { Image(systemName: s).font(.system(size: 10, weight: .heavy)) }
            Text(status.label)
        }
        .font(NP.ui(12, .bold))
        .foregroundStyle(c.fg)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(c.bg, in: Capsule())
        .overlay(Capsule().strokeBorder(c.border))
        .accessibilityLabel("Compatibilidad: \(status.label)")
    }
}

/// Chip neutro para datos (Steam, DXMT, 60 FPS prom.).
struct NPChip: View {
    let text: String
    var mono = false
    var body: some View {
        Text(text)
            .font(mono ? NP.mono(12) : NP.ui(13, .semibold))
            .foregroundStyle(NP.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(NP.elevated, in: Capsule())
    }
}

// MARK: - Logo

/// El símbolo de Nightport dibujado en vector (mismo trazo que brand/logo/nightport-mark.svg).
/// `simplified` = versión de tamaños mínimos (menos de 24 pt): arco más grueso y un solo botón.
struct NightportMark: View {
    var simplified = false
    var monochrome: Color? = nil

    var body: some View {
        Canvas { ctx, size in
            let u = min(size.width, size.height) / 120
            let ox = (size.width - 120 * u) / 2, oy = (size.height - 120 * u) / 2
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * u, y: oy + (y - 7) * u) }

            var arch = Path()
            arch.move(to: pt(30, 106))
            arch.addLine(to: pt(30, 58))
            arch.addArc(center: pt(60, 58), radius: 30 * u, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            arch.addLine(to: pt(90, 106))
            ctx.stroke(arch, with: .color(monochrome ?? NP.portal),
                       style: StrokeStyle(lineWidth: (simplified ? 18 : 12) * u, lineCap: .round, lineJoin: .round))

            func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: Color) {
                let c0 = pt(x, y)
                ctx.fill(Path(ellipseIn: CGRect(x: c0.x - r * u, y: c0.y - r * u, width: 2 * r * u, height: 2 * r * u)),
                         with: .color(monochrome ?? c))
            }
            if simplified {
                dot(60, 78, 14, NP.ember)
            } else {
                dot(60, 64, 6, NP.ember)
                dot(48, 76, 6, NP.tide)
                dot(72, 76, 6, NP.tide)
                dot(60, 88, 6, NP.tide)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Símbolo + logotipo "nightport" para la barra lateral.
struct NightportLockup: View {
    var markSize: CGFloat = 30
    var body: some View {
        HStack(spacing: 10) {
            NightportMark().frame(width: markSize, height: markSize)
            Text("nightport")
                .font(NP.display(markSize * 0.6))
                .tracking(-0.3)
                .foregroundStyle(NP.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nightport")
    }
}
