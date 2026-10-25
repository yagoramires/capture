import AppKit

/// Registro de depuração em ~/Library/Logs/Capture/capture.log, sempre ligado. Só guarda o que o app
/// fez (qual captura, com quais opções, o que o screencapture respondeu), nunca o conteúdo
/// das capturas. Serve pra quem tiver problema anexar no relato.
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Capture/capture.log")
    /// Passou disso, o atual vira capture.log.1 e começa outro: no máximo ~4 MB em disco.
    private static let limit: UInt64 = 2_000_000
    private static var handle: FileHandle?
    /// O screencapture avisa que saiu numa thread de fundo: tudo que mexe no arquivo passa por aqui.
    private static let queue = DispatchQueue(label: "local.capture.log")
    /// Vem do `CaptureApp.init`: no NeyHub o `Bundle.main` é o do NeyHub.
    static var version = "?"
    /// Desligado no --selftest e no --snapshots: não sujam o log de quem usa o Capture.
    static var enabled = true
    private static let clock: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func write(_ message: String) {
        guard enabled else { return }
        let line = Data("\(clock.string(from: Date())) \(message)\n".utf8)
        queue.sync {
            if handle == nil { open() }
            guard let handle else { return }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                if try handle.offset() > limit { rotate() }
            } catch {
                // Disco cheio ou arquivo apagado: reabre na próxima linha em vez de derrubar o app.
                try? handle.close()
                self.handle = nil
            }
        }
    }

    /// Versão, sistema e monitores: o que mais ajuda a entender um relato de problema.
    static var environment: String {
        let displays = NSScreen.screens.map { "\(Int($0.frame.width))×\(Int($0.frame.height)) em (\(Int($0.frame.minX)), \(Int($0.frame.minY)))" }
        return """
        Capture \(version) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        Monitores: \(displays.joined(separator: "; "))
        Gravação de Tela: \(CGPreflightScreenCaptureAccess() ? "permitida" : "sem permissão")
        Pasta dos prints: \(Screencapture.folder.path)
        Pasta das gravações: \(Screencapture.recordingFolder.path)
        Opções: \(Options.shared.summary)
        """
    }

    private static func open() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: url)
    }

    private static func rotate() {
        try? handle?.close()
        handle = nil
        let previous = url.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: previous)
        try? FileManager.default.moveItem(at: url, to: previous)
    }
}

func debugLog(_ message: @autoclosure () -> String) {
    Log.write(message())
}
