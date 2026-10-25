# Capture

Print e gravação de tela do macOS direto da barra de menus, sem decorar atalho. Cada opção mostra o atalho nativo do lado, pra você ir aprendendo.

[Baixar a última versão](https://github.com/yagoramires/capture/releases/latest) · [Reportar problema](https://github.com/yagoramires/capture/issues/new)

O macOS tem um bom sistema de captura de tela, mas ele fica escondido atrás de atalhos como `⇧⌘4`, `⌃⇧⌘4` e `⇧⌘4` + Espaço + `⌥`, que são fáceis de esquecer. O Capture coloca todas essas opções num painel. Não tem gravador próprio: tudo passa pelo `screencapture` do sistema, o mesmo que os atalhos usam, com o mesmo som, a mesma qualidade e a mesma pasta.

## Instalar

1. Baixe o `Capture-x.y.z.dmg` (ou o `.zip`) na [página de releases](https://github.com/yagoramires/capture/releases/latest) e arraste o **Capture.app** pra pasta **Aplicativos**.
2. Abra o Capture. Como ele não é assinado com um certificado pago da Apple, na primeira vez o macOS avisa que não conseguiu verificar o desenvolvedor. Vá em **Ajustes do Sistema → Privacidade e Segurança**, role até o fim e clique em **Abrir Mesmo Assim**. No macOS 14 também dá para clicar com o botão direito no app → **Abrir** (a partir do macOS 15 esse atalho não libera mais o app). Pelo Terminal também resolve: `xattr -dr com.apple.quarantine /Applications/Capture.app`
3. Na primeira captura, dê a permissão de Gravação de Tela (veja **Permissões**).
4. Opcional: no painel do ícone do Capture, ligue **Abrir ao iniciar sessão**.

Requer macOS 14 ou mais novo. Roda nativo em Apple Silicon e Intel. Também dá pra compilar do código (veja **Build local**).

### Pelo NeyHub

Quem usa o [NeyHub](https://github.com/yagoramires/neyhub) pode instalar o Capture pela Loja dele (o `Capture-x.y.z.neyplugin` do release). Aí o Capture roda dentro do NeyHub: o painel do ícone é o mesmo, mas a Gravação de Tela e o Microfone são dados ao NeyHub (pela tela **Permissões**; **Conceder** no painel leva até ela), o NeyHub cuida do login, das atualizações e de mostrar ou esconder o ícone, e o painel do Capture não tem **Abrir ao iniciar sessão**, **Sair**, **Configurações…** nem a linha **Atualização pronta**. Feche o Capture avulso antes: se o NeyHub já roda o Capture, o avulso avisa (um aviso só), sai dos itens de login e fecha. Desinstalar pelo NeyHub no meio de uma gravação encerra como o `⌃⌘Esc`: o vídeo fica salvo.

### Desinstalar

1. No painel do ícone do Capture, desligue **Abrir ao iniciar sessão** e clique em **Sair**.
2. Apague o **Capture.app** de Aplicativos. Pelo NeyHub, é só desinstalar no card do Capture.
3. Em **Ajustes do Sistema → Privacidade e Segurança → Gravação de Tela e Áudio do Sistema**, remova o Capture.
4. Opcional, pra apagar as opções e os logs: `defaults delete local.capture; rm -rf ~/Library/Logs/Capture`

## Permissões

- **Gravação de Tela** (Ajustes do Sistema → Privacidade e Segurança → Gravação de Tela e Áudio do Sistema → Capture): pedida na primeira captura. Sem ela, o painel mostra **Precisa de Gravação de Tela · Conceder**. Dentro do NeyHub, a permissão é do NeyHub e o Capture nunca pede ao sistema: **Conceder** abre a tela **Permissões** do NeyHub.
- **Microfone**: só se você ligar **Gravar o microfone** ("Para gravar o som do microfone junto com a tela"). No avulso, o próprio macOS pergunta na primeira gravação com microfone. Dentro do NeyHub, com a opção ligada e sem a permissão, o painel mostra **Microfone sem permissão · Conceder**.

### Privacidade

O Capture não coleta nem envia nada. Prints e vídeos ficam só no seu Mac, na pasta que você escolheu.
A única conexão de rede é a consulta à API pública do GitHub (`api.github.com`) pra saber se tem
versão nova, e o download dela.

## Como usar

Clique no ícone do Capture na barra de menus. Abre um painel escuro com a versão e um ponto verde (tudo certo) ou âmbar (sem permissão):

| Parte | O que faz |
| --- | --- |
| Print | Salva um arquivo: tela inteira (do monitor onde está o mouse), parte, janela e janela sem sombra. |
| Copiar | Vai pra área de transferência: tela inteira, parte e janela. |
| Gravar vídeo | Tela inteira ou parte selecionada (escurece os monitores e você arrasta a área; Esc cancela). |
| Opções | As mesmas do `⇧⌘5` → Opções: **Timer** (nenhum, 5 ou 10 s, vale pra prints e gravações), mostrar o ponteiro (só no print da tela inteira), mostrar cliques e gravar o microfone (nas gravações) e abrir depois de capturar (como o Salvar em → Pré-Visualização). Mudam na hora, sem fechar o painel. |
| Pastas | **Prints** e **Gravações** abrem a pasta no Finder; **trocar…** escolhe outra (Mesa, Documentos ou Outro local…). Muda a pasta do sistema também, então vale pros atalhos nativos. |
| Painel de captura do macOS | Abre o painel nativo, igual ao `⇧⌘5`. |
| Atualização pronta — entra ao sair | Uma versão nova já foi baixada e entra quando você fechar o Capture. **Reiniciar agora** troca e reabre na hora. Não aparece dentro do NeyHub. |
| Abrir ao iniciar sessão | Liga o Capture junto com o Mac. Não aparece dentro do NeyHub. |
| Ajuda ▾ | Mostra a versão, abre o log de depuração, reporta problemas e, fora do NeyHub, abre as **Configurações…**. |
| Sair | Fecha o Capture. Não aparece dentro do NeyHub (fecharia o NeyHub inteiro). |

Cada bloco mostra o atalho nativo que faz a mesma coisa; parando o mouse em cima, aparece o passo seguinte (por exemplo, "depois aperte Espaço e clique na janela").

Enquanto grava, o ícone vira um botão vermelho com o tempo (ou a contagem do timer); pra parar, clique nele ou aperte `⌃⌘Esc`, o atalho nativo. Quando termina, o vídeo aparece no Finder (ou abre, com **Abrir depois de capturar**). Fechar o Capture no meio da gravação também para do mesmo jeito, sem perder o vídeo.

### Problemas

Em **Ajuda → Reportar problema…** no painel, o Capture abre uma issue no GitHub já com a versão, o macOS e os
monitores preenchidos, e mostra no Finder o log pra você anexar. O log fica em
`~/Library/Logs/Capture/capture.log` e só registra o que o app fez (qual captura, com quais opções,
o que o `screencapture` respondeu), nunca o conteúdo das capturas.

Se o ícone sumiu e você não acha as configurações, dá pra escondê-lo ou trazê-lo de volta pelo Terminal
(feche e reabra o Capture depois): `defaults write local.capture presence.menuBar -bool false` esconde,
`-bool true` mostra.

### Limitações

- O Touch Bar (`⇧⌘6`) não está no painel.
- Os prints e gravações do Capture não mostram a miniatura flutuante do canto da tela; use
  **Abrir depois de capturar** se quiser editar logo em seguida.
- Gravar só o áudio do sistema (sem microfone) não é possível pelo `screencapture`.

## Atalhos

O Capture não registra atalhos próprios: o painel mostra, do lado de cada bloco, o atalho nativo do macOS que faz a mesma coisa, e eles continuam valendo com o Capture fechado ou com o ícone escondido. O `⌃` é a tecla **Control**, não a Option (`⌥`).

#### Print: salva um arquivo

| Bloco | Atalho nativo |
| --- | --- |
| Tela inteira (do monitor onde está o mouse) | `⇧⌘3` |
| Parte | `⇧⌘4`. Enquanto arrasta: segure Espaço pra mover, `⇧` trava um lado, `⌥` cresce a partir do centro. Esc cancela. |
| Janela | `⇧⌘4`, depois Espaço e clique na janela |
| Sem sombra | `⇧⌘4`, depois Espaço, e clique na janela segurando `⌥` |

#### Copiar: vai pra área de transferência

| Bloco | Atalho nativo |
| --- | --- |
| Tela inteira | `⌃⇧⌘3` |
| Parte | `⌃⇧⌘4` |
| Janela | `⌃⇧⌘4`, depois Espaço e clique na janela |

#### Gravar vídeo

| Bloco | Atalho nativo |
| --- | --- |
| Tela inteira | `⇧⌘5`, depois **Gravar a Tela Inteira** |
| Parte selecionada | `⇧⌘5`, depois **Gravar a Parte Selecionada** |
| Parar | `⌃⌘Esc` (ou um clique no ícone vermelho) |

## Modos de exibição

O Capture não tem temas e roda só na barra de menus, sem janela. A única escolha de exibição é mostrar ou esconder o ícone. Escondido, nada para: uma gravação em andamento continua (pare com `⌃⌘Esc`) e os atalhos nativos continuam valendo. O ícone vira um botão vermelho com o tempo durante a gravação e ganha um sinal quando há atualização pronta.

- **Configurações**: no painel do ícone, **Ajuda ▾ → Configurações…**; com o ícone escondido, abra o Capture de novo pelo Finder (ou Spotlight) e a mesma janela aparece. Ela tem o interruptor **Mostrar na barra de menus**, se a Gravação de Tela foi concedida, os atalhos nativos e os botões **Mostrar log de depuração** e **Reportar problema…**. As opções de captura ficam no painel.
- **Dentro do NeyHub**: as configurações ficam no card do Capture, que não ganha item na barra lateral, e sem o interruptor do ícone (quem mostra ou esconde é o NeyHub). O card também mostra a permissão de Microfone.

## Atualizações

Desde a 0.3.0, o Capture confere 5 s depois de abrir e a cada 6 h se tem versão nova, baixa sozinho e só troca o app quando você fecha o Capture (ou clica em **Reiniciar agora** no painel): nunca reinicia sozinho no meio do uso. Na próxima abertura, mostra uma vez a janela **Novidades** com o que mudou. A versão baixada só é instalada se tiver sido assinada pelo mesmo certificado do app em uso, então a permissão de Gravação de Tela continua valendo. Dentro do NeyHub, quem atualiza é o NeyHub.

Quem está na 0.1.0 ou 0.2.0 recebe a 0.3.0 pelo aviso de atualização de sempre.

## Build local

### Compilar

Só precisa das Command Line Tools (`xcode-select --install`), não do Xcode.

```sh
git clone https://github.com/yagoramires/capture.git && cd capture
scripts/setup-signing.sh   # uma vez: certificado local de assinatura (veja abaixo)
scripts/build.sh --run     # gera build/Capture.app e abre (fecha o Capture aberto antes)
scripts/selftest.sh        # testes; imprime "selftest ok"
```

O NeyKit (tema, contrato de plugin) e o NeyKitApp (atualização, novidades) vêm do checkout do
[neyhub](https://github.com/yagoramires/neyhub) ao lado (`../neyhub`); para outro lugar, defina `NEYHUB_PATH`.

O `setup-signing.sh` cria um certificado de assinatura local ("Aero Local Signing", o mesmo do
[Aero](https://github.com/yagoramires/aero)) no seu Chaveiro. A permissão de Gravação de Tela fica presa
à assinatura do app: com assinatura ad-hoc ela muda a cada build e o macOS para de confiar no app. Sem o
certificado o build falha: o NeyHub só carrega plugins e as atualizações só entram com essa assinatura.

`scripts/make-icon.swift` gera o ícone (`Resources/AppIcon.icns`) a partir de código.

### Como funciona

O miolo fica em `Sources/CaptureCore` e é o mesmo no app avulso e no plugin do NeyHub:

| Arquivo | Papel |
| --- | --- |
| `CaptureApp.swift` | Ícone e painel da barra, ícone de gravação, ações, permissão e `stop()` (desinstalar no NeyHub). Recebe os `UserDefaults`, se está hospedado e a versão. |
| `PopoverView.swift` | O painel do ícone, em SwiftUI no tema Grafite do NeyKit. |
| `Screencapture.swift` | Monta os comandos do `screencapture` pra cada tipo de print, cuida da gravação (`Recorder`), da pasta do sistema e das opções. |
| `AreaPicker.swift` | Seleção da área pra gravar: escurece os monitores e deixa arrastar um retângulo. |
| `Log.swift` | Log de depuração em `~/Library/Logs/Capture/`, com rotação. |
| `SettingsView.swift` | Configurações (janela do avulso e card no NeyHub). |
| `SelfTest.swift` | `--selftest` (rode com `scripts/selftest.sh`). Troca o `screencapture` por um processo falso: nunca tira print nem grava. |
| `Snapshots.swift` | `Capture --snapshots <pasta>` desenha o painel e as configurações em PNG. |

As cascas: `Sources/Capture` (app avulso: confere se o NeyHub já roda o Capture, atualização e novidades
do NeyKitApp) e `Sources/CapturePlugin` (o `libCapturePlugin.dylib` que o NeyHub carrega; linka só o NeyKit).
O `Info.plist` declara `NeyHubAware = true` porque o avulso chama `HubCheck.leaveForHub` ao abrir: com essa
chave o NeyHub não mostra o alerta dele quando o avulso abre (só declare em app que faz essa checagem).

### Depuração

Só no avulso:

```sh
defaults write local.capture debugBridge -bool true   # liga os comandos abaixo; reabra o app
scripts/debug.sh dump            # ambiente e o estado do painel em /tmp/capture-debug.txt
scripts/debug.sh shot-screen     # print da tela inteira (também copy-screen)
scripts/debug.sh record-area     # grava uma área fixa de 400×300 (também record-screen)
scripts/debug.sh record-stop     # para a gravação
scripts/debug.sh toolbar         # abre o painel ⇧⌘5
tail -f ~/Library/Logs/Capture/capture.log
```

### Publicar uma versão

1. Suba a versão em `Resources/Info.plist` (`CFBundleShortVersionString` e `CFBundleVersion`) e
   escreva a seção `## [x.y.z]` do `CHANGELOG.md` (vira a nota do release e a janela Novidades).
2. `scripts/release.sh` gera em `dist/` o `Capture-x.y.z.dmg`, o `Capture-x.y.z.zip` (o app, que a
   atualização automática baixa) e o `Capture-x.y.z.neyplugin` (o plugin do NeyHub). Só empacota.
3. Commit, push e `NEYHUB_CONFIRM_PUBLISH=yes scripts/release.sh --publish` para criar o release.

O release **precisa ser assinado com o mesmo certificado** das versões anteriores, senão os apps já
instalados recusam a atualização automática. Antes de trocar de Mac, exporte o "Aero Local Signing"
pelo app Acesso às Chaves (com a chave privada) e importe no Mac novo.

## Patch notes

Veja o [CHANGELOG](CHANGELOG.md).

## Licença

[MIT](LICENSE)
