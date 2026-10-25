import AVFoundation
import Combine
import NeyKit
import SwiftUI

/// Configurações (card no NeyHub, janela no avulso reaberto com ícone escondido). As opções de captura ficam no popover.
struct SettingsView: View {
    let version: String
    let hosted: Bool
    /// nil hospedado: o ícone é do NeyHub.
    let menuBar: Bool?
    let onMenuBar: (Bool) -> Void
    let act: (PopoverAction) -> Void
    /// O --snapshots fixa as permissões; senão vêm do sistema (só leitura, nunca pede).
    let granted: () -> (screen: Bool, microphone: Bool)
    @ViewState private var shown: Bool
    @ViewState private var screen: Bool
    @ViewState private var microphone: Bool

    init(version: String, hosted: Bool, menuBar: Bool?, onMenuBar: @escaping (Bool) -> Void, act: @escaping (PopoverAction) -> Void,
         granted: @escaping () -> (screen: Bool, microphone: Bool) = SettingsView.systemPermissions) {
        self.version = version; self.hosted = hosted; self.menuBar = menuBar; self.onMenuBar = onMenuBar; self.act = act
        self.granted = granted
        let now = granted()
        _shown = ViewState(wrappedValue: menuBar ?? true)
        _screen = ViewState(wrappedValue: now.screen)
        _microphone = ViewState(wrappedValue: now.microphone)
    }

    static func systemPermissions() -> (screen: Bool, microphone: Bool) {
        (CGPreflightScreenCaptureAccess(), AVCaptureDevice.authorizationStatus(for: .audio) == .authorized)
    }

    private static let shortcuts = [("Print da tela inteira / de uma parte", "⇧⌘3 ⇧⌘4"),
                                    ("Copiar em vez de salvar", "⌃ + o atalho"),
                                    ("Painel de captura e gravação", "⇧⌘5"), ("Parar a gravação", "⌃⌘Esc")]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture").font(.system(size: 16, weight: .bold)).foregroundStyle(Grafite.strong)
            Text("Prints e gravação de tela pela barra de menus · \(version)").font(.system(size: 12)).foregroundStyle(Grafite.muted)
                .padding(.bottom, 6)
            if menuBar != nil {
                GCard {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            title("Mostrar na barra de menus")
                            Spacer()
                            GSwitch(isOn: Binding(get: { shown }, set: { shown = $0; onMenuBar($0) }), label: "Mostrar na barra de menus")
                        }
                        Text("Escondido, o Capture não desliga nada: os atalhos nativos do macOS (⇧⌘3, ⇧⌘4, ⇧⌘5) continuam valendo.")
                            .font(.system(size: 11)).foregroundStyle(Grafite.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            GCard {
                VStack(alignment: .leading, spacing: 8) {
                    permission("Gravação de Tela", screen)
                    // Avulso o próprio screencapture pede o microfone na primeira gravação com ele.
                    if hosted { permission("Microfone", microphone, note: "só se “Gravar o microfone” estiver ligado") }
                }
            }
            GCard {
                VStack(alignment: .leading, spacing: 0) {
                    title("Atalhos nativos").padding(.bottom, 4)
                    ForEach(Self.shortcuts, id: \.0) { name, keys in
                        HStack {
                            Text(name).font(.system(size: 11))
                            Spacer()
                            Text(keys).font(.system(size: 11, design: .monospaced)).foregroundStyle(Grafite.accent)
                        }
                        .padding(.vertical, 4)
                        Rectangle().fill(Grafite.border).frame(height: 1)
                    }
                }
            }
            HStack(spacing: 6) {
                Chip(title: "Mostrar log de depuração") { act(.showLog) }
                Chip(title: "Reportar problema…") { act(.report) }
            }
        }
        .padding(18)
        .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
        .grafiteWindow()
        // A permissão chega pelos Ajustes com a tela aberta.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            let now = granted()
            screen = now.screen
            microphone = now.microphone
        }
    }

    private func permission(_ name: String, _ ok: Bool, note: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                title(name)
                if let note { Text(note).font(.system(size: 10)).foregroundStyle(Grafite.muted) }
            }
            Spacer()
            if ok {
                Text("Concedida").font(.system(size: 11)).foregroundStyle(Grafite.accent)
            } else {
                Text("Não concedida").font(.system(size: 11)).foregroundStyle(Grafite.warn)
                GPill(title: "Conceder") { act(.grant) }
            }
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Grafite.strong)
    }
}
