import GMCore
import SwiftUI

/// Portada del juego: se carga en tiempo de ejecución desde el CDN de Steam (nunca se empaqueta arte de juegos).
/// Sin conexión o sin steamAppId, muestra la forma de color de los mockups.
struct CoverArt: View {
    let profile: GameProfile
    var cornerRadius: CGFloat = 0

    private var url: URL? {
        profile.steamAppId.flatMap { URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\($0)/header.jpg") }
    }

    var body: some View {
        // Rectangle toma el tamaño que le dan; la imagen va en overlay para no empujar el layout.
        Rectangle()
            .fill(NP.elevated)
            .overlay {
                if let url {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            PlaceholderShape(seed: profile.id)
                        }
                    }
                } else {
                    PlaceholderShape(seed: profile.id)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

/// Forma de color determinista por juego (círculo, cuadrado o arco), como en los mockups.
struct PlaceholderShape: View {
    let seed: String

    private var index: Int { seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } }
    private var color: Color { [NP.portal, NP.ember, NP.tide, NP.moonlight, NP.portalSoft][index % 5] }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.42
            Group {
                switch index % 3 {
                case 0: Circle().fill(color)
                case 1: RoundedRectangle(cornerRadius: side * 0.12, style: .continuous).fill(color)
                default: UnevenArch().fill(color)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// Arco: semicírculo arriba y base recta (eco del símbolo de Nightport).
struct UnevenArch: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.addArc(center: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct SteamPill: View {
    let running: Bool
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(running ? NP.support : NP.textSecondary).frame(width: 8, height: 8)
            Text(running ? "Steam abierto" : "Steam cerrado")
                .font(NP.ui(14, .semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(NP.textPrimary)
        }
        .padding(.horizontal, 14)
        .frame(height: NP.minTarget)
        .background(NP.surface, in: RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous).strokeBorder(NP.elevated))
        .accessibilityElement(children: .combine)
    }
}

struct SearchField: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(NP.textSecondary)
            TextField("", text: $text, prompt: Text("Buscar juego").foregroundColor(NP.textSecondary))
                .textFieldStyle(.plain)
                .font(NP.ui(15))
                .foregroundStyle(NP.textPrimary)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(NP.textSecondary)
                    .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .frame(minWidth: 180, idealWidth: 280, maxWidth: 280, minHeight: NP.minTarget, maxHeight: NP.minTarget)
        .background(NP.surface, in: RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous).strokeBorder(NP.elevated))
    }
}

/// Aviso con borde Ember (pantalla dormida, errores importantes).
struct NoticeBanner: View {
    let text: String
    var symbol = "exclamationmark.triangle.fill"
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(NP.energy)
            Text(text).font(NP.ui(14)).foregroundStyle(NP.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
        .background(NP.surface, in: RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NP.Radius.control, style: .continuous).strokeBorder(NP.energy))
    }
}

/// Píldora de filtro (Todos · 12, Steam…).
struct FilterPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NP.ui(14, .semibold))
                .foregroundStyle(selected ? NP.textPrimary : NP.textSecondary)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(selected ? NP.elevated : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? NP.accent : NP.elevated))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// "hace 2 h", "ayer"… en español.
func relativeSession(_ date: Date?) -> String? {
    guard let date else { return nil }
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "es_MX")
    f.unitsStyle = .full
    return f.localizedString(for: date, relativeTo: Date())
}
