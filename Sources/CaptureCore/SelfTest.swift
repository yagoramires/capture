import AppKit
import AVFoundation

/// `Capture --selftest`. Sem XCTest (só CommandLineTools). Nunca grava no `.standard`: é o domínio do Capture em uso.
/// Nunca tira print nem grava: o screencapture é trocado por um processo falso.
extension CaptureApp {
    public static func selfTest() {
        Log.enabled = false
        defaultsInjected()
        popover()
        stopEndsRecording()
        permissions()
    }

    /// Suite temporária no lugar do `.standard`; o chamador apaga. Nome fixo: não junta um plist por rodada.
    private static func tempDefaults() -> (UserDefaults, String) {
        let name = "capture.selftest"
        return (UserDefaults(suiteName: name)!, name)
    }

    /// Opções vão para o `defaults` injetado, nunca para o `.standard`.
    static func defaultsInjected() {
        let (d, name) = tempDefaults()
        defer { d.removePersistentDomain(forName: name) }
        let keys = ["delay", "showCursor", "showClicks", "recordMicrophone", "openAfter", "debugBridge", "presence.menuBar"]
        let before = keys.map { UserDefaults.standard.object(forKey: $0) as? NSObject }
        let app = CaptureApp(defaults: d, hosted: true, version: "9.8.7")
        // Antes de mexer: se ainda fosse o .standard, o teste mudaria as opções de quem usa o Capture.
        precondition(Options.shared.defaults === d, "Options ainda no .standard")
        app.perform(.toggle("showCursor"))
        app.perform(.toggle("showClicks"))
        app.perform(.delay(5))
        precondition(d.bool(forKey: "showCursor") && d.object(forKey: "showClicks") as? Bool == false && d.integer(forKey: "delay") == 5,
                     "opções não foram para o defaults injetado")
        precondition(keys.map { UserDefaults.standard.object(forKey: $0) as? NSObject } == before, "opção vazou para o .standard")
    }

    /// Hospedado: sem "Abrir ao iniciar sessão" (é o login do NeyHub), sem "Sair" (fecharia o NeyHub) e sem
    /// a linha de atualização (quem atualiza é o NeyHub).
    static func popover() {
        func state(hosted: Bool, microphone: Bool = false) -> PopoverState {
            let (d, name) = tempDefaults()
            defer { d.removePersistentDomain(forName: name) }
            let app = CaptureApp(defaults: d, hosted: hosted, version: "9.8.7")
            app.updateReady = true
            if microphone { app.perform(.toggle("recordMicrophone")) }
            return app.popoverState()
        }
        let hosted = state(hosted: true), alone = state(hosted: false)
        precondition(!hosted.showsQuit && hosted.loginItem == nil && !hosted.showsUpdate && !hosted.showsSettings, "\(hosted)")
        precondition(alone.showsQuit && alone.loginItem != nil && alone.showsUpdate && alone.showsSettings, "\(alone)")
        precondition(hosted.version == "9.8.7" && alone.version == "9.8.7")
        precondition(alone.elapsed == nil && !alone.partial)

        // Microfone: só conta hospedado e com "Gravar o microfone" ligado; avulso o screencapture pede sozinho.
        let missing = AVCaptureDevice.authorizationStatus(for: .audio) != .authorized
        precondition(!hosted.needsMicrophone && !alone.needsMicrophone)
        precondition(state(hosted: true, microphone: true).needsMicrophone == missing)
        precondition(!state(hosted: false, microphone: true).needsMicrophone)

        // "Reiniciar agora" fica na linha de atualização (só avulso); hospedado a ação não chega à casca.
        for hosted in [true, false] {
            let (d, name) = tempDefaults()
            defer { d.removePersistentDomain(forName: name) }
            let app = CaptureApp(defaults: d, hosted: hosted, version: "9.8.7")
            var relaunched = 0
            app.onRelaunch = { relaunched += 1 }
            app.perform(.relaunch)
            precondition(relaunched == (hosted ? 0 : 1), "Reiniciar agora hospedado=\(hosted): \(relaunched)")
        }
        precondition(clockText(84) == "1:24" && clockText(-4.2) == "em 5s")
    }

    /// Desinstalar no meio da gravação: o stop() manda o Ctrl-C do ⌃⌘Esc e espera o screencapture sair (Review Focus 2).
    static func stopEndsRecording() {
        let (d, name) = tempDefaults()
        defer { d.removePersistentDomain(forName: name) }
        let launch = Recorder.launch
        defer { Recorder.launch = launch }

        var fake: Process?
        var seen: [String] = []
        Recorder.launch = { args, stdin, _ in
            seen = args
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sleep")
            p.arguments = ["30"]
            p.standardInput = stdin
            try! p.run()
            fake = p
            return p
        }
        let app = CaptureApp(defaults: d, hosted: true, version: "9.8.7")
        app.recorder.start(area: nil)
        precondition(app.recorder.isRecording && seen.first == "-v", "gravação falsa não começou: \(seen)")
        let begin = Date()
        app.stop()
        guard let fake else { preconditionFailure("o Recorder não usou o Recorder.launch") }
        precondition(!fake.isRunning, "stop() voltou com o screencapture rodando")
        precondition(fake.terminationReason == .uncaughtSignal && fake.terminationStatus == SIGINT,
                     "esperava SIGINT, veio \(fake.terminationReason.rawValue)/\(fake.terminationStatus)")
        precondition(Date().timeIntervalSince(begin) < 5, "stop() demorou demais")

        // Como o screencapture, o falso leva um tempo fechando o arquivo depois do Ctrl-C: o stop() espera.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("capture-selftest-\(getpid()).mov")
        try? FileManager.default.removeItem(at: file)
        defer { try? FileManager.default.removeItem(at: file) }
        Recorder.launch = { _, stdin, _ in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            p.arguments = ["-c", "trap 'kill $! 2>/dev/null; sleep 0.5; echo ok > \"$0\"; exit 0' INT; sleep 30 & wait", file.path]
            p.standardInput = stdin
            try! p.run()
            return p
        }
        let other = CaptureApp(defaults: d, hosted: true, version: "9.8.7")
        other.recorder.start(area: nil)
        usleep(300_000) // o sh instala o trap
        other.stop()
        precondition(FileManager.default.fileExists(atPath: file.path), "stop() não esperou o arquivo ser fechado")
    }

    /// Sem Gravação de Tela: hospedado abre as Permissões do NeyHub e nunca chama CGRequestScreenCaptureAccess.
    static func permissions() {
        for hosted in [true, false] {
            let (d, name) = tempDefaults()
            defer { d.removePersistentDomain(forName: name) }
            let app = CaptureApp(defaults: d, hosted: hosted, version: "9.8.7")
            var opened = 0, requested = 0
            app.onOpenPermissions = { opened += 1 }
            // true: o avulso não abre os Ajustes durante o teste.
            app.requestScreenAccess = { requested += 1; return true }
            app.perform(.grant)
            precondition(hosted ? (opened == 1 && requested == 0) : (opened == 0 && requested == 1),
                         "Conceder hospedado=\(hosted): abriu \(opened), pediu \(requested)")
        }
    }
}
