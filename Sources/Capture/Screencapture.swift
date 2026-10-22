import AppKit

/// Tudo passa pelo `screencapture` do próprio macOS: mesmo som, mesma qualidade e a
/// mesma pasta que o ⇧⌘5 usa.
enum Screencapture {
    /// Os tipos de print do macOS, na ordem do painel ⇧⌘5.
    enum Shot: String { case screen, selection, window, windowNoShadow }

    /// `copy` manda pra área de transferência em vez de salvar, como os atalhos com ⌃.
    static func shot(_ kind: Shot, copy: Bool = false) {
        let options = Options.shared
        var args: [String] = []
        switch kind {
        case .screen:
            args += ["-D", String(displayNumber(for: screenUnderMouse()))]
            // O screencapture só aceita mostrar o ponteiro fora do modo interativo.
            if options.showCursor { args.append("-C") }
        case .selection: args += ["-i", "-s"]
        case .window: args += ["-i", "-w"]
        case .windowNoShadow: args += ["-i", "-w", "-o"]
        }
        if options.delay > 0 { args += ["-T", String(options.delay)] }

        var file: URL?
        if copy {
            args.append("-c")
        } else {
            let url = newFile(in: folder, "Captura de Tela", "png")
            file = url
            args.append(url.path)
        }

        run(args) { status, errors in
            // Com Esc na seleção o screencapture sai sem criar arquivo; isso não é erro.
            if let file {
                if FileManager.default.fileExists(atPath: file.path) {
                    debugLog("print salvo em \(file.path)")
                    if options.openAfter { NSWorkspace.shared.open(file) }
                    return
                }
            } else if status == 0 {
                debugLog("print copiado")
                return
            }
            if status != 0, !errors.isEmpty {
                showError("Não deu pra tirar o print", errors)
            } else {
                debugLog("print cancelado")
            }
        }
    }

    /// O painel do ⇧⌘5 é o app Captura de Tela; abrir ele é o mesmo que apertar o atalho.
    static func openToolbar() {
        let app = URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")
        NSWorkspace.shared.openApplication(at: app, configuration: .init()) { _, error in
            if let error { debugLog("painel ⇧⌘5 não abriu: \(error.localizedDescription)") }
        }
    }

    // MARK: Pasta

    private static let domain = "com.apple.screencapture" as CFString

    /// Prints e gravações podem ir pra pastas diferentes, como no "Salvar em" do ⇧⌘5.
    enum Kind {
        case prints, recordings

        /// O macOS recente guarda uma pasta pra cada; o "location" antigo vale pros prints.
        var keys: [String] {
            switch self {
            case .prints: ["location", "location-screenshot"]
            case .recordings: ["location-screenrecording"]
            }
        }
    }

    /// A pasta dos prints. Trocar aqui troca no ⇧⌘5 também.
    static var folder: URL { savedFolder(keys: Kind.prints.keys) }

    /// Sem uma pasta própria, as gravações vão pra mesma dos prints.
    static var recordingFolder: URL { savedFolder(keys: Kind.recordings.keys + Kind.prints.keys) }

    static func folder(for kind: Kind) -> URL { kind == .prints ? folder : recordingFolder }

    private static func savedFolder(keys: [String]) -> URL {
        for key in keys {
            if let path = CFPreferencesCopyAppValue(key as CFString, domain) as? String {
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    return url
                }
            }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    static func setFolder(_ url: URL, for kind: Kind) {
        // Fixa a pasta atual das gravações antes, pra elas não seguirem os prints sem querer.
        if kind == .prints, CFPreferencesCopyAppValue("location-screenrecording" as CFString, domain) == nil {
            write(recordingFolder, keys: Kind.recordings.keys)
        }
        write(url, keys: kind.keys)
        debugLog("pasta \(kind == .prints ? "dos prints" : "das gravações"): \(url.path)")
    }

    private static func write(_ url: URL, keys: [String]) {
        let path = (url.path as NSString).abbreviatingWithTildeInPath
        for key in keys { CFPreferencesSetAppValue(key as CFString, path as CFString, domain) }
        CFPreferencesAppSynchronize(domain)
    }

    // MARK: Utilitários

    /// Nome no padrão do macOS; dois no mesmo segundo ganham " (2)", " (3)"… em vez de se sobrescrever.
    static func newFile(in folder: URL, _ prefix: String, _ ext: String) -> URL {
        let base = "\(prefix) \(timestamp())"
        var url = folder.appendingPathComponent("\(base).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) (\(n)).\(ext)")
            n += 1
        }
        return url
    }

    static func timestamp() -> String {
        let formatter = DateFormatter()
        // Fixos pra o nome não mudar com o calendário ou o relógio de 12 h escolhidos no sistema.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd 'às' HH.mm.ss"
        return formatter.string(from: Date())
    }

    static func screenUnderMouse() -> NSScreen {
        NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.screens[0]
    }

