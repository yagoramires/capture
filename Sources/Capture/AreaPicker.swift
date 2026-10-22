import AppKit

/// Escurece todos os monitores e deixa arrastar um retângulo, como o ⌘⇧4.
/// Devolve a área em coordenadas globais com origem no topo do monitor principal
/// (o formato do `-R` do screencapture), ou nil se a pessoa apertar Esc.
final class AreaPicker {
    private var windows: [NSWindow] = []
    private var completion: ((CGRect?) -> Void)?

    func pick(_ completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        windows = NSScreen.screens.map { screen in
            let window = PickerWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.setFrame(screen.frame, display: false)
            let view = PickerView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onFinish = { [weak self, weak window] rect in
                guard let self else { return }
                self.finish(rect.flatMap { local in window.map { $0.convertToScreen(local) } })
            }
            window.contentView = view
            return window
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.orderFrontRegardless() }
        let current = windows.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? windows.first
        current?.makeKey()
    }

    private func finish(_ rect: NSRect?) {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        let mainHeight = NSScreen.screens[0].frame.height
        let flipped = rect.map { CGRect(x: $0.minX, y: mainHeight - $0.maxY, width: $0.width, height: $0.height) }
        let completion = self.completion
        self.completion = nil
        completion?(flipped)
    }
}

private final class PickerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class PickerView: NSView {
    var onFinish: ((NSRect?) -> Void)?
    private var start: NSPoint?
    private var current: NSPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    private var selection: NSRect? {
        guard let start, let current else { return nil }
        return NSRect(x: min(start.x, current.x), y: min(start.y, current.y),
                      width: abs(start.x - current.x), height: abs(start.y - current.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()
        if let selection {
            NSColor.clear.setFill()
            selection.fill(using: .copy)
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection.insetBy(dx: -0.5, dy: -0.5))
            border.lineWidth = 1
            border.setLineDash([5, 3], count: 2, phase: 0)
            border.stroke()
            drawLabel("\(Int(selection.width)) × \(Int(selection.height))",
                      at: NSPoint(x: selection.maxX + 8, y: selection.minY - 22))
        } else {
            let hint = "Arraste para escolher a área da gravação · Esc cancela"
            drawLabel(hint, at: NSPoint(x: bounds.midX - 190, y: bounds.midY))
        }
    }

    private func drawLabel(_ text: String, at point: NSPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let box = NSRect(x: point.x, y: point.y, width: size.width + 16, height: size.height + 8)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6).fill()
        string.draw(at: NSPoint(x: box.minX + 8, y: box.minY + 4))
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        // Um clique sem arrastar não escolhe nada; continua esperando.
        guard let selection, selection.width >= 20, selection.height >= 20 else {
            start = nil
            current = nil
            needsDisplay = true
            return
        }
        onFinish?(selection)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onFinish?(nil) } else { super.keyDown(with: event) }
    }

    override func cancelOperation(_ sender: Any?) {
        onFinish?(nil)
    }
}
