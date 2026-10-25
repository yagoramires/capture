import AppKit
import AVFoundation
import NeyKit
import ServiceManagement
import SwiftUI

/// O Capture inteiro, sem a casca: o avulso (`Capture`) e o plugin do NeyHub (`CapturePlugin`) usam o mesmo.
public final class CaptureApp: NSObject {
    private let defaults: UserDefaults
    /// Dentro do NeyHub: sem pedir permissão ao sistema, sem item de login e sem "Sair".
    private let hosted: Bool
    let recorder = Recorder()
    private let picker = AreaPicker()
    private var statusItem: NSStatusItem?
    private var clock: Timer?
    private var debugObserver: NSObjectProtocol?
    private let popover = NSPopover()
    private var popoverHost: NSHostingController<PopoverView>?
    private var outsideClicks: Any?
    private(set) var settingsWindow: NSWindow?
    /// Hospedado: o NeyHub liga à tela de Permissões dele (Gravação de Tela e Microfone são do NeyHub).
    public var onOpenPermissions: (() -> Void)?
    /// Avulso: o Updater já preparou uma versão, que entra quando o app fechar.
    public var updateReady = false { didSet { refreshStatusItem() } }
    /// Avulso: "Reiniciar agora" do popover; a casca liga ao `Updater.relaunchNow`.
    public var onRelaunch: (() -> Void)?
    /// O pedido do sistema; o --selftest troca para conferir que o hospedado nunca chama.
    var requestScreenAccess: () -> Bool = CGRequestScreenCaptureAccess
    /// Só leitura (nunca pede); o --selftest troca para não depender do estado real do Microfone.
    var microphoneGranted: () -> Bool = { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
    /// Depois do stop() nada começa: ações já agendadas e a seleção de área em andamento são descartadas.
    private(set) var stopped = false

    public init(defaults: UserDefaults, hosted: Bool, version: String) {
        self.defaults = defaults
        self.hosted = hosted
        Log.version = version
        Options.shared = Options(defaults: defaults)
        Front.hosted = hosted
        super.init()
        recorder.onChange = { [weak self] in self?.refreshStatusItem() }
    }

    public func start() {
        stopped = false
        if !hosted { setupDebugBridge() }
        debugLog("iniciou\n\(Log.environment)")
    }

    /// Desinstalar no NeyHub: uma gravação em andamento é encerrada como no ⌃⌘Esc (o vídeo fica salvo) e o ícone sai.
    public func stop() {
        stopped = true
        picker.cancel()
        recorder.stopAndWait()
        if let debugObserver { DistributedNotificationCenter.default().removeObserver(debugObserver) }
        debugObserver = nil
        setMenuBarVisible(false)
        removeOutsideClicks()
        debugLog("parou")
    }

    /// false REMOVE o ícone; true cria com autosaveName "local.capture" (a posição na barra é lembrada).
    /// Escondido, nada para: os atalhos nativos do macOS continuam valendo.
    public func setMenuBarVisible(_ visible: Bool) {
        if !visible, let statusItem {
            popover.performClose(nil)
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
            refreshStatusItem()
        } else if visible, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = "local.capture"
            statusItem = item
            refreshStatusItem()
        }
    }

    public func makeSettings() -> NSViewController {
        NSHostingController(rootView: SettingsView(
            version: Log.version, hosted: hosted, wantsMicrophone: { Options.shared.recordMicrophone },
            menuBar: hosted ? nil : Presence.load(defaults, hasScreen: false).menuBar,
            onMenuBar: { [weak self] visible in self?.saveMenuBar(visible) },
            act: { [weak self] in self?.perform($0) }))
    }

