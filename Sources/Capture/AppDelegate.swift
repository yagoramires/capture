import AppKit
import CaptureCore
import NeyKit
import NeyKitApp

/// Casca do avulso: o Capture em si mora no CaptureCore, o mesmo que o NeyHub carrega como plugin.
final class CaptureAppDelegate: NSObject, NSApplicationDelegate {
    private var capture: CaptureApp?
    private var updater: Updater?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if HubCheck.isHosted(id: "local.capture") && HubCheck.leaveForHub(id: "local.capture", name: "Capture") { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let capture = CaptureApp(defaults: .standard, hosted: false, version: version)
        capture.start()
        capture.setMenuBarVisible(Presence.load(.standard, hasScreen: false).menuBar)
        self.capture = capture

        let updater = Updater(name: "Capture", repo: "yagoramires/capture", id: "local.capture")
        capture.updateReady = updater.staged != nil
        updater.onChange = { [weak capture, weak updater] in capture?.updateReady = updater?.staged != nil }
        capture.onRelaunch = { [weak updater] in updater?.relaunchNow() }
        updater.start()
        self.updater = updater
        // Toda abertura: mostra as novidades uma vez e limpa um preparado velho.
        if let notes = Updater.notesAfterUpdate(id: "local.capture", current: version) {
            WhatsNew.show(name: "Capture", version: version, notes: notes)
        }
    }

    /// Fechar no meio de uma gravação encerra como o ⌃⌘Esc: o vídeo fica salvo.
    func applicationWillTerminate(_ notification: Notification) {
        capture?.stop()
        _ = updater?.applyStaged()
    }

    /// Aberto de novo pelo Finder com o ícone escondido: único jeito de chegar às configurações.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let capture, !Presence.load(.standard, hasScreen: false).menuBar else { return true }
        capture.showSettings()
        return false
    }
}
