# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [0.3.0] - 2026-10-25

### Adicionado
- Instalação pelo NeyHub: o Capture também vem como plugin (`Capture-0.3.0.neyplugin`) e roda dentro do NeyHub, que dá as permissões de Gravação de Tela e Microfone pela tela de Permissões dele. Desinstalar pelo NeyHub no meio de uma gravação encerra como o `⌃⌘Esc`: o vídeo fica salvo.
- Instalador `.dmg`, além do `.zip`.
- Configurações em **Ajuda ▾ → Configurações…** (ou, com o ícone da barra escondido, abrindo o Capture de novo pelo Finder): janela com o interruptor **Mostrar na barra de menus**, o estado da Gravação de Tela, os atalhos nativos e os botões de log e de reportar problema. No NeyHub, ficam no card do Capture.
- Fechar o Capture no meio de uma gravação também encerra como o `⌃⌘Esc`, sem perder o vídeo.

### Alterado
- O menu da barra virou um painel no tema Grafite: blocos de **Print**, **Copiar** e **Gravar vídeo** com o atalho nativo de cada um (o passo seguinte aparece ao parar o mouse no bloco), **Opções** à vista (Timer, ponteiro, cliques, microfone e abrir depois), **Pastas** com **trocar…**, **Painel de captura do macOS** e **Ajuda ▾**. Enquanto grava, o ícone continua sendo o botão vermelho com o tempo, e um clique para.
- Atualização automática sem perguntar: o Capture confere 5 s depois de abrir e a cada 6 h, baixa sozinho e troca a versão quando você fecha o app (ou em **Reiniciar agora**). Depois de atualizar, mostra as novidades uma vez. O item **Buscar atualizações…** saiu do menu.
- Se o NeyHub já roda o Capture, o avulso avisa, sai dos itens de login e fecha, para não rodar duas vezes.
- O build exige o certificado "Aero Local Signing"; não assina mais ad-hoc.

## [0.2.0] - 2026-10-22

### Adicionado
- Prints e gravações podem ir para pastas diferentes: em **Opções**, **Salvar prints em** e **Salvar gravações em**. A escolha vale também para os atalhos nativos (`⇧⌘3`, `⇧⌘4`, `⇧⌘5`).
- No fim do menu, **Prints** e **Gravações** abrem a pasta de cada um no Finder. Se for a mesma pasta, aparece um item só: **Capturas**.

## [0.1.0] - 2026-10-22

### Adicionado
- Primeira versão: todos os tipos de print do macOS (tela inteira, parte selecionada, janela com e sem sombra), salvando ou copiando, e gravação da tela inteira ou de uma área, cada um com o atalho nativo equivalente do lado.
- Opções iguais às do `⇧⌘5`: Salvar em, Timer, ponteiro, cliques e microfone.
- Atualização automática e log de depuração.
