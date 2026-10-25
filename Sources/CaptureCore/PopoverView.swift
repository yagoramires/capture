import NeyKit
import SwiftUI

/// O que o popover mostra, tirado no clique do ícone (e a cada segundo enquanto grava).
struct PopoverState {
    var version: String
    var hosted: Bool
    var needsPermission: Bool
    /// Hospedado, com "Gravar o microfone" ligado e o NeyHub sem a permissão de Microfone.
    var needsMicrophone: Bool
    /// Tempo desde o início da gravação (negativo na contagem do timer); nil parado.
    var elapsed: TimeInterval?
    var partial: Bool
    var delay: Int
    var showCursor: Bool, showClicks: Bool, recordMicrophone: Bool, openAfter: Bool
    /// Nomes curtos das pastas dos prints e das gravações.
    var prints: String, recordings: String
    var updateReady: Bool
    /// nil hospedado: o login é do NeyHub.
    var loginItem: Bool?

    var showsQuit: Bool { !hosted }
    /// Hospedado as configurações ficam no card do NeyHub.
    var showsSettings: Bool { !hosted }
    /// Hospedado quem atualiza é o NeyHub.
    var showsUpdate: Bool { updateReady && !hosted }
}

enum PopoverAction: Equatable {
    case shot(Screencapture.Shot, copy: Bool), record(partial: Bool), stop, toolbar
    case toggle(String), delay(Int), openFolder(Screencapture.Kind), chooseFolder(Screencapture.Kind)
    case grant, showLog, report, quit, loginItem, settings, relaunch
}

extension Grafite {
    // O Grafite não tem cor de alerta nem de gravação; estas vêm do mockup aprovado.
    static let warn = color(hex: "#ffb03d") ?? .orange
    static let warnBg = color(hex: "#2a2110") ?? .clear
    static let warnBorder = color(hex: "#5a4416") ?? .clear
    static let rec = color(hex: "#ff4d4d") ?? .red
    static let recBg = color(hex: "#2a1414") ?? .clear
    static let recBorder = color(hex: "#5a2222") ?? .clear
    static let recText = color(hex: "#ffb3b3") ?? .pink
}

struct PopoverView: View {
    let state: PopoverState
    let act: (PopoverAction) -> Void
    @ViewState private var help: Bool

    /// `help`: Ajuda já aberta (só o --snapshots usa).
    init(state: PopoverState, help: Bool = false, act: @escaping (PopoverAction) -> Void) {
        self.state = state; self.act = act
        _help = ViewState(wrappedValue: help)
    }

