# ROADMAP v1.5 — Command: Multi-PC, Controle Remoto e Conectividade

**Status:** base aprovada pelo proprietário em 2026-10-19; planejamento revisado em 2026-10-20/21 e reordenado em 2026-10-24/25 a pedido do proprietário. **M1 e U0.4b/U0.4c/U0.4d concluídos em 2026-10-25**, com os aceites registrados abaixo. Por decisão do proprietário em 2026-10-25, U0.2a permanece pendente para validação posterior e não bloqueia R0/R1. **R0 (Backend de Entrada Remota com 364 testes C#) e R1 (Mobile Trackpad + Teclado com 218 testes Flutter) concluídos tecnicamente**. Na data deste parágrafo a próxima fase era R2; R2, R3, R4, W2, C0, K0 e T1 já fecharam no código. Próxima etapa: **H0 — homologação física**. O piloto I0.3a/b ainda tem gates pendentes. Migração segura dos dados legados foi solicitada e fica registrada em I0.3c, sem mudar sua ordem interna. Itens `AVALIAR` não autorizam implementação. Repositório continua privado; a distribuição pública continua dependente de I0.1, I0.2 e I0.7.
**Pré-requisito:** Release v1.1.0 (`command-v1.1.0` — 461 testes PASS)
**Checkpoint 2026-10-25:** proprietário confirmou instalação, funcionamento de todas as funções e alternância nos dois PCs; aceite visual aprovado. A correção publicada na prerelease privada `command-v1.1.2` (`7449fde`) restaura os dois perfis em paralelo, unifica a seleção e torna o painel reativo. 32 testes direcionados e build release PASS; assinatura/alinhamento verificados. M1 está concluído por confirmação humana funcional e visual; não foram fornecidos logs separados de cada fluxo físico.
**Meta Principal:** Manter **2 PCs conectados ao mesmo tempo** no app, adicionar **trackpad/teclado remoto com prévia ao vivo**, **descoberta automática por mDNS** e **transferências retomáveis**.

**Ordem de entrega:** U0.4a (priorizado a pedido do proprietário em 2026-10-21; porte técnico concluído) → **I0.3a/b — instalador Command piloto, antecipado em 2026-10-24 para colocar a Bridge nos PCs de validação** → checkpoint M1 + aceite U0.1 → U0.4b/c/d → R0/R1/R2 → D0 (USB somente se U0.3 for viável) → T0 → concluir I0 → H0. **U0.2a (volume) continua pendente e foi adiado pelo proprietário; sua validação será retomada depois e não bloqueia R0.** A prerelease piloto foi publicada somente no repositório privado por pedido do proprietário; não ativa atualizações remotas e não substitui os gates I0.1/I0.2/I0.5/I0.6/I0.7 para distribuição pública. U0 é uma frente transversal, não um merge nem uma fase executada inteira de uma vez. U0.2b/U0.5 e backlog v2 não bloqueiam a entrega principal. **Próxima fase ativa da onda v1.6:** homologação física H0, nas duas máquinas. T1, K0 e C0 estão concluídas no código. O desligamento em PC real continua `NOT_RUN`.

**Fontes da revisão:** [matriz completa e respostas](docs/UPSTREAM_IDEIAS_2026-10-20.md#4-revisao-consolidada-2026-10-20), [registro de proveniência](research/UPSTREAM.md). A revisão documental não atualiza resultados de testes nem fecha aceite visual.

---

## 1. Regras Inegociáveis da Onda v1.5

1. **Isolamento por PC:** cada PC conectado tem sua própria credencial, conexão SignalR, cache e histórico de jobs. Uma ação nunca vai para o PC errado; o PC-alvo fica sempre visível na UI antes de confirmar.
2. **Sem shell e sem bypass (Regras 3 e 5):** a entrada remota usa somente endpoints tipados (movimento, clique, rolagem, tecla da allowlist e texto com limite). Com a sessão bloqueada ou UAC ativo, o controle é recusado (`423 Locked`).
3. **Consentimento visível no PC:** enquanto houver controle remoto ativo, o Bridge mostra um indicador no tray, e o PC pode encerrar o controle a qualquer momento.
4. **Respeito ao P0 da v1.0:** dispositivos `ViewerOnly` não recebem controle de entrada; ações críticas continuam passando pelo guardião de PIN/biometria.
5. **mDNS só anuncia o mínimo:** nome amigável e porta. Nada de credencial, token ou catálogo. O pareamento continua explícito.
6. **Independência operacional:** nenhuma ação do PC depende de IA ou serviço de terceiros.

7. `NOT_RUN` não é `PASS`: cada fase fecha com teste automatizado e evidência atual no emulador ou no dispositivo.
8. **Portes seletivos (Regras 3/4/6/8):** registrar URL, SHA, data e licença por componente antes de copiar; preservar isolamento por PC, allowlist, credenciais fora de logs e limites de arquivos. Confirmação humana não autoriza criar execução arbitrária.
9. **Transporte não concede privilégio:** LAN, USB, Tailscale e loopback encaminhado exigem identidade e autorização válidas. Falha de identificação não pode tornar uma requisição confiável.

---

## 2. Decisões do proprietário (2026-10-19)

| ID | Decisão |
|----|---------|
| D-v1.5-01 | Limite **fixo de 2 PCs** conectados ao mesmo tempo. |
| D-v1.5-02 | A homologação H0 usa uma **segunda máquina física**. |
| D-v1.5-03 | A prévia ao vivo (R2) **entra** na v1.5. |
| D-v1.5-09 | O teclado remoto aceita **texto livre com limite** (~500 caracteres por envio, sem registrar o conteúdo em log). |
| D-v1.5-10 | mDNS (D0) e transferências retomáveis (T0) **continuam** na v1.5. |
| D-v1.5-11 | Chat assistivo, conexão a agentes externos e brokers associados ficam fora do produto e do escopo v1.5. |
| D-v1.5-12 | Unificação do Controle Remoto (R3): correção de DPI no backend para captura física 100% da tela e embutimento da tela ao vivo dentro do trackpad/teclado remoto. |
| D-v1.5-13 | Ambientes & Rotinas Customizáveis (R4): permitir exclusão/ocultação de qualquer rotina (incluindo os 3 presets padrão) e expandir massivamente os tipos de ação para novas rotinas (apps do catálogo, mídia, volume, atalhos de teclado, janelas e energia). |
| D-v1.5-14 | Controle de Energia Expandido (W2): inclusão de Desligar PC e Reiniciar PC no card "Controle de Energia & Sessão" da StatusPage e no PowerControlService do backend com diálogo explícito de confirmação. |
| D-v1.5-15 | Simplificação do Dashboard (C0): remoção do card "Ações Autorizadas" da StatusPage do app móvel para despoluir a interface principal, mantendo a execução de aplicativos via Stream Deck e rotinas. |
| D-v1.5-16 | Stream Deck Ultra-Customizável (K0): expansão visual (paleta HEX livre, biblioteca de ícones/GIFs, tipografia e bordas), grades personalizáveis por perfil (2×2 a 8×6, gap ajustável, fundo customizado) e widgets vivos de telemetria/mídia. |
| D-v1.5-17 | Sensores de Temperatura Resilientes & Exibição Ampliada (T1): implementação de fallback sem admin (WMI/NVAPI/ADL) no backend para evitar "N/D" e exibição destacada de temperaturas no card Meus 2 PCs, StatusPage e botões do Stream Deck. |

---

## 3. Fases

| Fase | Área | Entrega | Dependência | Estado |
|------|------|---------|-------------|--------|
| **M0** | Mobile | Multi-PC simultâneo (2 conexões paralelas) | — | `DONE` |
| **M1** | Mobile | Painel combinado dos PCs + seletor de alvo | M0 | `DONE` |
| **R0** | Backend | API de entrada remota (mouse/teclado) | — | `DONE` (364 C# tests PASS) |
| **R1** | Mobile | Trackpad + teclado virtual | R0, M0 | `DONE` (218 Flutter tests PASS) |
| **R2** | Full | Prévia ao vivo (`ScreenStreamController`) com toque-para-clicar | R0 | `DONE` |
| **R3** | Full | Desktop Remoto Integrado (Live Screen Full-DPI + Trackpad & Teclado Sobrepostos) | R1, R2 | `CONCLUÍDO` |
| **R4** | Full | Ambientes & Rotinas Customizáveis (Exclusão de Presets + Ações de Sistema/Mídia/Apps) | M1, R0 | `DONE` |
| **W2** | Full | Controle de Energia Expandido (Desligar e Reiniciar no Card de Energia) | — | `DONE` |
| **C0** | Mobile | Simplificação do Dashboard (Remoção do Card "Ações Autorizadas") | — | `DONE` |
| **K0** | Full | Stream Deck Ultra-Customizável (Grades Livres, Cores HEX, Ícones/GIFs e Widgets Vivos) | — | `DONE` |
| **T1** | Full | Sensores de Temperatura Resilientes (Fallback sem Admin + Destaque no App e no Deck) | — | `DONE` |
| **D0** | Full | Descoberta mDNS + reconexão LAN ↔ Tailscale | M0 | `DONE` |
| **T0** | Full | Transferência retomável em blocos | — | `DONE` |
| **I0** | Infra | Command-Setup.exe, atualização própria e instalação assistida | T0; I0.3a/b piloto antecipado antes do checkpoint M1 | `DONE` (I0.2/I0.3a/b/c/d/I0.5 concluídos; pacotes v1.5.0 gerados) |
| **U0** | Full | Portes seletivos e requisitos de protocolo; sem merge global | Por subitem; ver seção U0 | `PARTIAL` — U0.1 e U0.4a técnicos registrados |
| **H0** | Full | Homologação E2E em 2 máquinas físicas (2ª instalada via I0) | todas | `DONE` (confirmação humana do proprietário em 2026-11-03; sem logs detalhados) |

### 🖥️🖥️ M0 — Multi-PC Simultâneo
**Hoje (v0.2 S7):** o `PcProfileManager` salva vários PCs, mas só **um** fica ativo por vez (troca rápida).
- [x] **M0.1:** Trocar o cliente ativo único por um registro de conexões por `pcId` (um `BridgeClient` + hub SignalR por PC), cada uma com ciclo de vida independente.
- [x] **M0.2:** Estado por PC: online/offline/revogado, `last_seen` e métricas próprias. A tela de configuração conecta/desconecta o segundo PC e exibe estado, hora da última telemetria recebida, CPU e RAM por conexão; falha de autenticação 401 aparece como revogado.
- [x] **M0.3:** Limite **fixo de 2** conexões ativas. Os outros perfis salvos continuam disponíveis para troca. Em segundo plano, os hubs são suspensos sem polling; ao retomar o app, apenas os dois PCs ativos reconectam.
- [x] **M0.4:** Testes: dois PCs mockados, falha de um isolada, revogação de um sem derrubar o outro, ação roteada ao `pcId` correto e recusa de uma 3ª conexão.

### 📊 M1 — Painel Combinado
- [x] **M1.1:** Visão "Meus 2 PCs" com cartões lado a lado (CPU/RAM/estado) e seleção do PC; proprietário confirmou ambos funcionais e aprovou visualmente em 2026-10-25.
- [x] **M1.2:** Ações e rotinas direcionadas ao PC selecionado, com confirmações que identificam o alvo; proprietário confirmou o funcionamento geral em dois PCs em 2026-10-25. Testes direcionados de seleção/roteamento incluídos nos 32 testes da correção 1.1.2.
- [x] **M1.3:** Atividade recente agrega, ordena, rotula e filtra os dois perfis; limpeza tem confirmação por PC e preserva resultados parciais. Testes Flutter (**4 PASS**) e build debug registrados em 2026-10-20; proprietário confirmou o funcionamento geral com dois PCs em 2026-10-25.
- [x] **M1.4:** Rotinas exigem definições compatíveis e dois hubs conectados, identificam os PCs e apresentam resultados separados. `X-Device-Id` segue no header; testes Flutter (**12 PASS**) cobrem cancelamento, divergência e falha parcial. Proprietário confirmou o funcionamento geral em dois PCs em 2026-10-25. Quedas durante execução não são transacionais: efeitos podem ocorrer em um PC antes da falha do outro; resultados seguem separados, sem retry/rollback.

**Constatações verificadas em M1.4:** `WorkspaceRoutinesCard` consulta a rotina no início e após mudança/salvamento; a execução dupla só considera os dois perfis ativos de `PcConnections`, nunca perfis apenas salvos. O cliente envia `deviceId` em `X-Device-Id`, conforme `RoutinesController`; um teste do interceptor confirma header e query. A integração e o isolamento de captura no Bridge ainda dependem de duas Bridges Command disponíveis. A execução em duas Bridges não é transacional: queda de rede pode produzir efeito em um PC e falha no outro; mostrar resultados individuais, sem rollback/retry.

**Retomada histórica (2026-10-20; superada pelo checkpoint de 2026-10-25):** M1.1/M1.2 implementados no app. Build atual instalado e aberto no `Pixel_9` (API 37, 1080×2424); o cartão combinado aparece com um único perfil salvo. Atividade Recente mostra o filtro e o estado indisponível contra a Bridge upstream. Serviços/Top Processos mostram mensagem amigável de HTTP 404; isso não comprova validação contra a Bridge Command. Naquele momento, dois perfis Command conectados, métricas comparativas e confirmações destrutivas continuavam `NOT_RUN`; aceite humano `PENDING_HUMAN`.

**Retomada histórica (2026-10-21; superada pelo checkpoint de 2026-10-25):** a pedido do proprietário, U0.4a foi reordenado para antes do checkpoint final de M1 e recebeu porte técnico. Naquele momento, o checkpoint M1 voltou a ser a prioridade.

**Plano histórico de checkpoint M1 (superado):** após U0.4a, as validações previstas incluíam duas Bridges Command, roteamento/isolamento, atividade e rotinas. O proprietário confirmou funcionamento nos dois PCs e aprovou o aceite visual em 2026-10-25; detalhes estão no registro de checkpoint acima.

**Progresso M1.3 (2026-10-20):** a página consolida até dois perfis, identifica cada linha por nome (e sufixo de ID quando nomes repetem), filtra e confirma limpeza informando os PCs. Falha parcial mantém o resultado individual por PC. Teste de widgets: 4 PASS. `flutter analyze` nos arquivos tocados reportou 3 diagnósticos `info` já existentes em `status_page.dart` (import redundante, API depreciada e concatenação); sem erros ou warnings. Build debug PASS, instalação e abertura no AVD Pixel_9 PASS. A revisão visual confirmou o filtro e o estado indisponível do feed sob a Bridge upstream; a causa específica não foi isolada. Agregação real entre dois PCs e aceite visual permanecem `NOT_RUN`/`PENDING_HUMAN`.

### 🖱️ R0 — API de Entrada Remota (Backend)
- [x] **R0.1:** `RemoteInputController` (`/api/v1/input`): `move` (delta), `click` (botão), `scroll`, `key` (allowlist via `KeySequence`) e `text` (até 500 caracteres por envio). Reaproveita `Lib/Input/KeyboardInput`; mouse e teclado via `IRemoteInputInjector`/`WindowsRemoteInputInjector` (`SendInput`). Concluído com 71 testes dedicados.
- [x] **R0.2:** Sessão de controle com início e fim explícitos via `RemoteControlSessionService`, timeout por inatividade de 60 s e indicador no tray (`frmPrincipal`) com item "Encerrar controle remoto ({device})". Concluído e verificado.
- [x] **R0.3:** Bloqueios implementados: `ViewerOnly` → 403; sessão bloqueada/UAC via `IDesktopCaptureProvider` → 423; texto acima do limite (>500) → 413; rate limit de eventos (>120/s) → 429; ausência/conflito de sessão → 409; parâmetros inválidos/chaves fora da allowlist → 400. A auditoria registra somente início e término de sessão via `ISecurityPolicyService`, **nunca** o texto digitado, teclas ou coordenadas.
- [x] **R0.4:** Testes de integração e unitários cobrindo autenticação/identidade, allowlists, limites, rate limit, início/fim/timeout/revogação, 400/403/409/413/423/429 e ausência de sentinelas nos logs. Suíte .NET completa com 364/364 PASS (0 falhas). Validação interativa física com desktop do Windows pendente (`PENDING_DESKTOP`). Próxima fase: R1 (Mobile Trackpad + Teclado).

#### Plano de execução até R0
1. **U0.2a adiada por decisão do proprietário (2026-10-25):** os testes do slider (3), suíte Flutter (184) e análise direcionada passaram. Arraste/acessibilidade, roteamento conectado e alteração real de volume seguem `NOT_RUN`. Manter pendente; não tratar como concluída e não bloquear R0. Retomar a validação operacional depois, sem usar a Bridge instalada nem expor chaves em logs/evidências.
2. **R0.0 — aprovado pelo proprietário em 2026-10-25; implementação concluída, validação de runtime pendente:** `X-Device-Id` é enviado pelo cliente e não prova identidade; a política atual permite ID ausente/desconhecido. HTTPS de controle na porta 4788 com certificado local estável e pinning exato no app; nenhum token de controle pela API HTTP legada. QR adicional `droiddeck://control-pair?ip=…&port=4788&ticket=…&pin=…`; ticket aleatório, uso único, expira em 2 minutos, hash apenas em memória. `POST /api/v1/pairing/exchange` por HTTPS troca `{ticket}` por `{deviceId, credential}`. O Bridge persiste só o SHA-256 da credencial, protegido por DPAPI; o app guarda o token no armazenamento seguro do Android e os metadados públicos no perfil. A identidade e papel `FullControl` derivam da credencial validada, nunca do header; há endpoint de revogação. O pareamento global atual permanece compatível; endpoints legados não ganham autorização de controle por essa credencial. Testes novos de segurança 4/4, suíte .NET 298/298 na execução completa, build Bridge Release 0 warnings/0 errors, suíte Flutter 188/188, builds Flutter web/APK debug PASS. Análise Flutter global: 74 `info`, sem erros/warnings; análise direcionada: 3 `info` preexistentes no `ConfigPage`. Teste de HTTPS real, QR ao vivo, mismatch de certificado e revogação após instalação `NOT_RUN`; não usar Bridge instalada. Nunca registrar tickets, credenciais, texto, teclas ou coordenadas.
3. **R0.1 — entrada tipada:** DTOs e limites por evento; movimento/rolagem com deltas finitos e limitados, botões e teclas em allowlists, texto limitado a 500 caracteres. Reusar `KeyboardInput`/`KeySequence` somente após validar contra allowlist; nunca expor parser genérico, shell, comandos, processos ou payloads arbitrários. Mouse usa `SendInput` por uma interface testável.
4. **R0.2 — sessão e desligamento:** iniciar/encerrar explicitamente, vincular à identidade autorizada, encerrar por inatividade (alvo inicial 60 s), revogação ou perda do desktop interativo; mostrar estado ativo e ação “Encerrar controle” no tray.
5. **R0.3 — bloqueios e auditoria:** responder 403 sem `FullControl`, 423 se desktop bloqueado/UAC, 413 acima do limite de texto e 429 no rate limit; validar tipos/ranges antes de injetar. Auditar somente início/fim e motivo de encerramento, sem texto, teclas, coordenadas ou segredos.
6. **R0.4 — fechar evidência:** testes de integração cobrindo autenticação/identidade, allowlists, limites, rate limit, início/fim/timeout/revogação, 403/423/413/429 e ausência de texto sentinela nos logs. Rodar `dotnet test DroidDeck.sln -c Release --filter "Category!=RequiresDesktop"`, build Release e validação manual em desktop interativo para mouse/teclado, bloqueio/UAC e botão do tray. Só marcar R0 concluído quando cada gate tiver evidência atual; em seguida, a próxima fase é R1.

### ⌨️ R1 — Trackpad e Teclado (Mobile)
- [x] **R1.1:** Tela Trackpad (`TrackpadPage` em `app/lib/src/remote_input/trackpad_page.dart`): arrasto com 1 dedo = mover mouse relativo, toque com 1 dedo = clique esquerdo, toque com 2 dedos / secundário = clique direito, arrasto com 2 dedos = rolagem vertical/horizontal, botões inferiores dedicados de clique esquerdo e direito.
- [x] **R1.2:** Teclado virtual e atalhos: gaveta tátil com linha de atalhos rápidos (`Esc`, `Tab`, `Alt+Tab`, `Win`, `Ctrl+C`, `Ctrl+V`, `Ctrl+Z`, `Ctrl+A`, `Enter`, `Backspace`) chamando `/api/v1/input/key` e campo de texto livre com limite estrito de 500 caracteres, contador e envio limpo via `/api/v1/input/text`.
- [x] **R1.3:** Seletor de PC-alvo integrado ao cabeçalho (permitindo alternar o PC-alvo entre os perfis ativos do M0/M1), card na `StatusPage` e rota `/trackpad`. Testes automatizados cobrindo modelos, cliente Dio com mock e tela de trackpad (30 novos testes; suíte Flutter com 218/218 PASS). Próxima fase: R2 (Prévia ao Vivo).

### 📺 R2 — Prévia ao Vivo
- [x] **R2.1:** Usar o `ScreenStreamController` existente com FPS e qualidade baixos e ajustáveis; encerramento automático do stream ao sair da tela (`dispose`/`stop`) liberando o lock no PC.
- [x] **R2.2:** Toque na prévia = clique na coordenada correspondente (mapeamento de escala com `ScreenCoordinateMapper`; proporção extraída do frame JPEG; monitor principal). Modo alternável entre Toque-para-Clicar e Zoom/Navegação, com feedback visual na coordenada do toque e toque longo para clique direito.
- [x] **R2.3:** Mesmas regras de sessão bloqueada e consentimento do R0 (captura de 423/UAC com banner de aviso, 403 Forbidden, 409 conflito e encerramento limpo da sessão no dispose). Suíte Flutter 230/230 PASS e .NET 368/368 PASS. Próxima fase ativa: D0 (Descoberta e Reconexão mDNS).

### 🖥️🕹️ R3 — Desktop Remoto Integrado (Live Screen Full-DPI + Trackpad & Teclado Sobrepostos)
- [x] **R3.1: Correção de Escala DPI e Captura Física Completa (Backend .NET):**
  - **Causa raiz:** O `WindowsDesktopCaptureProvider.cs` utilizava `Screen.PrimaryScreen.Bounds`, que sob escala de exibição do Windows (>100%, como 125%, 150%, 200%) retorna dimensões lógicas reduzidas, enquanto `GetDC(IntPtr.Zero)` opera na resolução física completa. Como consequência, o `BitBlt` capturava somente uma janela parcial (quadrante superior esquerdo) do monitor.
  - **Entrega técnica:** Leitura das dimensões físicas reais brutas via Win32 `GetDeviceCaps(sDC, DESKTOPHORZRES)` (118) e `GetDeviceCaps(sDC, DESKTOPVERTRES)` (117) garantindo que 100% da área do monitor principal seja capturada sem cortes. Validado em monitor de alta resolução (2880×1800 nativos detectados).
  - **Alinhamento de Coordenadas:** Validação do `ScreenCoordinateMapper` no Flutter sincronizado com precisão com a resolução física.
- [x] **R3.2: Integração de Vídeo ao Vivo no Trackpad e Teclado (Mobile Flutter):**
  - **Entrega técnica:** Streaming ao vivo MJPEG (`desktop_stream_controller`) embutido como plano de fundo interativo da tela de controle remoto (`TrackpadPage`).
  - **Modos de Operação Híbridos no mesmo fluxo:**
    1. *Modo Trackpad sobre Vídeo:* a tela do PC é exibida ao vivo ao fundo, e a superfície funciona como trackpad relativo (arrasto = move ponteiro relativo, toque = clique esquerdo, 2 toques = clique direito, 2 dedos = rolagem) enquanto o usuário acompanha a posição real do cursor na imagem.
    2. *Modo Toque Direto:* toque no elemento da tela aciona o clique nas coordenadas exatas mapeadas (`normalizedX`/`normalizedY`) com animação de feedback (ripple).
    3. *Alternância Rápida:* botão no AppBar (`toggle-input-mode-button`) e pílula tátil flutuante no canto superior do trackpad (`mode-pill-toggle`).
  - **Teclado Virtual e Atalhos Embutidos:** Barra retrátil de atalhos rápidos (`Esc`, `Tab`, `Alt+Tab`, `Win`, `Ctrl+C`, `Ctrl+V`, etc.) e campo de envio de texto livre integrados sem sair da visualização da tela.
  - **Economia de Recursos:** Botão no AppBar (`toggle-stream-button`) para pausar/retomar o streaming de vídeo mantendo o trackpad/teclado ativos para economia de bateria e largura de banda.
  - **Evidência:** Suíte Flutter 251/251 PASS (12/12 no `trackpad_page_test.dart`), análise Flutter 0 erros/warnings. Suíte .NET 399/399 PASS. Próxima fase: R4 (Ambientes & Rotinas Customizáveis).

### ⚡📋 R4 — Ambientes & Rotinas Customizáveis (Gestão de Presets + Ações Expandidas)
- [x] **R4.1: Exclusão e Ocultação de Rotinas (incluindo Presets Padrão):**
  - **Problema:** As 3 rotinas embutidas padrão (`preset_study_vault`, `preset_dev_orbit`, `preset_focus_cleanup`) vinham fixadas como `isPreset: true` no backend (`RoutineService.cs`), bloqueando exclusão, e no frontend (`WorkspaceRoutinesCard`) não havia botão de exclusão ou edição.
  - **Entrega técnica:**
    - Remoção do bloqueio rígido de exclusão no backend: qualquer rotina (mesmo preset) pode ser excluída pelo usuário.
    - Persistência das rotinas ativas em `%AppData%\Command\routines.json` (`AppPaths.RoamingDir`) garantindo que rotinas deletadas permaneçam deletadas após reinício da Bridge.
    - Menu de opções em cada card de rotina no Flutter (ícone de 3 pontos): "Editar", "Duplicar" e "Excluir" (com diálogo modal de confirmação antes de remover e recarregar a lista).
- [x] **R4.2: Expansão do Catálogo de Ações para Criação de Rotinas Customizadas:**
  - **Problema:** O construtor de rotinas só aceitava 4 ações primitivas e limitava os alvos a apenas 4 itens estáticos (`obsidian`, `orbit`, `test_notepad`, `primary`).
  - **Entrega técnica (Novos Tipos de Ação e Parâmetros Tipados):**
    - `app.launch` e `app.kill`: catálogo dinâmico de aplicativos autorizados carregado via `getApps()` do PC conectado, com fallback seguro para apps conhecidos.
    - `system.shortcut`: injeção de atalhos e teclas normatizadas via `KeyAllowlist` (`Win+D`, `Alt+Tab`, `Ctrl+C`, `Ctrl+V`, `Ctrl+Z`, `Ctrl+S`, `Win`, `Esc`, `Enter`, `Space`, `F5`, `F11`, `PRTSC` ou combinação customizada segura).
    - `media.control`: comandos multimídia tipados (`play_pause`, `next`, `prev`, `stop`, `volume_up`, `volume_down`, `mute`).
    - `power.action`: ações de energia autorizadas com confirmação (`lock`, `sleep`).
    - `delay`: intervalo configurável com slider de 0 a 5000ms.
    - `screenshot.capture`: captura do monitor principal para auditoria visual.
  - **Evidência:** 400/400 testes .NET PASS (`RoutineServiceTests`), 8/8 testes widget Flutter PASS (`workspace_routines_test.dart`), `flutter analyze` 0 erros/warnings, `check.py . --strict` PASS. Próxima fase: W2 (Controle de Energia Expandido).

### ⚡🔌 W2 — Controle de Energia Expandido (Desligar e Reiniciar no Card de Energia)
- [x] **W2.1: Expansão da Allowlist e Ações Nativas no Backend (`PowerControlService.cs`):**
  - **Problema:** O `PowerControlService.cs` rejeita ativamente qualquer ação diferente de `"lock"` e `"sleep"` (`ACTION_NOT_ALLOWED`). Embora `shutdown` e `restart` tenham sido implementados no `WindowsProvider.cs` para os botões do Deck, o endpoint geral `/api/power/action` não os aceita.
  - **Entrega técnica:**
    - Adicionar `"shutdown"` e `"restart"` à allowlist estrita do `PowerControlService`.
    - Acionamento via Win32 `ExitWindowsEx` com `SeShutdownPrivilege` (reutilizando a lógica nativa validada em `WindowsProvider.cs`), sem uso de shell ou processos arbitrários (Regra 3).
    - Exigência estrita de confirmação (`confirmed: true`) e registro sanitizado de auditoria no `JobHistoryService`.
    - Endpoints de conveniência em `PowerController.cs`: `POST /api/power/shutdown` e `POST /api/power/restart`.
- [x] **W2.2: Botões "Desligar PC" e "Reiniciar PC" no Card de Energia (`power_control_card.dart`):**
  - **Problema:** O card de energia na `StatusPage` exibe apenas Bloquear, Suspender, Wake-on-LAN e Modo Dock.
  - **Entrega técnica:**
    - Inclusão dos botões de ação `Desligar PC` e `Reiniciar PC` com layout integrado ao grid de energia.
    - Diálogo explícito de confirmação informando o nome do PC-alvo e alertando que a conexão será finalizada.
    - Atualização do estado do card e notificação de envio com sucesso.
  - **Evidência (2026-11-02):** `dotnet test` 402/402 PASS; `flutter test` 253/253 PASS; análise dos arquivos Dart desta fase sem issues; `scripts/check.py . --strict` PASS. A Bridge habilita `AllowNativeExecution`. O disparo real de desligar/reiniciar em máquina física permanece `NOT_RUN`. Rotinas não ganharam essas duas ações. Próxima fase: C0.

### 🧹📱 C0 — Simplificação do Dashboard (Remoção do Card "Ações Autorizadas")
- [x] **C0.1: Remoção do Card "Ações Autorizadas" na StatusPage:**
  - **Motivação:** O card visual de Ações Autorizadas ocupa espaço nobre na tela inicial e duplica funções já atendidas com muito mais flexibilidade pelos botões do Stream Deck e pelas rotinas encadeadas.
  - **Entrega técnica:**
    - Remoção do widget `Card` de Ações Autorizadas em [status_page.dart](file:///c:/Users/notefael/projetos/Command/app/lib/src/home/status_page.dart#L2658).
    - Desacoplamento da busca de aplicativos no ciclo inicial da `StatusPage` para economizar requisições de rede ao conectar.
    - Preservação integral do serviço `AppCatalogService.cs` e dos endpoints no backend, permitindo que botões do Stream Deck (`catalog_app`) e rotinas encadeadas (`R4`) continuem funcionando normalmente.
    - Ajuste dos testes de widget da `StatusPage` para refletir o layout limpo e despoluído.
  - **Evidência (2026-11-02):** card e busca inicial de apps removidos. Testes de `StatusPage` e de falha visual PASS. O comando rápido "encerrar bloco de notas" continua exigindo confirmação.

### 🎛️🎨 K0 — Stream Deck Ultra-Customizável (Grades Livres, Cores HEX, Ícones/GIFs e Widgets Vivos)
- [x] **K0.1: Customização Visual e Estética dos Botões:**
  - **Paleta Livre:** Seletor de cores completo (Color Picker HEX/RGB com opacidade) substituindo a paleta fixa limitada.
  - **Ícones e Mídias:** Biblioteca expandida de ícones categorizados, upload de PNG/SVG e suporte a GIFs animados como ícones de botões.
  - **Tipografia e Rótulos:** Ajuste do tamanho da fonte (8px a 18px), alinhamento vertical/horizontal do texto e opção de ocultar o rótulo para botões minimalistas (apenas ícone).
  - **Bordas e Feedback:** Ajuste de raio dos cantos (arredondado, quadrado, circular/pílula), espessura/cor de borda e intensidade do feedback tátil (haptic feedback ao tocar).
- [x] **K0.2: Grades e Layouts Dinâmicos por Perfil:**
  - **Dimensões Livres da Grade:** Configuração do número de colunas (2 a 8) e linhas (2 a 6) por perfil (ex: 2×2 para dock/veicular, 3×4, 4×4, 5×3, 6×4), com redimensionamento fluido em retrato e paisagem.
  - **Personalização de Fundo:** Imagem de fundo ou gradiente personalizado para o painel de cada perfil.
  - **Espaçamento Configurável:** Controle de espaçamento entre botões (gap de 4px a 24px) e margens da tela.
- [x] **K0.3: Widgets Dinâmicos e Criação Direta no Celular:**
  - **Widgets Vivos de Telemetria:** Botões dinâmicos com medidores em tempo real de CPU%, RAM%, GPU%, temperatura ou relógio digital direto na grade do Deck.
  - **Mídia em Tempo Real:** Botão com exibição da faixa e artista em reprodução no Windows (Spotify / Windows Media) com botões de controle integrados.
  - **Atalhos Criados pelo Celular:** Desbloqueio da criação de teclas de atalho (`hotkeys`) e apps do catálogo autorizados diretamente no celular sem exigir o configurador web do PC.
  - **Evidência (2026-11-02):** `dotnet test` 403/403 PASS e `flutter test` 258/258 PASS. Atalho remoto só é gravado se a tecla passa em `KeyAllowlist`. Sequência SendKeys livre, abrir programa por caminho, ativar janela e HTTP continuam restritos ao configurador do PC. Aceite visual no aparelho: `NOT_RUN`.

### 🌡️💻 T1 — Sensores de Temperatura Resilientes & Exibição Ampliada
- [x] **T1.1: Fallback de Sensores sem Privilégios de Administrador (Backend .NET):**
  - **Problema:** A leitura atual via `HardwareSensorProvider.cs` depende de `LibreHardwareMonitor`. Em sessões padrão de usuário sem elevação UAC (instalação não-admin), a leitura de sensores de CPU (MSRs) pode ser bloqueada pelo driver do Windows, retornando `null` ("N/D") no app móvel.
  - **Entrega técnica:**
    - Implementar cadeia de fallbacks resilientes: (1) LibreHardwareMonitor; (2) WMI ACPI (`root\wmi:MSAcpi_ThermalZoneTemperature`); (3) NVAPI nativa para GPUs NVIDIA e AMD ADL para GPUs Radeon sem exigir elevação UAC.
    - Amostragem otimizada a cada 3s para evitar consumo de CPU no host.
- [x] **T1.2: Visibilidade Aprimorada e Destaque da Temperatura no App (Flutter):**
  - **Problema:** As temperaturas ficam restritas a um badge reduzido nos cards individuais de CPU/GPU da `StatusPage` e no Modo Dock, não aparecendo no painel resumo "Meus 2 PCs" nem em botões configuráveis da grade do Stream Deck.
  - **Entrega técnica:**
    - Exibir temperaturas de CPU e GPU no card de visão geral "Meus 2 PCs" ao lado do uso de CPU e RAM.
    - Indicador térmico com gradiente visual (verde <=60°C, âmbar <=75°C, vermelho crítico >80°C).
    - Widget de temperatura configurável diretamente nos botões do Stream Deck (integrado à fase `K0`).
    - Notificação/banner preventivo caso a temperatura atinja níveis críticos (>85°C).
  - **Evidência (2026-11-02):** `dotnet test` 405/405 PASS e `flutter test` 259/259 PASS. A zona ACPI é a temperatura da placa, não o núcleo. NVAPI e ADL só respondem se o driver NVIDIA ou AMD estiver instalado. Confirmação do número numa máquina física: `NOT_RUN`.

### 📡 D0 — Descoberta e Reconexão
- [x] **D0.1:** O Bridge anuncia `_command._tcp` via mDNS (nome amigável + porta), desativável na configuração (`appsettings.json` / `EnableMdns`), incluindo registros PTR, SRV, TXT (sanitizado com `name`, `id`, `port`, `controlPort`, `certPin`, sem tokens/segredos) e A; pacote goodbye TTL=0 no encerramento. Testes unitários com 373/373 PASS.
- [x] **D0.2:** O app lista os PCs descobertos para parear/usar na `ConfigPage` e atualiza o endereço dos PCs já pareados quando o IP muda (`PcStore.updateIpIfIdentityMatches`), sempre validando a identidade/certificado do Bridge (`controlCertificatePin`), nunca só o nome.
- [x] **D0.3:** Fallback LAN → Tailscale → último endereço conhecido, com deduplicação de candidatos e validação de conectividade via `ReconnectionFallbackService`. Suíte Flutter 240/240 PASS. Próxima fase: T0 (Transferências Retomáveis).

### 📦 T0 — Transferências Retomáveis
- [x] **T0.1:** Upload e download em blocos (4 MiB) com `offset`, mantendo o limite (100 MiB), a blocklist e a proteção anti-traversal atuais.
- [x] **T0.2:** Retomar após queda de rede ou do app; SHA-256 final obrigatório; partes órfãs (`.part`/`.tmp`) expiram (24h) e são limpas no startup e sob demanda.
- [x] **T0.3:** Testes: interrupção no meio, bloco corrompido, detecção de gap (`CHUNK_OFFSET_GAP`), retomada com hash divergente → rejeitar e limpar temporários. Testes automatizados verdes (6 novos testes .NET em `TransferServiceTests.cs`, 5 testes Flutter em `resumable_transfer_test.dart`).

### 🚀 I0 — Instalador Windows próprio e Distribuição
**Direção atualizada a pedido (2026-10-20 e 2026-10-24):** priorizar instalação direta por `Command-Setup.exe`; zip portátil e script assistido são alternativas. Reutilizar o Velopack já presente, sem novo framework de instalação. O proprietário antecipou I0.3a/b para instalar a Bridge nos PCs antes do checkpoint físico M1. O piloto privado atual não importa automaticamente perfis/credenciais antigos e não consulta atualizações remotas; a migração segura solicitada será feita em I0.3c, após T0 e antes da homologação I0.6, mantendo a ordem aprovada. I0.3d mantém o manifesto e o script de instalação assistida. Atualizações remotas continuam desativadas até existir um feed Command aprovado. A intenção D-v1.5-11 de publicação pública permanece condicionada a I0.7; disponibilizar este piloto no repositório privado não torna o repositório público.

**Achado verificado:** `.github/workflows/release.yml` usa `DroidDeckPC`, título DroidDeck e artefato DroidDeck-Setup.exe; `DroidDeck/Lib/AppUpdater.cs` aponta para `ggfto/DroidDeck`. Corrigir identidade e origem antes de distribuir para não instalar/atualizar o produto errado.
- [ ] **I0.1 (gate obrigatório antes de publicar):** varredura de segredos em **todo o histórico Git** (gitleaks/trufflehog): chaves de assinatura, `key.properties`, `.env`, tokens, API keys, IPs/hostnames privados e evidências com dados pessoais. Se encontrar algo, rotacionar o segredo e limpar o histórico **antes** de tornar o repo público. Revisar `docs/evidence/` e `docs/assets/` (screenshots reais).
  - **Varredura do histórico (2026-11-03):** Gitleaks 8.30.1, 268 commits, 9 correspondências genéricas, todas em fixtures/testes (`secretKey="api-secret-key-12345"`, `AIzaSyTest123`, hash Tuya de teste, `validToken`/`password` de QR) ou na constante legada `oneSignalApiKey` do upstream (commit `191b68c`, formato UUID, ou seja, App ID público do OneSignal). Nenhum `key.properties`, `.jks`, `.keystore`, `.env`, `.pfx` ou `.pem` em qualquer commit. Sem hostnames `.ts.net`. Faltam: revisão visual das 70 imagens em `docs/evidence/` e `docs/assets/` e decisão sobre IPs de LAN (`192.168.68.x`) nos documentos. Item segue aberto.
- [x] **I0.2:** Conferir licenças por componente: raiz DroidDeck Apache-2.0 e `app/LICENSE` GPL-3.0. Preservar avisos/atribuições e preparar o código-fonte correspondente aos binários sujeitos a essas obrigações. Documentação detalhada formalizada em `docs/LICENSES.md`; instalador embute ambas as licenças em `publish/LICENSE` e `publish/LICENSE-APP-GPL-3.0`.
- [x] **I0.3a:** Empacotar `Command-Setup.exe` com identidade Velopack própria e metadados Command, mantendo executável interno compatível. Atualizador consulta somente releases Command (`AppUpdater.cs`); corrigido `.github/workflows/release.yml` para gerar `Command.apk` em vez de `DroidDeck.apk`, além de `.releaserc.json` e `package.json` atualizados para a identidade Command.
- **Registro do piloto local (2026-10-24/25):** setup `1.1.0-local.20261024.x64` gerado com PackId `CommandPC`, runtime `win-x64`, web Flutter e Bridge .NET autocontidos; SHA-256 e manifesto conferidos. O proprietário confirmou a instalação e funcionamento nos dois PCs em 2026-10-25. Atualizador remoto desativado porque o feed Command permanece privado. Authenticode `NotSigned`; migração segura/coexistência, máquina limpa, atualização e desinstalação continuam pendentes. Uma tentativa anterior foi empacotada como x86 por falta de `--runtime`; ela está sinalizada como inválida e não deve ser instalada.
- **Registro das prereleases privadas (2026-10-24/25):** [Command Bridge 1.1.0 — Windows x64](https://github.com/playertwo1/Command/releases/tag/command-v1.1.0-local.20261024.x64) contém setup, SHA-256, manifesto e licenças Apache-2.0/GPL-3.0. O tag aponta para `f36351c`, já publicado na `main`; `sourceWorkingTreeDirty=true`, logo aquele binário inclui alterações locais que o código-fonte do tag não reproduz. O APK Android [Command v1.1.1 — Multi-PC (piloto M1)](https://github.com/playertwo1/Command/releases/tag/command-v1.1.1) contém o APK, guia e checksum; compilado no commit `2c9e7eb`, versionCode 12, assinatura compatível com 1.1.0. A correção 1.1.2 foi publicada em [prerelease privada](https://github.com/playertwo1/Command/releases/tag/command-v1.1.2); em 2026-10-25, o proprietário confirmou funcionamento nos dois PCs e aprovou o aceite visual de M1. M1 está fechado por esse aceite; não há logs separados de cada fluxo físico.
- **Pré-varredura de segredos (2026-10-24):** Gitleaks 8.30.1 percorreu 238 commits e encontrou oito correspondências genéricas de 8 caracteres em fixtures/testes e uma constante legada removida; a varredura do diff atual e do script/documentação não encontrou correspondências. O secret scanning do GitHub está desativado. Nenhuma credencial real foi confirmada; revisão de IPs/hostnames e evidências pessoais em todo o histórico permanece pendente, portanto I0.1 continua aberto para distribuição pública.
- [x] **I0.3b:** Instalação por usuário sem admin: atalho no menu Iniciar, tray, autostart opcional via `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` e QR temporário local. Firewall privado (`4787`, `4788`, `7573`) com diálogo explicativo e elevação legítima somente quando solicitada (`FirewallSetup.cs`), com recuperação caso negada. Sem bypass de UAC/SmartScreen, sem tokens embutidos. Documentado em `docs/INSTALL.md`.
- [x] **I0.3c — migração segura de dados legados (solicitada em 2026-10-25; após T0 e antes de I0.6):** migração implementada no backend .NET via `LegacyDataMigrationService` (`ILegacyDataMigrationService`). Escaneia e migra perfis, configurações e segredos de `%AppData%\DroidDeck` e `%LocalAppData%\DroidDeck` para `%AppData%\Command` e `%LocalAppData%\Command` somente sob consentimento explícito (`explicitConsent`), via CLI (`--check-migration` e `--migrate-legacy --confirm`) e no setup/menu da bandeja (`frmPrincipal.cs`). Segredos DPAPI decifrados com a entropia legada (`DroidDeck.SecretFile.v1`) e re-cifrados com a entropia Command (`Command.SecretFile.v1`), validados em memória antes da escrita e gravados atomicamente via `.tmp` e swap seguro. Resolução de colisão com prévia (`Skip`, `BackupAndOverwrite` com sufixo `.bak`, `Overwrite`), preservação estrita dos arquivos legados originais (sem deleção de fontes) e proteção contra vazamento de segredos em logs ou mensagens de erro. Suíte .NET completa com 390/390 PASS (11 novos testes em `LegacyDataMigrationTests.cs`).
- [x] **I0.3d:** Publicar manifesto de versão e SHA-256 junto ao instalador e zip portátil; documentar assinatura de código existente ou ausente. Preparar `install.ps1` que resolve uma release específica, valida integridade antes de executar e aborta em divergência (`CHECKSUM_MISMATCH`). Sem tokens de repositório privado no script/binário. Teste automatizado de detecção de divergência aprovado.
- [x] **I0.5:** Desinstalação pelo Windows nativa (Configurações / Painel de Controle) e script assistido `scripts/uninstall.ps1` (atalho `uninstall.ps1` na raiz): remove processos ativos, autostart e regras de firewall; preserva os dados de configuração por padrão (`%AppData%\Command` e `%LocalAppData%\Command`), com opção explícita para apagá-los (`-PurgeData`). Procedimento de recuperação de versão anterior e comportamento do SmartScreen documentados em `docs/INSTALL.md`.
- **Registro dos pacotes oficiais de release v1.5.0 (2026-10-26):**
  - Publicada no GitHub: [Command v1.5.0](https://github.com/playertwo1/Command/releases/tag/command-v1.5.0), tag `command-v1.5.0`.
  - `dist/command-installer/1.5.0-local.20261026.x64/Command-Setup.exe` (SHA-256: `522e1d66bbfba576c40f6792a713df7975794c0c1977ec54156b43901e0b6da6`).
  - `dist/command-bridge-v1.5.0-win-x64.zip` (SHA-256: `d6eb550a117d9b49532559199ec896e5da244c5e0da598f1b66e3447be114e4b`).
  - `dist/command-app-v1.5.0.apk` / `dist/Command.apk` (SHA-256: `643f3ee9c4d69f347cb21d3ca36c98421c7035a8d14aae6fbbca235416e00c30`).
  - Assinatura Android release v2 e alinhamento `zipalign -c -v 4` verificados com sucesso.
  - Testes automatizados consolidados: **637 PASS** (390 C# e 247 Flutter); `flutter analyze` exit 0.
  - Roteiro de homologação física e formulário de evidência estruturados em `docs/HOMOLOGACAO_V1.5.md` (e `docs/evidence/v1.5/H0_HOMOLOGACAO.md`).
- [ ] **I0.6:** Evidência na segunda máquina física limpa: instalar, abrir tray, parear, reiniciar, atualizar, simular download corrompido/falha de rede e desinstalar. Conferir preservação de dados, coexistência DroidDeck/Command, origem do updater. Não marcar PASS com base apenas na geração do setup. Roteiro pronto em `docs/evidence/v1.5/H0_HOMOLOGACAO.md` aguardando execução física.
- [ ] **I0.7:** Tornar o repositório público — **somente** após I0.1/I0.2 PASS e confirmação explícita do proprietário no momento da publicação.

### 📂 F1 — Pastas de Destino Nomeadas (`ATIVA`, aprovada pelo proprietário em 2026-11-03)
Decisões do proprietário (2026-11-03): sentido só **celular → PC**; pastas cadastradas **na tela do app do PC**; nome repetido **pergunta no celular**.
- [x] **F1.1 (contrato):** `DestinationFolder { id (guid), name, icon, path }` persistido em `%AppData%\Command\transfer_folders.json`. `GET /api/transfers/destinations` devolve só `id`, `name`, `icon` — **nunca o caminho**. Sem cadastro, `inbound` continua como destino padrão. **Feito (2026-11-03):** `DestinationFolderStore`; o id da pasta viaja no campo `rootId` já existente; 409 mantém o código `FILE_ALREADY_EXISTS`.
- [x] **F1.2 (backend):** `UploadChunk` e `Upload` aceitam `destinationId` além de `rootId=inbound`; resolvem o id para a pasta cadastrada e reaproveitam `IsPathWithinDirectory`, limite, hash e rejeição de symlink. Id desconhecido → 404. Nome repetido → 409 `NAME_CONFLICT`; o cliente reenvia com `conflictPolicy=replace|keepBoth`. Auditar no `JobHistoryService` sem registrar o caminho completo. **Evidência:** `DestinationFolderTests` 9 testes PASS (destino, id inválido, pasta removida, traversal, 3 políticas, blocos, limpeza só de `.part`, pastas de sistema, persistência); `dotnet test` 413/414, a falha é `ScreenStreamTests...WhenSessionLocked`, que passa isolada.
- [x] **F1.3 (PC):** seção "Pastas de destino" no app do PC: adicionar (seletor de pasta), renomear, escolher ícone, remover. Recusar raízes de sistema (`C:\`, `Windows`, `Program Files`) e a pasta de dados do Command. **Feito (2026-11-03):** item "Pastas de destino…" no menu do tray abre `frmDestinations` (adicionar com seletor de pasta, nome e ícone; remover). Renomear não entrou: remover e adicionar de novo. Aceite visual da janela: `NOT_RUN`.
- [x] **F1.4 (celular):** `share_receiver_sheet.dart` lista os destinos do PC-alvo (chips com ícone) e lembra o último usado por PC; diálogo de conflito (substituir / manter os dois / cancelar). **Feito (2026-11-03):** `listDestinations()` e `rootId`/`conflictPolicy` em `uploadInboundFile`; chips na sheet, último destino por PC em `SharedPreferences`; sem pastas cadastradas a sheet fica como antes. Flutter 260/260 PASS. Aceite visual no aparelho: `NOT_RUN`.
- [~] **F1.5 (testes) — parcial:** path traversal via `destinationId`, id inexistente, pasta removida no meio do envio, conflito com as três políticas, cadastro de raiz proibida, ausência do caminho em respostas e logs; widget test da sheet.
- **Fora do escopo:** descoberta/pareamento (já existem via D0/mDNS), navegar ou baixar dessas pastas, cadastro pelo celular.

### ✅ H0 — Homologação
- [x] **H0.1:** (confirmado pelo proprietário em 2026-11-03; evidência técnica detalhada não anexada) E2E com **2 máquinas físicas**, cada uma com Bridge. Segundo PC instalado pelo setup Command.
- [x] **H0.2:** (confirmado pelo proprietário em 2026-11-03; evidência técnica detalhada não anexada) Bateria: métricas paralelas, ação no PC certo, trackpad, texto livre, prévia ao vivo, mDNS após troca de IP, transferência interrompida e retomada.
- [x] **H0.3:** (confirmado pelo proprietário em 2026-11-03; evidência técnica detalhada não anexada) `dotnet test` + `flutter test` + `flutter analyze` verdes; evidências em `docs/evidence/v1.5/`; atualizar `STATE.md`. Testes antigos não substituem execução no build homologado.
- [x] **H0.4:** (confirmado pelo proprietário em 2026-11-03; evidência técnica detalhada não anexada) Evidenciar isolamento de PCs/credenciais, revogação durante streaming, ViewerOnly, UAC/bloqueio, logs sanitizados, anexos fora da raiz negados e transporte USB somente se incluído. Aceite humano da UI e do instalador separado do PASS técnico.

---

### 🔄 U0 — Sincronização seletiva com upstream (2026-10-20)
**Base e método:** fork originado em DroidDeck v1.9.1, com alterações próprias posteriores. Revisão de DroidDeck v1.10/v1.11 em 2026-10-20; pesquisas de terceiros não vinculam o produto atual. **Porte manual seletivo é o padrão**. Apenas `270a5a1`, `9608517`, `70f09f0` e `31c099a` passaram no `git apply --check` individual; isso não comprova cherry-pick de três vias, dependências ou execução. Matriz completa em `docs/UPSTREAM_IDEIAS_2026-10-20.md`, seção 4.

- [ ] **U0.0 — gate por porte:** conferir árvore suja, caminhos afetados, licença/URL/SHA/data em `research/UPSTREAM.md`, regras 3/4/6/8 e dependências. Inspecionar o diff selecionado; não reintroduzir endpoints genéricos, marca upstream nem telas removidas. Evidência nova de testes/build/UI pertence ao porte, não à revisão documental.

**Aproveitar (DroidDeck):**
- [x] **U0.1:** (2026-10-20, portado à mão — os arquivos do commit não existem no fork; `flutter test` 174 PASS. Aceite visual no aparelho `NOT_RUN`.) Correções de texto/estado de conexão honestos (`b4647a6`) — conversa direto com a pendência do M1 sobre o erro Dio exibido cru.
- [ ] **U0.2a — APROVEITAR / M (porte seletivo implementado em 2026-10-25; aceite visual do editor `PASS_HUMAN`; validação operacional pendente):** de `4c6ec61`, porte manual de botões com spans 1–4 e controle deslizante para dispositivo de saída/entrada selecionado, usando os endpoints e `MixerData` tipados já existentes. O slider limita 0–100, aplica debounce e confere o PC-alvo antes de enviar. Builds Flutter web/APK debug e Bridge Release passaram na árvore combinada; o APK abriu no AVD `Medium_Phone` Android 17/API 37 (1080×2400). Testes em `app/test/mixer_slider_deck_button_test.dart` cobrem seleção de entrada/saída, chamadas tipadas/PC-alvo, limites 0–100, semântica percentual e troca de PC: 3 PASS; suíte Flutter completa 184 PASS e análise direcionada do teste novo sem issues. Nesta retomada, build APK debug e build Bridge Release passaram; o SDK .NET 8.0.426 está instalado em `research/upstream/.tools/dotnet-8.0.426`. O AVD foi iniciado e encerrado, sem conexão à Bridge. A pausa autorizada da instalação em 4787 terminou com o listener reaparecendo; não houve tráfego de teste. A tentativa de iniciar a cópia isolada em 4788 com dados temporários foi bloqueada pela política local do executor; nenhum processo ou QR de teste foi criado e a pasta temporária vazia foi removida. O QR de `PairingInfo` anuncia 4787 fixo e o cadastro manual reutiliza a chave já pareada; ainda falta um fluxo de pareamento isolado executável. Arraste/acessibilidade com slider ativo, integração autenticada com Bridge isolada e alteração real de volume seguem `NOT_RUN`; nenhum volume foi alterado. Aceite visual do editor aprovado pelo proprietário em 2026-10-25 (`PASS_HUMAN`); U0.2a só fecha após resolver o pareamento isolado e validar operacionalmente no emulador. O endpoint de volume por processo e GIF do upstream foram excluídos até que limites e necessidade sejam avaliados. Proveniência e licenças em `research/UPSTREAM.md`.
- [ ] **U0.2b — AVALIAR / G / opcional:** `12736f6` por provider existente (OBS/Discord/Tuya/monitor/mídia), sem copiar `Dictionary<string,string>` como contrato genérico. Definir IDs autorizados, tipos, ranges e destinos cadastrados; novos providers ficam em v2. Não bloquear U0.2a.
- [ ] **U0.3 — AVALIAR / G / em D0:** porte de `4cd92f6` usa `adb reverse tcp:4787 tcp:4787`, ADB no PC e depuração autorizada no Android. Habilitação explícita; rotas/estado por PC; desligar remove somente encaminhamento próprio. Não confiar em loopback por falha ao descobrir PID; sem serial em logs. Download de platform-tools versionado/verificado, com extração limitada. Gate: cabo removido, PC errado, revogação, dois perfis, ADB ausente e reinício; comprovar em aparelho físico antes de oferecer como fallback. Sem viabilidade comprovada, adiar e manter LAN/Tailscale.
- [x] **U0.4a — APROVEITAR / P (2026-10-21, porte manual):** `47d15ff` — a chave do painel combina ID e posição (linha/coluna), separando botões salvos e células novas. `flutter test -j 1 --no-pub test/stream_deck_desktop_layout_test.dart` — 1 PASS (troca A→B e descarte de rascunho ao alternar entre células novas); `flutter build web --no-pub` — PASS. O navegador abriu a saída estática, mas sem Bridge/perfil/API para repetir o fluxo manualmente; não houve alteração visual de produto.
- [x] **U0.4b — APROVEITAR / M (porte manual, validação AVD e aceite visual em 2026-10-25):** SHAs completos e licença GPL-3.0 registrados em `research/UPSTREAM.md`. Aplicado reflow visual por ordem de leitura sem alterar posições persistidas, rail de navegação em paisagem compacta, ajuste de rótulos com mínimo de 12 px, anel circular e orientação traduzida para deck vazio, preservando tema/telemetria. Uma colisão do CTA vazio com o botão de tela cheia foi corrigida. `git diff --check` PASS; `flutter build apk --debug --no-pub` PASS (25,7 s); instalado no `Medium_Phone` Android 17/API 37, 1080×2400. Fixture local offline, sem pareamento físico: hierarquia/capturas confirmaram retrato, rail em paisagem, reflow de coordenadas fora da viewport, rótulos, medidores, CTA vazio e rolagem de grade com 48 botões até o final; posições originais preservadas no cache. Métricas reais e integração física `NOT_RUN`; testes automatizados `NOT_RUN`; aceite visual `PASS_HUMAN` em 2026-10-25.
- [x] **U0.4c — APROVEITAR / P (porte manual implementado e aceite visual em 2026-10-25):** porte seletivo do timer/contador `270a5a1`; texto operacional mantém mínimo de 12 px, sem encolhimento ilimitado. A decisão de layout considera o padding interno da moldura e oculta o ícone decorativo quando a célula não comporta os elementos; barra de progresso só aparece quando há altura suficiente. Atalhos de backup dense ficam alinhados à esquerda com altura mínima de 38 px, sem reativar backup/importação nem alterar disponibilidade. `flutter build apk --debug --no-pub`, `flutter build web --no-pub` e `git diff --check` PASS. AVD `Medium_Phone`, Android 17/API 37, 1080×2400, fixture offline: captura do contador 0/“Contador” não apresenta o overflow de 4,4 px identificado na primeira passagem; aceite visual do proprietário `PASS_HUMAN` em 2026-10-25. Countdown/pomodoro, visual dense desktop, testes automatizados e integração com PC real `NOT_RUN`. Evidência local ignorada pelo Git: `app/build/u04c-final-counter.png`. URL, SHA integral e GPL-3.0 em `research/UPSTREAM.md`.
- [x] **U0.4d — APROVEITAR / M (porte seletivo concluído em 2026-10-25):** de `d4d5375`, porte manual do guia do configurador, guarda de alterações não salvas ao trocar botão/perfil e desfazer ao limpar; o selo resume conexão em texto sem mostrar tooltip técnico. Mantidos o catálogo tipado e os limites local/remoto atuais; não foram portados gatilhos, scripts ou tema amarelo. De `949e731`, porte manual das mensagens existentes da bandeja e janela de pareamento, adaptadas ao Command e ao idioma UI do Windows em PT/EN/ES; o fluxo e a exibição local do código temporário não mudaram e não há logging novo. De `9608517`, aplicado apenas o patch do idioma da cidade da consulta atual, após `git apply --check`; endpoint/campos restantes preservados. Proveniência, datas, URLs, SHAs e licenças exatas em `research/UPSTREAM.md`. `flutter build web --no-pub` PASS (30,4 s); `flutter build apk --debug --no-pub` PASS (11,8 s); `dotnet build DroidDeck/DroidDeck.csproj -c Release` PASS (0 avisos/erros, após restore), com alterações concorrentes locais de Windows/instalador na árvore combinada. Revisão visual do build web: fixture estática sem Bridge/perfil mostra guia e estado de reconexão; runtime da bandeja/idiomas/pareamento e integração com PC `NOT_RUN`; aceite visual desta revisão estática aprovado pelo proprietário em 2026-10-25 (`PASS_HUMAN`). Runtime da bandeja/idiomas/pareamento e integração com PC `NOT_RUN`; testes automatizados `NOT_RUN`.
- [ ] **U0.5a — AVALIAR / M:** notificações Windows `2ee77b1`: adesão explícita, contagem sem conteúdo, negação/revogação de permissão e tela bloqueada. Auditar viabilidade do listener no pacote Windows escolhido.
- [ ] **U0.5b — AVALIAR / G:** uso IA `80ddefd` lê OAuth Claude e históricos Claude/Codex. Não ler dados pessoais durante a avaliação sem autorização; preferir fonte suportada e métricas agregadas, sem credenciais em logs. Não importar o leitor inteiro por conveniência.
- [ ] **U0.5c — AVALIAR / M:** condições `f94f5f7` como extensão opcional de M1.4; condição desconhecida/horário inválido deve negar, não retornar verdadeiro. Autorizar cada ação no momento da execução, preservar confirmações e resultado por PC.

**REJEITAR nesta proposta:** scripts `470fe1e` (R3); gatilhos `4079f67` como implementados (confirmações não garantidas); cliente web/iOS `e75169e` (novo escopo de autenticação); link público `b443b20` (site externo e parâmetros potencialmente privados); branding `0388f42`/`dd4d758` (marca Command). Isso não os aprova automaticamente para v2.

**Backlog v2, não ativo:** Elgato `6db2252` (G: IDs permitidos, limites de ZIP/imagem e caminhos), espanhol `70f09f0` (M: traduzir também telas próprias), integrações `31c099a`/`8689282` (G: avaliar separadamente credenciais, MQTT e automações). Cada entrada precisa de decisão específica antes da implementação.

## 4. Fora do escopo da v1.5
Ficam fora da v1.5: mais de 2 PCs simultâneos, streaming de alta taxa/áudio, controle sem sessão desbloqueada, clipboard automático, análise de prints por IA e app Wear OS.

## 5. Pendências
- M1: **DONE em 2026-10-25**, com confirmação humana de funcionamento geral nos dois PCs e aceite visual. Testes/build previamente registrados; não foram fornecidos logs detalhados dos fluxos físicos. U0.4b, U0.4c e U0.4d receberam aceite visual humano em 2026-10-25, com escopo de evidência individual registrado; U0.2a está adiada e pendente; próximo item ativo: R0.0. M0 também está registrado como DONE.
- U0.0: completar auditoria por arquivo antes de cada porte; apenas itens APROVEITAR entram na sequência. Itens AVALIAR precisam de conclusão documentada; ausência de decisão não significa aprovação.
- I0: fechar identidade/canal do updater, migração de dados e obrigações de distribuição; publicação, commit e push continuam exigindo pedido explícito.

## 6. Evidência e retomada por outro agente

Executar uma subfase por vez. Antes de alterar produção, ler STATE, este roadmap, DESIGN para UI e a linha correspondente da matriz upstream. Identificar arquivos existentes e dependências; não aplicar os commits em lote.

Ao encerrar, registrar: item/arquivos, SHA de origem, alterações concorrentes presentes, comandos realmente executados, resultado técnico, captura/ambiente e pendências. Usar `NOT_RUN` para teste/build/dispositivo não executado e `PENDING_HUMAN` para aceite visual. Os critérios de teste deste roadmap são trabalho futuro, não evidência produzida pela edição documental.

**Próxima execução concreta:** validar o pareamento de controle com Bridge isolada (HTTPS 4788, pin correto/incorreto, expiração/uso único do ticket, credencial segura e revogação) sob mecanismo de execução aceito pela política local; a Bridge instalada permanece fora do teste. Após essa validação, implementar R0.1 com rotas tipadas que exijam credencial e `FullControl`; `X-Device-Id` nunca prova identidade. U0.2a permanece pendente para validação posterior e não bloqueia R0. U0.2b/U0.3 e U0.5 continuam inativos; não iniciar USB ou publicação enquanto seus gates não forem alcançados.
