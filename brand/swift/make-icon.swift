// Genera AppIcon.icns de Nightport dibujando el logo en vector (sin depender de archivos externos).
// Uso: swift make-icon.swift <salida.icns>
// Reemplaza a tools/app/make-icon.swift (mismo uso, mismo resultado: un .icns).
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}
let harbor = hex(0x151833), border = hex(0x2A2F57), portal = hex(0x7C6CFF), tide = hex(0x3DDBD0), ember = hex(0xFF7A45)

/// El logo vive en una caja de 120x120 unidades con y hacia abajo (igual que los SVG de brand/logo).
/// `small` = versión simplificada para 16 y 32 px: arco más grueso y un solo botón.
func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.shouldAntialias = true

    let s = CGFloat(px) / 1024           // rejilla de íconos de macOS: cuerpo de 824 en 1024
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    harbor.setFill(); bodyPath.fill()
    if px >= 64 { border.setStroke(); bodyPath.lineWidth = max(1, s); bodyPath.stroke() }

    let small = px <= 32
    let markSize = 824 * s * (small ? 0.78 : 0.70)
    let unit = markSize / 120
    let origin = NSPoint(x: (CGFloat(px) - markSize) / 2, y: (CGFloat(px) + markSize) / 2)
    // unidades del logo (y hacia abajo) -> píxeles (y hacia arriba); dy = -7 centra el logo ópticamente
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: origin.x + x * unit, y: origin.y - (y - 7) * unit) }

    let arch = NSBezierPath()
    arch.move(to: p(30, 106))
    arch.line(to: p(30, 58))
    // semicírculo superior: centro (60,58), radio 30, de izquierda a derecha pasando por arriba
    arch.appendArc(withCenter: p(60, 58), radius: 30 * unit, startAngle: 180, endAngle: 0, clockwise: true)
    arch.line(to: p(90, 106))
    arch.lineWidth = (small ? 18 : 12) * unit
    arch.lineCapStyle = .round
    arch.lineJoinStyle = .round
    portal.setStroke(); arch.stroke()

    func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: NSColor) {
        let c0 = p(x, y)
        c.setFill()
        NSBezierPath(ovalIn: NSRect(x: c0.x - r * unit, y: c0.y - r * unit, width: 2 * r * unit, height: 2 * r * unit)).fill()
    }
    if small {
        dot(60, 78, 14, ember)
    } else {
        dot(60, 64, 6, ember)   // botón superior: energía, "jugar"
        dot(48, 76, 6, tide)
        dot(72, 76, 6, tide)
        dot(60, 88, 6, tide)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", out]
try! proc.run(); proc.waitUntilExit()
print("icono: \(out)")