    /// `hint` é o passo seguinte do atalho nativo, quando há (aparece ao parar o mouse no bloco).
    private struct Tile { let title: String, symbol: String, key: String, hint: String?, action: PopoverAction }
    private static let prints = [
        Tile(title: "Tela inteira", symbol: "display", key: "⇧⌘3", hint: nil, action: .shot(.screen, copy: false)),
        Tile(title: "Parte", symbol: "rectangle.dashed", key: "⇧⌘4",
             hint: "segure Espaço pra mover · ⇧ trava um lado · ⌥ cresce do centro", action: .shot(.selection, copy: false)),
        Tile(title: "Janela", symbol: "macwindow", key: "⇧⌘4 ␣", hint: "depois aperte Espaço e clique na janela",
             action: .shot(.window, copy: false)),
        Tile(title: "Sem sombra", symbol: "macwindow", key: "⇧⌘4 ␣ ⌥", hint: "depois Espaço, e clique na janela segurando ⌥",
             action: .shot(.windowNoShadow, copy: false)),
    ]
    private static let copies = [
        Tile(title: "Tela inteira", symbol: "display", key: "⌃⇧⌘3", hint: nil, action: .shot(.screen, copy: true)),
        Tile(title: "Parte", symbol: "rectangle.dashed", key: "⌃⇧⌘4", hint: nil, action: .shot(.selection, copy: true)),
        Tile(title: "Janela", symbol: "macwindow", key: "⌃⇧⌘4 ␣", hint: "depois aperte Espaço e clique na janela",
             action: .shot(.window, copy: true)),
    ]
    private static let records = [
        Tile(title: "Tela inteira", symbol: "record.circle", key: "⇧⌘5", hint: "depois clique em Gravar a Tela Inteira",
             action: .record(partial: false)),
        Tile(title: "Parte selecionada", symbol: "rectangle.dashed.badge.record", key: "⇧⌘5",
             hint: "depois clique em Gravar a Parte Selecionada", action: .record(partial: true)),
    ]
    private static let toggles = [
        ("Mostrar o ponteiro", "showCursor", "só no print da tela inteira"), ("Mostrar cliques", "showClicks", "nas gravações"),
        ("Gravar o microfone", "recordMicrophone", "nas gravações"),
        ("Abrir depois de capturar", "openAfter", "como o Salvar em → Pré-Visualização"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let elapsed = state.elapsed {
                recording(elapsed)
            } else {
                header
                if state.needsPermission { permission }
                captures
                if state.showsUpdate {
                    HStack {
                        line("Atualização pronta — entra ao sair", Grafite.accent)
                        Spacer()
                        GPill(title: "Reiniciar agora") { act(.relaunch) }.padding(.top, 8).accessibilityLabel("Reiniciar o Capture agora")
                    }
                }
                if let on = state.loginItem {
                    HStack {
                        Text("Abrir ao iniciar sessão").font(.system(size: 11))
                        Spacer()
                        GSwitch(isOn: Binding(get: { on }, set: { _ in act(.loginItem) }), label: "Abrir ao iniciar sessão")
                    }
                    .padding(.top, 4)
                }
                footer
            }
        }
        .padding(12)
        .frame(width: 300)
        .grafiteWindow()
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Capture").font(.system(size: 13, weight: .bold)).foregroundStyle(Grafite.strong)
            Text(state.version).font(.system(size: 10)).foregroundStyle(Grafite.muted)
            Spacer()
            Circle().fill(state.needsPermission ? Grafite.warn : Grafite.accent).frame(width: 7, height: 7)
                .accessibilityLabel(state.needsPermission ? "Sem permissão" : "Funcionando")
        }
        .padding(.bottom, 4)
    }

    private var captures: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("Print", "salva um arquivo")
            row(Self.prints, section: "Print")
            section("Copiar", "vai pra área de transferência")
            row(Self.copies, section: "Copiar")
            section("Gravar vídeo", "pra parar: ⌃⌘Esc")
            row(Self.records, section: "Gravar", red: true)

            section("Opções", "as mesmas do ⇧⌘5")
            HStack {
                Text("Timer").font(.system(size: 11))
                Spacer()
                timer
            }
            .padding(.vertical, 5)
            ForEach(Self.toggles, id: \.1) { title, key, hint in
                divider
                HStack {
                    Text(title).font(.system(size: 11))
                    Spacer()
                    GSwitch(isOn: Binding(get: { isOn(key) }, set: { _ in act(.toggle(key)) }), label: title)
                }
                .help(hint)
                if key == "recordMicrophone", state.needsMicrophone { microphone }
            }

            section("Pastas", nil)
            HStack(spacing: 6) {
                folder("Prints", state.prints, .prints)
                folder("Gravações", state.recordings, .recordings)
            }

            divider.padding(.top, 10)
            Button { act(.toolbar) } label: {
                HStack {
                    Image(systemName: "slider.horizontal.below.rectangle").font(.system(size: 11))
                    Text("Painel de captura do macOS").font(.system(size: 11))
                    Spacer()
                    Text("⇧⌘5").font(.system(size: 10, design: .monospaced)).foregroundStyle(Grafite.accent)
                }
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func isOn(_ key: String) -> Bool {
        switch key {
        case "showCursor": state.showCursor
        case "showClicks": state.showClicks
        case "recordMicrophone": state.recordMicrophone
        default: state.openAfter
        }
    }

    private func section(_ title: String, _ note: String?) -> some View {
        HStack {
            GSectionLabel(title)
            Spacer()
            if let note { Text(note).font(.system(size: 9)).foregroundStyle(Grafite.label) }
        }
        .padding(.top, 12).padding(.bottom, 6)
    }

    private func row(_ tiles: [Tile], section: String, red: Bool = false) -> some View {
        HStack(spacing: 6) {
            ForEach(tiles, id: \.title) { t in
                Block(title: t.title, symbol: t.symbol, key: t.key, hint: t.hint, red: red,
                      accessibility: "\(section): \(t.title)") { act(t.action) }
            }
        }
    }

    /// O Timer do ⇧⌘5: Nenhum, 5 s ou 10 s.
    private var timer: some View {
        HStack(spacing: 0) {
            ForEach(Options.delays, id: \.self) { seconds in
                let on = state.delay == seconds
                Button { act(.delay(seconds)) } label: {
                    Text(seconds == 0 ? "Nenhum" : "\(seconds) s").font(.system(size: 10))
                        .foregroundStyle(on ? Grafite.strong : Grafite.muted)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(on ? Grafite.selected : .clear, in: RoundedRectangle(cornerRadius: 5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(seconds == 0 ? "Timer: nenhum" : "Timer: \(seconds) segundos")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Grafite.card, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Grafite.cardBorder, lineWidth: 1))
    }

    /// Clicar abre a pasta no Finder; "trocar…" abre o "Salvar em" (vale pro ⇧⌘5 também).
    private func folder(_ title: String, _ place: String, _ kind: Screencapture.Kind) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Button { act(.openFolder(kind)) } label: {
                Label(title, systemImage: "folder").font(.system(size: 10.5)).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Abrir no Finder")
            HStack(spacing: 0) {
                Text("\(place) · ").lineLimit(1)
                Button("trocar…") { act(.chooseFolder(kind)) }.buttonStyle(.plain)
                    .accessibilityLabel(kind == .prints ? "Salvar prints em" : "Salvar gravações em")
            }
            .font(.system(size: 9.5)).foregroundStyle(Grafite.muted)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Grafite.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Grafite.cardBorder, lineWidth: 1))
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 6) {
            warning("Precisa de Gravação de Tela")
            Text(state.hosted ? "No NeyHub, “Conceder” abre a tela de Permissões. O microfone só é pedido se você ligar “Gravar o microfone”."
                              : "O microfone só é pedido se você ligar “Gravar o microfone”.")
                .font(.system(size: 10)).foregroundStyle(Grafite.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var microphone: some View { warning("Microfone sem permissão").padding(.bottom, 4) }

    private func warning(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text).font(.system(size: 12)).foregroundStyle(Grafite.warn)
            Spacer()
            GPill(title: "Conceder") { act(.grant) }
        }
        .padding(8)
        .background(Grafite.warnBg, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Grafite.warnBorder, lineWidth: 1))
    }

    private func recording(_ elapsed: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "record.circle.fill").font(.system(size: 16)).foregroundStyle(Grafite.rec)
                VStack(alignment: .leading, spacing: 1) {
                    Text(CaptureApp.clockText(elapsed)).font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Grafite.strong)
                    Text(elapsed < 0 ? "A gravação já vai começar" : state.partial ? "Gravando uma parte da tela" : "Gravando a tela inteira")
                        .font(.system(size: 10)).foregroundStyle(Grafite.recText)
                }
                Spacer()
                Button { act(.stop) } label: {
                    Text("Parar").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Grafite.rec, in: Capsule()).contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Parar a gravação")
            }
            .padding(10)
            .background(Grafite.recBg, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Grafite.recBorder, lineWidth: 1))
            Text(state.openAfter ? "Também para com ⌃⌘Esc. O vídeo abre ao terminar." : "Também para com ⌃⌘Esc. O vídeo abre no Finder ao terminar.")
                .font(.system(size: 10)).foregroundStyle(Grafite.muted)
        }
    }

    private var divider: some View { Rectangle().fill(Grafite.border).frame(height: 1) }

    private func line(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(color).padding(.top, 8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            divider.padding(.bottom, 4)
            HStack(spacing: 6) {
                Chip(title: help ? "Ajuda ▴" : "Ajuda ▾") { help.toggle() }
                Spacer()
                if state.showsQuit { Chip(title: "Sair") { act(.quit) } }
            }
            if help {
                Text("Capture \(state.version)").font(.system(size: 10)).foregroundStyle(Grafite.muted).padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    if state.showsSettings { Chip(title: "Configurações…") { act(.settings) } }
                    Chip(title: "Mostrar log de depuração") { act(.showLog) }
                    Chip(title: "Reportar problema…") { act(.report) }
                }
            }
        }
        .padding(.top, 8)
    }
}

/// Bloco de captura: símbolo, nome e o atalho nativo equivalente, pra ir aprendendo.
private struct Block: View {
    let title: String, symbol: String, key: String, hint: String?, red: Bool, accessibility: String, action: () -> Void
    @ViewState private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(red ? Grafite.rec : Grafite.strong)
                    .frame(height: 18)
                Text(title).font(.system(size: 9.5)).lineLimit(1)
                Text(key).font(.system(size: 9, design: .monospaced)).foregroundStyle(Grafite.accent).lineLimit(1)
            }
            .padding(.top, 7).padding(.bottom, 6).padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .background(Grafite.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(hover ? Grafite.accent : Grafite.cardBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(hint.map { "\(key), \($0)" } ?? key)
        .accessibilityLabel(accessibility)
        .accessibilityHint(hint.map { "Atalho nativo \(key), \($0)" } ?? "Atalho nativo \(key)")
    }
}

/// Botão discreto do rodapé e das configurações (o ".g" do mockup).
struct Chip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 10)).foregroundStyle(Grafite.muted)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Grafite.card, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