    /// Janela de configurações do avulso: Ajuda → Configurações… ou reabrir pelo Finder com o ícone escondido.
    public func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: makeSettings())
            window.title = "Capture"
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        Front.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Avulso: no NeyHub quem guarda a presença é o NeyHub.
    private func saveMenuBar(_ visible: Bool) {
        var presence = Presence.load(defaults, hasScreen: false)
        presence.menuBar = visible
        presence.save(defaults)
        setMenuBarVisible(visible)
    }

    /// Parado: ícone de visor com o popover (e um sinal quando há atualização).
    /// Gravando: botão vermelho com o tempo, e um clique para.
    private func refreshStatusItem() {
        clock?.invalidate()
        clock = nil
        if popover.isShown { popoverHost?.rootView = popoverView() }
        guard let button = statusItem?.button else { return }
        button.target = self
        if recorder.isRecording {
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
            button.action = #selector(togglePopover)
            button.title = ""
            button.toolTip = updateReady ? "Capture: atualização pronta" : "Capture"
            let symbol = updateReady ? "camera.badge.ellipsis" : "camera.viewfinder"
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Capture")
        }
    }

    private func updateClock() {
        guard let started = recorder.started else { return }
        statusItem?.button?.title = " " + Self.clockText(Date().timeIntervalSince(started))
        if popover.isShown { popoverHost?.rootView = popoverView() }
    }

    /// Antes de começar (timer ligado), a contagem regressiva; depois, minutos e segundos.
    static func clockText(_ elapsed: TimeInterval) -> String {
        if elapsed < 0 { return "em \(Int((-elapsed).rounded(.up)))s" }
        let seconds = Int(elapsed)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Ações

    /// Espera o popover sumir da tela pra ele não sair no print.
    private func afterMenuCloses(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, !self.stopped else { return }
            action()
        }
    }

    private func recordScreen() {
        afterMenuCloses { [recorder] in recorder.start(area: nil) }
    }

    private func recordSelection() {
        afterMenuCloses { [picker, recorder] in
            picker.pick { [weak self] area in
                guard let area, self?.stopped == false else { return debugLog("seleção da gravação cancelada") }
                recorder.start(area: area)
            }
        }
    }

    @objc private func stopRecording() {
        recorder.stop()
    }

    /// `tag` diz qual pasta: 0 prints, 1 gravações.
    @objc private func chooseFolder(_ sender: NSMenuItem) {
        let kind: Screencapture.Kind = sender.tag == 1 ? .recordings : .prints
        if let url = sender.representedObject as? URL {
            Screencapture.setFolder(url, for: kind)
            return
        }
        Front.activate()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = Screencapture.folder(for: kind)
        panel.message = kind == .prints ? "Onde salvar os prints" : "Onde salvar as gravações"
        panel.prompt = "Escolher"
        if panel.runModal() == .OK, let url = panel.url { Screencapture.setFolder(url, for: kind) }
    }

    private func toggleOption(_ key: String) {
        let options = Options.shared
        switch key {
        case "showCursor": options.showCursor.toggle()
        case "recordMicrophone": options.recordMicrophone.toggle()
        case "showClicks": options.showClicks.toggle()
        case "openAfter": options.openAfter.toggle()
        default: break
        }
        debugLog("opções: \(options.summary)")
    }

    private func setDelay(_ seconds: Int) {
        Options.shared.delay = seconds
        debugLog("opções: \(Options.shared.summary)")
    }

    /// Hospedado a permissão é do NeyHub: nunca pede ao sistema, abre a tela de Permissões dele.
    private func askScreenPermission() {
        if hosted {
            onOpenPermissions?()
            return
        }
        if !requestScreenAccess() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    private func showLog() {
        debugLog("log aberto pelo menu\n\(Log.environment)")
        NSWorkspace.shared.activateFileViewerSelecting([Log.url])
    }

    /// Abre uma issue no GitHub já com o ambiente preenchido e mostra o log pra anexar.
    private func reportProblem() {
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

    private func toggleLoginItem() {
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
        if popover.isShown { popoverHost?.rootView = popoverView() }
    }

    /// Comandos de teste via scripts/debug.sh; só no avulso e só liga com
    /// `defaults write local.capture debugBridge -bool true`.
    private func setupDebugBridge() {
        guard defaults.bool(forKey: "debugBridge") else { return }
        debugObserver = DistributedNotificationCenter.default().addObserver(
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
            case "dump":
                let lines = [Log.environment, "gravando=\(self.recorder.isRecording)", "popover: \(self.popoverState())"]
                try? lines.joined(separator: "\n").write(toFile: "/tmp/capture-debug.txt", atomically: true, encoding: .utf8)
            default: break
            }
        }
    }
}

// MARK: Popover da barra