    /// O `-D` do screencapture conta os monitores a partir de 1, na ordem do CoreGraphics.
    static func displayNumber(for screen: NSScreen) -> Int {
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return (ids.firstIndex { $0 == id } ?? 0) + 1
    }

    @discardableResult
    static func run(_ args: [String], stdin: Pipe? = nil, done: @escaping (Int32, String) -> Void) -> Process? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        let errors = Pipe()
        process.standardError = errors
        if let stdin { process.standardInput = stdin }
        process.terminationHandler = { process in
            let text = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            debugLog("screencapture saiu com \(process.terminationStatus)\(trimmed.isEmpty ? "" : ": \(trimmed)")")
            DispatchQueue.main.async { done(process.terminationStatus, trimmed) }
        }
        debugLog("screencapture \(args.joined(separator: " "))")
        do {
            try process.run()
            return process
        } catch {
            showError("Não deu pra abrir o screencapture", error.localizedDescription)
            return nil
        }
    }

    static func showError(_ title: String, _ details: String) {
        debugLog("erro: \(title) (\(details))")
        showAlert(title, details)
    }
}

/// Traz o app pra frente (ele não tem janela) e mostra um aviso simples.
func showAlert(_ title: String, _ details: String) {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = details
    alert.runModal()
}

/// Grava a tela até alguém mandar parar. O screencapture fecha o arquivo com Ctrl-C (o ícone)
/// e também sozinho com o ⌃⌘Esc nativo; os dois juntos fazem ele descartar o vídeo.
final class Recorder {
    var onChange: (() -> Void)?
    private(set) var started: Date?
    private var process: Process?
    private var stdin: Pipe?
    /// Um segundo Ctrl-C enquanto o screencapture fecha o arquivo pode fazer ele descartar o vídeo.
    private var stopping = false

    var isRecording: Bool { process != nil }

    /// `area` em coordenadas globais com origem no canto superior esquerdo do monitor principal.
    func start(area: CGRect?) {
        guard !isRecording else { return }
        let options = Options.shared
        var args = ["-v"]
        if options.recordMicrophone { args.append("-g") }
        if options.showClicks { args.append("-k") }
        if options.delay > 0 { args += ["-T", String(options.delay)] }
        if let area {
            args += ["-R", [area.minX, area.minY, area.width, area.height].map { String(Int($0.rounded())) }.joined(separator: ",")]
        } else {
            args += ["-D", String(Screencapture.displayNumber(for: Screencapture.screenUnderMouse()))]
        }
        let file = Screencapture.newFile(in: Screencapture.recordingFolder, "Gravação de Tela", "mov")
        args.append(file.path)

        // Sem um stdin aberto o screencapture lê fim de arquivo e encerra a gravação na hora.
        let stdin = Pipe()
        let process = Screencapture.run(args, stdin: stdin) { [weak self] status, errors in
            guard let self else { return }
            self.process = nil
            self.stdin = nil
            self.started = nil
            self.stopping = false
            self.onChange?()
            if FileManager.default.fileExists(atPath: file.path) {
                debugLog("gravação salva em \(file.path)")
                if options.openAfter { NSWorkspace.shared.open(file) } else { NSWorkspace.shared.activateFileViewerSelecting([file]) }
            } else {
                Screencapture.showError("Não deu pra gravar a tela", errors.isEmpty ? "O screencapture saiu com código \(status)." : errors)
            }
        }
        guard let process else { return }
        self.process = process
        self.stdin = stdin
        // Com timer, o vídeo só começa depois da contagem; o relógio do ícone acompanha.
        started = Date().addingTimeInterval(TimeInterval(options.delay))
        onChange?()
    }

    func stop() {
        guard let process, !stopping else { return }
        stopping = true
        debugLog("parando gravação")
        process.interrupt()
    }
}

/// Preferências do menu Opções, guardadas em UserDefaults. Espelham as opções do ⇧⌘5.
final class Options {
    static let shared = Options()
    private let defaults = UserDefaults.standard

    /// Os mesmos tempos do Timer do ⇧⌘5.
    static let delays = [0, 5, 10]

    var delay: Int {
        get { defaults.integer(forKey: "delay") }
        set { defaults.set(newValue, forKey: "delay") }
    }
    var showCursor: Bool {
        get { defaults.bool(forKey: "showCursor") }
        set { defaults.set(newValue, forKey: "showCursor") }
    }
    var recordMicrophone: Bool {
        get { defaults.bool(forKey: "recordMicrophone") }
        set { defaults.set(newValue, forKey: "recordMicrophone") }
    }
    var showClicks: Bool {
        get { defaults.object(forKey: "showClicks") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showClicks") }
    }
    var openAfter: Bool {
        get { defaults.bool(forKey: "openAfter") }
        set { defaults.set(newValue, forKey: "openAfter") }
    }

    var summary: String {
        "timer=\(delay) cursor=\(showCursor) mic=\(recordMicrophone) cliques=\(showClicks) abrir=\(openAfter)"
    }
}
