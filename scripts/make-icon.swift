// Gera Resources/AppIcon.icns no estilo Liquid Glass, irmão do ícone do Aero: o visor da câmera
// (quatro cantos) com o botão de gravar no meio, em peças de vidro sobre coral.
// Uso: swift scripts/make-icon.swift [preview.png]
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func shadow(_ blur: CGFloat, _ y: CGFloat, _ alpha: CGFloat) {
    let s = NSShadow()
    s.shadowBlurRadius = blur
    s.shadowOffset = NSSize(width: 0, height: y)
    s.shadowColor = NSColor.black.withAlphaComponent(alpha)
    s.set()
}

/// Gradiente só na faixa da borda de dentro do `path`: é o brilho especular do vidro.
func rim(_ path: NSBezierPath, width: CGFloat, colors: [NSColor], locations: [CGFloat], angle: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    // Contorno grosso recortado pelo próprio shape = só a metade de dentro do traço.
    let stroked = NSBezierPath(cgPath: path.cgPath.copy(strokingWithWidth: width * 2, lineCap: .round,
                                                       lineJoin: .round, miterLimit: 10))
    stroked.addClip()
    NSGradient(colors: colors, atLocations: locations, colorSpace: .sRGB)!.draw(in: path.bounds, angle: angle)
    NSGraphicsContext.restoreGraphicsState()
}

/// Peça de vidro fosco: translúcida, com sombra macia, brilho em cima e reflexo embaixo.
func glass(_ path: NSBezierPath, filled: Bool) {
    let rect = path.bounds
    NSGraphicsContext.saveGraphicsState()
    shadow(44, -18, filled ? 0.28 : 0.12)
    color(0x5A0B2A, filled ? 0.35 : 0.1).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let top = filled ? 0.96 : 0.16, bottom = filled ? 0.78 : 0.06
    NSGradient(starting: NSColor.white.withAlphaComponent(top), ending: NSColor.white.withAlphaComponent(bottom))!
        .draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    rim(path, width: filled ? 7 : 13,
        colors: [.white, NSColor.white.withAlphaComponent(filled ? 0.15 : 0.35), NSColor.white.withAlphaComponent(filled ? 0.6 : 0.8)],
        locations: [0, 0.55, 1], angle: -75)
}

/// Canto do visor: um "L" de pontas arredondadas, feito contornando a linha central.
func bracket(_ corner: CGPoint, dx: CGFloat, dy: CGFloat, arm: CGFloat, thickness: CGFloat) -> NSBezierPath {
    let line = CGMutablePath()
    line.move(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
    line.addLine(to: corner)
    line.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
    // normalized() tira a volta que o contorno faz por dentro da quina (virava um triângulo no brilho).
    return NSBezierPath(cgPath: line.copy(strokingWithWidth: thickness, lineCap: .round, lineJoin: .round, miterLimit: 10).normalized())
}

/// Desenha no canvas de 1024×1024 do grid de ícones do macOS (origem embaixo).
func drawIcon() {
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

    NSGraphicsContext.saveGraphicsState()
    shadow(30, -14, 0.3)
    color(0xD9364F).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(colors: [color(0xFF9A5C), color(0xF5445E), color(0xA3164A)],
               atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: body, angle: -90)
    // Luz difusa vinda de cima à esquerda.
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [NSColor.white.withAlphaComponent(0.3).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                          locations: [0, 1])!
    NSGraphicsContext.current!.cgContext.drawRadialGradient(glow, startCenter: CGPoint(x: 320, y: 900), startRadius: 0,
                                                            endCenter: CGPoint(x: 320, y: 900), endRadius: 640, options: [])
    NSGraphicsContext.restoreGraphicsState()
    rim(squircle, width: 5, colors: [NSColor.white.withAlphaComponent(0.55), NSColor.white.withAlphaComponent(0.05),
                                     NSColor.white.withAlphaComponent(0.2)],
        locations: [0, 0.5, 1], angle: -90)

    // Cantos do visor, com a linha central recuada meia espessura pra borda bater em 250/774.
    let thickness: CGFloat = 66, arm: CGFloat = 150
    let near: CGFloat = 250 + thickness / 2, far: CGFloat = 774 - thickness / 2
    for (x, y, dx, dy) in [(near, far, 1, -1), (far, far, -1, -1), (near, near, 1, 1), (far, near, -1, 1)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
        glass(bracket(CGPoint(x: x, y: y), dx: dx, dy: dy, arm: arm, thickness: thickness), filled: true)
    }

    // Botão de gravar: anel de vidro livre com a bolinha cheia dentro.
    glass(NSBezierPath(ovalIn: NSRect(x: 512 - 132, y: 512 - 132, width: 264, height: 264)), filled: false)
    glass(NSBezierPath(ovalIn: NSRect(x: 512 - 84, y: 512 - 84, width: 168, height: 168)), filled: true)
}

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / 1024
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
if CommandLine.arguments.count > 1 {
    try! render(1024).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
print(iconutil.terminationStatus == 0 ? "✓ Resources/AppIcon.icns" : "✗ iconutil falhou")