extension CaptureApp: NSPopoverDelegate {
    @objc private func togglePopover() {
        if popover.isShown { return popover.performClose(nil) }
        guard let button = statusItem?.button else { return }
        if popoverHost == nil {
            let host = NSHostingController(rootView: popoverView())
            host.sizingOptions = .preferredContentSize
            popoverHost = host
            popover.contentViewController = host
            popover.behavior = .transient
            popover.appearance = NSAppearance(named: .darkAqua)
            popover.delegate = self
        } else {
            popoverHost?.rootView = popoverView()
        }
        // App de barra não é ativo: sem isso o primeiro clique no popover pode não chegar.
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // O .transient sozinho não fecha quando o clique cai em outro app; um monitor global pega esse clique.
        if outsideClicks == nil {
            outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.popover.performClose(nil)
            }
        }
        popover.contentViewController?.view.window?.makeKey()
    }

    public func popoverDidClose(_ notification: Notification) { removeOutsideClicks() }

    private func removeOutsideClicks() {
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
    }

    /// O que o popover mostra agora.
    func popoverState() -> PopoverState {
        let options = Options.shared
        return PopoverState(
            version: Log.version, hosted: hosted, needsPermission: !CGPreflightScreenCaptureAccess(),
            // Avulso o próprio screencapture faz o pedido do microfone, como sempre.
            needsMicrophone: hosted && options.recordMicrophone && !microphoneGranted(),
            elapsed: recorder.started.map { Date().timeIntervalSince($0) }, partial: recorder.partial,
            delay: options.delay, showCursor: options.showCursor, showClicks: options.showClicks,
            recordMicrophone: options.recordMicrophone, openAfter: options.openAfter,
            prints: Self.place(Screencapture.folder), recordings: Self.place(Screencapture.recordingFolder),
            updateReady: updateReady, loginItem: hosted ? nil : SMAppService.mainApp.status == .enabled)
    }

    private func popoverView() -> PopoverView {
        PopoverView(state: popoverState()) { [weak self] in self?.perform($0) }
    }

    func perform(_ action: PopoverAction) {
        // Hospedado o popover não mostra login, Sair nem Configurações; a guarda é defesa extra (fecharia ou mexeria no NeyHub).
        if hosted, [.loginItem, .quit, .settings, .relaunch].contains(action) { return }
        // Opções e login mudam no lugar: o popover fica aberto e redesenha.
        switch action {
        case .loginItem: return toggleLoginItem()
        case .toggle(let key): toggleOption(key)
        case .delay(let seconds): setDelay(seconds)
        default:
            popover.performClose(nil)
        }
        switch action {
        case .shot(let kind, let copy): afterMenuCloses { Screencapture.shot(kind, copy: copy) }
        case .record(let partial): partial ? recordSelection() : recordScreen()
        case .stop: stopRecording()
        case .toolbar: afterMenuCloses { Screencapture.openToolbar() }
        case .openFolder(let kind): NSWorkspace.shared.open(Screencapture.folder(for: kind))
        case .chooseFolder(let kind):
            DispatchQueue.main.async { self.saveToMenu(kind).popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil) }
        case .grant: askScreenPermission()
        case .showLog: showLog()
        case .report: reportProblem()
        case .quit: NSApp.terminate(nil)
        case .settings: showSettings()
        case .relaunch: onRelaunch?()
        case .toggle, .delay:
            if popover.isShown { popoverHost?.rootView = popoverView() }
        case .loginItem: break
        }
    }

    /// Nome curto da pasta, como no "Salvar em" do ⇧⌘5.
    static func place(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch url.standardizedFileURL {
        case home.appendingPathComponent("Desktop").standardizedFileURL: return "Mesa"
        case home.appendingPathComponent("Documents").standardizedFileURL: return "Documentos"
        default: return url.lastPathComponent
        }
    }

    /// O "Salvar em" do ⇧⌘5: Mesa, Documentos, a pasta atual e "Outro local…".
    private func saveToMenu(_ kind: Screencapture.Kind) -> NSMenu {
        let menu = NSMenu()
        let current = Screencapture.folder(for: kind).standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser
        var places = [("Mesa", home.appendingPathComponent("Desktop")), ("Documentos", home.appendingPathComponent("Documents"))]
        if !places.contains(where: { $0.1.standardizedFileURL == current }) {
            places.append((current.lastPathComponent, current))
        }
        menu.addItem(.sectionHeader(title: kind == .prints ? "Salvar prints em" : "Salvar gravações em"))
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
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }
}
