import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let recorder = Recorder()
    private let picker = AreaPicker()
    private let updater = Updater()
    private var statusItem: NSStatusItem!
    private var clock: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        recorder.onChange = { [weak self] in self?.refreshStatusItem() }
        refreshStatusItem()
        setupDebugBridge()
        debugLog("iniciou\n\(Log.environment)")

        updater.onChange = { [weak self] in self?.refreshStatusItem() }
        // Confere atualização logo depois de abrir e, como o app fica aberto por semanas, uma vez por dia.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [updater] in updater.check(manual: false) }
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [updater] _ in
            updater.check(manual: false)
        }
    }

    /// Parado: ícone de visor com o menu (e uma bolinha quando há atualização).
    /// Gravando: botão vermelho com o tempo, e um clique para.
    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        clock?.invalidate()
        if recorder.isRecording {
            statusItem.menu = nil
            button.target = self
            button.action = #selector(stopRecording)
            let image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Parar gravação")?
                .withSymbolConfiguration(.init(paletteColors: [.white, .systemRed]))
            image?.isTemplate = false
            button.image = image
            button.imagePosition = .imageLeading
            button.toolTip = "Clique para parar a gravação (ou ⌃⌘Esc)"
            updateClock()
            clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateClock() }
        } else {
            button.action = nil
            button.title = ""
            button.toolTip = updater.available.map { "Capture: versão \($0.version) disponível" } ?? "Capture"
            let symbol = updater.available == nil ? "camera.viewfinder" : "camera.badge.ellipsis"
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Capture")
            let menu = NSMenu()
            menu.delegate = self
            statusItem.menu = menu
        }
    }

    private func updateClock() {
        guard let started = recorder.started else { return }
        let elapsed = Date().timeIntervalSince(started)
        // Antes de começar (timer ligado), mostra a contagem regressiva.
        if elapsed < 0 {
            statusItem.button?.title = " em \(Int((-elapsed).rounded(.up)))s"
            return
        }
        let seconds = Int(elapsed)
        statusItem.button?.title = String(format: " %d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Ações

    /// Espera o menu sumir da tela pra ele não sair no print.
    private func afterMenuCloses(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: action)
    }

    @objc private func shoot(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let kind = Screencapture.Shot(rawValue: raw.replacingOccurrences(of: "copy:", with: "")) else { return }
        let copy = raw.hasPrefix("copy:")
        afterMenuCloses { Screencapture.shot(kind, copy: copy) }
    }

    @objc private func recordScreen() {
        afterMenuCloses { [recorder] in recorder.start(area: nil) }
    }

    @objc private func recordSelection() {
        afterMenuCloses { [picker, recorder] in
            picker.pick { area in
                guard let area else { return debugLog("seleção da gravação cancelada") }
                recorder.start(area: area)
            }
        }
    }

    @objc private func stopRecording() {
        recorder.stop()
    }

    @objc private func openToolbar() {
        afterMenuCloses { Screencapture.openToolbar() }
    }

    @objc private func openFolder(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(sender.representedObject as? URL ?? Screencapture.folder)
    }

    /// `tag` diz qual pasta: 0 prints, 1 gravações.
    @objc private func chooseFolder(_ sender: NSMenuItem) {
        let kind: Screencapture.Kind = sender.tag == 1 ? .recordings : .prints
        if let url = sender.representedObject as? URL {
            Screencapture.setFolder(url, for: kind)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = Screencapture.folder(for: kind)
        panel.message = kind == .prints ? "Onde salvar os prints" : "Onde salvar as gravações"
        panel.prompt = "Escolher"
        if panel.runModal() == .OK, let url = panel.url { Screencapture.setFolder(url, for: kind) }
    }

    @objc private func toggleOption(_ sender: NSMenuItem) {
        let options = Options.shared
        switch sender.representedObject as? String {
        case "showCursor": options.showCursor.toggle()
        case "recordMicrophone": options.recordMicrophone.toggle()
        case "showClicks": options.showClicks.toggle()
        case "openAfter": options.openAfter.toggle()
        default: break
        }
        debugLog("opções: \(options.summary)")
    }

    @objc private func setDelay(_ sender: NSMenuItem) {
        Options.shared.delay = sender.tag
        debugLog("opções: \(Options.shared.summary)")
    }

    @objc private func askScreenPermission() {
        if !CGRequestScreenCaptureAccess() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    @objc private func checkForUpdates() {
        if let release = updater.available { updater.offer(release) } else { updater.check(manual: true) }
    }

    @objc private func showLog() {
        debugLog("log aberto pelo menu\n\(Log.environment)")
        NSWorkspace.shared.activateFileViewerSelecting([Log.url])
    }

    /// Abre uma issue no GitHub já com o ambiente preenchido e mostra o log pra anexar.
    @objc private func reportProblem() {
        showLog()
        let body = """
        **O que aconteceu:**


        **O que você esperava:**


        **Ambiente:**
        \(Log.environment)

        _Arraste o arquivo capture.log (o Finder acabou de mostrar ele) pra cá._
        """
        var components = URLComponents(string: "https://github.com/yagoramires/capture/issues/new")!
        components.queryItems = [URLQueryItem(name: "body", value: body)]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            try service.status == .enabled ? service.unregister() : service.register()
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Não deu pra mudar a abertura ao iniciar sessão"
            alert.runModal()
        }
        // O macOS pode exigir aprovação manual em Ajustes → Geral → Itens de Início.
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    /// Comandos de teste via scripts/debug.sh; só liga com
    /// `defaults write local.capture debugBridge -bool true`.
    private func setupDebugBridge() {
        guard UserDefaults.standard.bool(forKey: "debugBridge") else { return }
        DistributedNotificationCenter.default().addObserver(
            forName: .init("local.capture.debug"), object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let command = note.object as? String else { return }
            debugLog("debug: \(command)")
            switch command {
            case "shot-screen": Screencapture.shot(.screen)
            case "copy-screen": Screencapture.shot(.screen, copy: true)
            case "record-screen": self.recorder.start(area: nil)
            case "record-area": self.recorder.start(area: CGRect(x: 100, y: 100, width: 400, height: 300))
            case "record-stop": self.recorder.stop()
            case "toolbar": Screencapture.openToolbar()
            case "check-update": self.updater.check(manual: true)
            case "install-latest": self.updater.installLatest()
            case "dump":
                let menu = NSMenu()
                self.menuNeedsUpdate(menu)
                var lines = [Log.environment, "gravando=\(self.recorder.isRecording)", "menu:"]
                lines += Self.describe(menu, indent: "  ")
                try? lines.joined(separator: "\n").write(toFile: "/tmp/capture-debug.txt", atomically: true, encoding: .utf8)
            default: break
            }
        }
    }

    private static func describe(_ menu: NSMenu, indent: String) -> [String] {
        menu.items.flatMap { item -> [String] in
            if item.isSeparatorItem { return ["\(indent)—"] }
            var line = indent + item.title
            if !item.keyEquivalent.isEmpty {
                let m = item.keyEquivalentModifierMask
                let mods = (m.contains(.control) ? "⌃" : "") + (m.contains(.option) ? "⌥" : "")
                    + (m.contains(.shift) ? "⇧" : "") + (m.contains(.command) ? "⌘" : "")
                line += "  [\(mods)\(item.keyEquivalent.uppercased())]"
            }
            if item.state == .on { line += "  ✓" }
            if #available(macOS 14.4, *), let subtitle = item.subtitle { line += "  — \(subtitle)" }
            return [line] + (item.submenu.map { describe($0, indent: indent + "  ") } ?? [])
        }
    }
}

// MARK: Menu da barra

extension AppDelegate: NSMenuDelegate {
    /// Cada item mostra o atalho nativo equivalente (e o passo seguinte, quando há), pra ir aprendendo.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !CGPreflightScreenCaptureAccess() {
            menu.addItem(item("Dar permissão de Gravação de Tela…", #selector(askScreenPermission), symbol: "exclamationmark.triangle"))
            menu.addItem(.separator())
        }

        let save: NSEvent.ModifierFlags = [.command, .shift]
        let copy: NSEvent.ModifierFlags = [.command, .shift, .control]

        menu.addItem(.sectionHeader(title: "Print: salva um arquivo"))
        menu.addItem(shot("Tela inteira", .screen, symbol: "display", "3", save))
        menu.addItem(shot("Parte selecionada", .selection, symbol: "rectangle.dashed", "4", save,
                          hint: "segure Espaço pra mover · ⇧ trava um lado · ⌥ cresce do centro"))
        menu.addItem(shot("Janela", .window, symbol: "macwindow", "4", save, hint: "depois aperte Espaço e clique na janela"))
        menu.addItem(shot("Janela sem sombra", .windowNoShadow, symbol: "macwindow", "4", save,
                          hint: "depois Espaço, e clique na janela segurando ⌥"))

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Copiar: vai pra área de transferência"))
        menu.addItem(shot("Tela inteira", .screen, copy: true, symbol: "display", "3", copy))
        menu.addItem(shot("Parte selecionada", .selection, copy: true, symbol: "rectangle.dashed", "4", copy))
        menu.addItem(shot("Janela", .window, copy: true, symbol: "macwindow", "4", copy,
                          hint: "depois aperte Espaço e clique na janela"))

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Gravar vídeo"))
        menu.addItem(item("Tela inteira", #selector(recordScreen), symbol: "record.circle", shortcut: "5", save,
                          hint: "depois clique em Gravar a Tela Inteira"))
        menu.addItem(item("Parte selecionada", #selector(recordSelection), symbol: "rectangle.dashed.badge.record",
                          shortcut: "5", save, hint: "depois clique em Gravar a Parte Selecionada"))
        menu.addItem(disabled("Pra parar: clique no ícone ou ⌃⌘Esc"))

        menu.addItem(.separator())
        menu.addItem(item("Painel de captura do macOS", #selector(openToolbar), symbol: "slider.horizontal.below.rectangle",
                          shortcut: "5", save))
        let options = NSMenuItem(title: "Opções", action: nil, keyEquivalent: "")
        options.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        setHint(options, "no atalho: ⇧⌘5 → Opções")
        options.submenu = optionsMenu()
        menu.addItem(options)

        menu.addItem(.separator())
        folderItems().forEach(menu.addItem)

        menu.addItem(.separator())
        if let release = updater.available {
            menu.addItem(item("Atualizar para a versão \(release.version)…", #selector(checkForUpdates),
                              symbol: "arrow.down.circle"))
        }
        let login = item("Abrir ao iniciar sessão", #selector(toggleLoginItem))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(helpItem())
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    /// Atalhos pras pastas onde os prints e as gravações caem; um só se forem a mesma.
    private func folderItems() -> [NSMenuItem] {
        let shots = Screencapture.folder.standardizedFileURL
        let videos = Screencapture.recordingFolder.standardizedFileURL
        let folders = shots == videos
            ? [("Capturas", shots)]
            : [("Prints", shots), ("Gravações", videos)]
        return folders.map { title, url in
            let entry = item(title, #selector(openFolder(_:)), symbol: "folder")
            entry.representedObject = url
            return entry
        }
    }

    /// Espelha as opções do ⇧⌘5: Salvar em, Timer e as opções de ponteiro, cliques e microfone.
    private func optionsMenu() -> NSMenu {
        let options = Options.shared
        let menu = NSMenu()

        menu.addItem(saveToItem("Salvar prints em", .prints))
        menu.addItem(saveToItem("Salvar gravações em", .recordings))

        let timer = NSMenuItem(title: "Timer", action: nil, keyEquivalent: "")
        let timerMenu = NSMenu()
        for seconds in Options.delays {
            let entry = item(seconds == 0 ? "Nenhum" : "\(seconds) segundos", #selector(setDelay(_:)))
            entry.tag = seconds
            entry.state = options.delay == seconds ? .on : .off
            timerMenu.addItem(entry)
        }
        timer.submenu = timerMenu
        menu.addItem(timer)

        menu.addItem(.separator())
        menu.addItem(toggle("Mostrar o ponteiro do mouse", "showCursor", options.showCursor, hint: "só no print da tela inteira"))
        menu.addItem(toggle("Mostrar cliques do mouse", "showClicks", options.showClicks, hint: "nas gravações"))
        menu.addItem(toggle("Gravar o microfone", "recordMicrophone", options.recordMicrophone, hint: "nas gravações"))
        menu.addItem(.separator())
        menu.addItem(toggle("Abrir depois de capturar", "openAfter", options.openAfter,
                            hint: "como o Salvar em → Pré-Visualização"))
        return menu
    }

    private func saveToItem(_ title: String, _ kind: Screencapture.Kind) -> NSMenuItem {
        let saveTo = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        let current = Screencapture.folder(for: kind).standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser
        var places = [("Mesa", home.appendingPathComponent("Desktop")), ("Documentos", home.appendingPathComponent("Documents"))]
        if !places.contains(where: { $0.1.standardizedFileURL == current }) {
            places.append((current.lastPathComponent, current))
        }
        for (title, url) in places {
            let entry = item(title, #selector(chooseFolder(_:)))
            entry.representedObject = url
            entry.tag = kind == .prints ? 0 : 1
            entry.state = url.standardizedFileURL == current ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        let other = item("Outro local…", #selector(chooseFolder(_:)))
        other.tag = kind == .prints ? 0 : 1
        menu.addItem(other)
        saveTo.submenu = menu
        return saveTo
    }

    private func helpItem() -> NSMenuItem {
        let help = NSMenuItem(title: "Ajuda", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.addItem(disabled("Capture \(Updater.currentVersion)"))
        menu.addItem(.separator())
        menu.addItem(item("Buscar atualizações…", #selector(checkForUpdates)))
        menu.addItem(item("Mostrar log de depuração", #selector(showLog)))
        menu.addItem(item("Reportar problema…", #selector(reportProblem)))
        help.submenu = menu
        return help
    }

    private func shot(_ title: String, _ kind: Screencapture.Shot, copy: Bool = false, symbol: String,
                      _ key: String, _ modifiers: NSEvent.ModifierFlags, hint: String? = nil) -> NSMenuItem {
        let entry = item(title, #selector(shoot(_:)), symbol: symbol, shortcut: key, modifiers, hint: hint)
        entry.representedObject = (copy ? "copy:" : "") + kind.rawValue
        return entry
    }

    /// `shortcut` + `modifiers` é o atalho nativo equivalente; `hint` explica o passo seguinte, quando há.
    private func item(_ title: String, _ action: Selector, symbol: String? = nil,
                      shortcut: String? = nil, _ modifiers: NSEvent.ModifierFlags = [], hint: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        if let shortcut {
            item.keyEquivalent = shortcut
            item.keyEquivalentModifierMask = modifiers
        }
        if let hint { setHint(item, hint) }
        return item
    }

    private func toggle(_ title: String, _ key: String, _ on: Bool, hint: String? = nil) -> NSMenuItem {
        let entry = item(title, #selector(toggleOption(_:)), hint: hint)
        entry.representedObject = key
        entry.state = on ? .on : .off
        return entry
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func setHint(_ item: NSMenuItem, _ hint: String) {
        if #available(macOS 14.4, *) { item.subtitle = hint } else { item.toolTip = hint }
    }
}
