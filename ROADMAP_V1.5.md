# ROADMAP v1.5 — Command: Multi-PC Simultâneo, Controle Remoto, Aba Hermes e Conectividade sem Atrito

**Status:** base aprovada pelo proprietário em 2026-10-19; planejamento revisado em 2026-10-20/21 e reordenado em 2026-10-24 a pedido do proprietário. **M1 e U0.4b/U0.4c concluídos em 2026-10-25**, com confirmação funcional e aceite visual do proprietário. Fase ativa: **U0.4d**, porte seletivo de orientação/edição segura, textos locais de bandeja/pareamento e avaliação do clima. O piloto I0.3a/b ainda tem gates pendentes. Itens `AVALIAR` não autorizam implementação. Repositório continua privado; a distribuição pública continua dependente de I0.1, I0.2 e I0.7.
**Pré-requisito:** Release v1.1.0 (`command-v1.1.0` — 461 testes PASS)
**Checkpoint 2026-10-25:** proprietário confirmou instalação, funcionamento de todas as funções e alternância nos dois PCs; aceite visual aprovado. A correção publicada na prerelease privada `command-v1.1.2` (`7449fde`) restaura os dois perfis em paralelo, unifica a seleção e torna o painel reativo. 32 testes direcionados e build release PASS; assinatura/alinhamento verificados. M1 está concluído por confirmação humana funcional e visual; não foram fornecidos logs separados de cada fluxo físico.
**Meta Principal:** Manter **2 PCs conectados ao mesmo tempo** no app, adicionar **trackpad/teclado remoto com prévia ao vivo**, uma **aba Hermes** (chat, notificações, escolha de modelo e de esforço via Hermes-Relay) usando o mesmo pareamento do Command, **descoberta automática por mDNS** e **transferências retomáveis**.

**Ordem de entrega:** U0.4a (priorizado a pedido do proprietário em 2026-10-21; porte técnico concluído) → **I0.3a/b — instalador Command piloto, antecipado em 2026-10-24 para colocar a Bridge nos PCs de validação** → checkpoint M1 + aceite U0.1 → U0.4b/c/d → U0.2a (volume) → R0/R1/R2 → A0/A1/A2 → D0 (USB somente se U0.3 for viável) → T0 → concluir I0 → H0. A prerelease piloto foi publicada somente no repositório privado por pedido do proprietário; não ativa atualizações remotas e não substitui os gates I0.1/I0.2/I0.5/I0.6/I0.7 para distribuição pública. U0 é uma frente transversal, não um merge nem uma fase executada inteira de uma vez. U0.2b/U0.5 e backlog v2 não bloqueiam a entrega principal.

**Fontes da revisão:** [matriz completa e respostas](docs/UPSTREAM_IDEIAS_2026-10-20.md#4-revisao-consolidada-2026-10-20), [registro de proveniência](research/UPSTREAM.md). A revisão documental não atualiza resultados de testes nem fecha aceite visual.

---

## 1. Regras Inegociáveis da Onda v1.5

1. **Isolamento por PC:** cada PC conectado tem sua própria credencial, conexão SignalR, cache e histórico de jobs. Uma ação nunca vai para o PC errado; o PC-alvo fica sempre visível na UI antes de confirmar.
2. **Sem shell e sem bypass (Regras 3 e 5):** a entrada remota usa somente endpoints tipados (movimento, clique, rolagem, tecla da allowlist e texto com limite). Com a sessão bloqueada ou UAC ativo, o controle é recusado (`423 Locked`).
3. **Consentimento visível no PC:** enquanto houver controle remoto ativo, o Bridge mostra um indicador no tray, e o PC pode encerrar o controle a qualquer momento.
4. **Respeito ao P0 da v1.0:** dispositivos `ViewerOnly` não recebem controle de entrada; ações críticas continuam passando pelo guardião de PIN/biometria.
5. **mDNS só anuncia o mínimo:** nome amigável e porta. Nada de credencial, token ou catálogo. O pareamento continua explícito.
6. **Hermes continua opcional (Regra 2):** sem o Hermes-Relay, a aba mostra "Não configurado" e todo o resto do app funciona. Nenhuma ação do PC passa a depender de IA.
7. **Sem terminal/shell via Hermes (Regra 3):** o Command **não** expõe os canais `terminal` e "hands" do Hermes-Relay (CLI desktop, arquivos, busca). A aba usa só chat, notificações e configuração de modelo/esforço.
8. `NOT_RUN` não é `PASS`: cada fase fecha com teste automatizado e evidência atual no emulador ou no dispositivo.
9. **Portes seletivos (Regras 3/4/6/8):** registrar URL, SHA, data e licença por componente antes de copiar; preservar isolamento por PC, allowlist, credenciais fora de logs e limites de arquivos. Confirmação humana não autoriza criar execução arbitrária.
10. **Transporte não concede privilégio:** LAN, USB, Tailscale e loopback encaminhado exigem identidade e autorização válidas. Falha de identificação não pode tornar uma requisição confiável.

---

## 2. Decisões do proprietário (2026-10-19)

| ID | Decisão |
|----|---------|
| D-v1.5-01 | Limite **fixo de 2 PCs** conectados ao mesmo tempo. |
| D-v1.5-02 | A homologação H0 usa uma **segunda máquina física**. |
| D-v1.5-03 | A prévia ao vivo (R2) **entra** na v1.5. |
| D-v1.5-04 | A aba Hermes é um **cliente Flutter próprio** (não reaproveita o app Kotlin). |
| D-v1.5-05 | O Hermes-Relay **não está instalado**: a v1.5 inclui instalar e configurar o relay (fase A0). |
| D-v1.5-06 | Canais da aba: **chat em streaming, notificações e escolha de modelo e de esforço**. Voz e dashboard completo do agente ficam fora. |
| D-v1.5-07 | **Qualquer celular pareado** (inclusive `ViewerOnly`) pode trocar modelo e esforço do Hermes. |
| D-v1.5-08 | Hermes-Relay instalado **nos 2 PCs**: cada PC tem o seu Hermes. |
| D-v1.5-09 | O teclado remoto aceita **texto livre com limite** (~500 caracteres por envio, sem registrar o conteúdo em log). |
| D-v1.5-10 | mDNS (D0) e transferências retomáveis (T0) **continuam** na v1.5. |

---

## 3. Fases

| Fase | Área | Entrega | Dependência | Estado |
|------|------|---------|-------------|--------|
| **M0** | Mobile | Multi-PC simultâneo (2 conexões paralelas) | — | `DONE` |
| **M1** | Mobile | Painel combinado dos PCs + seletor de alvo | M0 | `IN_PROGRESS` |
| **R0** | Backend | API de entrada remota (mouse/teclado) | — | `TODO` |
| **R1** | Mobile | Trackpad + teclado virtual | R0, M0 | `TODO` |
| **R2** | Full | Prévia ao vivo (`ScreenStreamController`) com toque-para-clicar | R0 | `TODO` |
| **A0** | Pesquisa/Infra | Auditoria + Hermes Dashboard nos 2 PCs; plugin condicional | R2 na ordem de entrega | `TODO` |
| **A1** | Backend | Broker de pareamento Hermes no Bridge (reaproveita o login) | A0 | `TODO` |
| **A2** | Mobile | Aba Hermes: chat, notificações, modelo e esforço | A1, M0 | `TODO` |
| **D0** | Full | Descoberta mDNS + reconexão LAN ↔ Tailscale | M0 | `TODO` |
| **T0** | Full | Transferência retomável em blocos | — | `TODO` |
| **I0** | Infra | Command-Setup.exe, atualização própria e instalação assistida | T0; A0 para opção Hermes; I0.3a/b piloto antecipado antes do checkpoint M1 | `IN_PROGRESS` — somente instalador local piloto |
| **U0** | Full | Portes seletivos e requisitos de protocolo; sem merge global | Por subitem; ver seção U0 | `PARTIAL` — U0.1 e U0.4a técnicos registrados |
| **H0** | Full | Homologação E2E em 2 máquinas físicas (2ª instalada via I0) | todas | `TODO` |

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

**Retomada 2026-10-20:** M1.1/M1.2 implementados no app. Build atual instalado e aberto no `Pixel_9` (API 37, 1080×2424); o cartão combinado aparece com um único perfil salvo. Atividade Recente mostra o filtro e o estado indisponível contra a Bridge upstream. Serviços/Top Processos mostram mensagem amigável de HTTP 404; isso não comprova validação contra a Bridge Command. Dois perfis Command conectados, métricas comparativas e confirmações destrutivas continuam `NOT_RUN`; aceite humano `PENDING_HUMAN`.

**Retomada (2026-10-21):** a pedido do proprietário, U0.4a foi reordenado para antes do checkpoint final de M1 e recebeu porte técnico. O checkpoint M1 volta a ser a prioridade: validar M1.1–M1.4 com duas Bridges Command físicas, confirmar roteamento/isolamento e obter aceite humano antes de fechar M1 e avançar para U0.4b.

**Checkpoint M1:** após U0.4a, voltar às validações pendentes com duas Bridges Command: troca do alvo durante resposta pendente, isolamento após queda/revogação, nome do PC em confirmação destrutiva, atividade unificada/filtrada e execução isolada da rotina em cada perfil. O AVD anterior mostrou o estado indisponível da upstream DroidDeckPC, não a integração Command. Registrar captura sem credenciais/dados privados e obter aceite humano para M1.1/M1.2. Então fechar M1 e avançar para U0.4b.

**Progresso M1.3 (2026-10-20):** a página consolida até dois perfis, identifica cada linha por nome (e sufixo de ID quando nomes repetem), filtra e confirma limpeza informando os PCs. Falha parcial mantém o resultado individual por PC. Teste de widgets: 4 PASS. `flutter analyze` nos arquivos tocados reportou 3 diagnósticos `info` já existentes em `status_page.dart` (import redundante, API depreciada e concatenação); sem erros ou warnings. Build debug PASS, instalação e abertura no AVD Pixel_9 PASS. A revisão visual confirmou o filtro e o estado indisponível do feed sob a Bridge upstream; a causa específica não foi isolada. Agregação real entre dois PCs e aceite visual permanecem `NOT_RUN`/`PENDING_HUMAN`.

### 🖱️ R0 — API de Entrada Remota (Backend)
- [ ] **R0.1:** `RemoteInputController` (`/api/v1/input`): `move` (delta), `click` (botão), `scroll`, `key` (allowlist via `KeySequence`) e `text` (até 500 caracteres por envio). Reaproveitar `Lib/Input/KeyboardInput`; adicionar mouse via `SendInput`.
- [ ] **R0.2:** Sessão de controle com início e fim explícitos, timeout por inatividade (ex.: 60 s) e indicador no tray com botão "Encerrar controle".
- [ ] **R0.3:** Bloqueios: `ViewerOnly` → 403; sessão bloqueada/UAC → 423; texto acima do limite → 413; rate limit de eventos. A auditoria registra só início e fim de sessão, **nunca** o texto digitado.
- [ ] **R0.4:** Testes de integração para cada regra acima.

### ⌨️ R1 — Trackpad e Teclado (Mobile)
- [ ] **R1.1:** Tela Trackpad: arrastar = mover, toque = clique, dois dedos = rolagem/clique direito.
- [ ] **R1.2:** Teclado virtual para texto livre + linha de atalhos (Esc, Tab, Alt+Tab, Win, Ctrl+C/V).
- [ ] **R1.3:** Seletor de PC-alvo no topo (integra M0) e testes de widget.

### 📺 R2 — Prévia ao Vivo
- [ ] **R2.1:** Usar o `ScreenStreamController` existente com FPS e qualidade baixos e ajustáveis; encerrar o stream ao sair da tela. Verificar primeiro o que o controller já suporta.
- [ ] **R2.2:** Toque na prévia = clique na coordenada correspondente (mapeamento de escala; só o monitor principal).
- [ ] **R2.3:** Mesmas regras de sessão bloqueada e consentimento do R0.

### 🔎 A0 — Auditoria e Instalação do Hermes-Relay (Regra 8)
**Fato verificado (clone conferido em 2026-10-20):** `research/upstream/hermes-relay` permanece no SHA `62de6b51289d933a3f8d68841652b044130aa72f` (2026-10-07), licença **MIT** (Axiom Labs). O app upstream é Kotlin; a aba será Flutter próprio. A0 deve mapear Dashboard/Gateway como contrato primário e consultar `docs/relay-protocol.md` somente para extensões Relay necessárias; o `/ws` Relay não deve ser confundido com o WS Gateway.
- [ ] **A0.1:** Completar `research/UPSTREAM.md`: preservar o SHA anterior, obter e comparar `android-v1.19.0` / `server-v1.13.1` (`da782a8d74eb6631ea2f097b3cc69c6452ec33de`), atualizar apenas o clone de pesquisa e registrar arquivos efetivamente auditados. Notas de release não equivalem a auditoria integral. Criar ADR com cliente Flutter próprio, broker HTTP/WS e plugin opcional; fixar também versão/SHA do Hermes Agent compatível.
- [ ] **A0.2:** Mapear os canais usados (chat, notificações, modelos/esforço) e os excluídos (voz, terminal, bridge/hands, dashboard completo), além dos limites de rate do servidor.
- [ ] **A0.3:** **Hipótese a verificar:** a escolha de modelo vem de `GET /v1/models` (Hermes WebAPI). Confirmar se o protocolo expõe um parâmetro de **esforço/raciocínio**; se não expuser, registrar a limitação e propor a alternativa antes de A2.
- [ ] **A0.4:** Documentar em `docs/INSTALL_HERMES.md` e instalar Hermes Agent + Dashboard nos dois PCs, ouvindo somente em `127.0.0.1:9119`. Conferir suporte Windows e scripts fixados por versão/hash antes de executar. Verificar notificações upstream primeiro; plugin Relay somente se a capacidade necessária não existir. Se adotado, usar ingresso allowlisted do Dashboard sem abrir `8767` na LAN. Registrar início, parada, revogação e comportamento com Hermes desligado.
- [ ] **A0.5:** Comparar com o `HermesController` atual (v0.4): o que a aba substitui e o que continua.

**Caminho mais fácil (pesquisado em 2026-10-19 no clone local):**
- O **Hermes-Relay CLI** (`desktop/`, instalado com `install.ps1`) é um **cliente**: ele dá ao agente "mãos" no PC (terminal, PowerShell, arquivos). Isso conflita com a Regra 3, e ele não é o servidor de chat. **Não usar.**
- O app oficial usa **Hermes Dashboard/Gateway vanilla** para chat, sessões e Manage. A0 deve conferir o instalador Windows e sua versão atual, baixá-lo para revisão e fixar o hash; não executar conteúdo remoto diretamente. Iniciar Dashboard somente em loopback; credenciais locais nunca entram em evidências.
- O **plugin Relay** é opcional. Android 1.15 documenta avisos comuns upstream; A0.2 deve distinguir esses avisos de Notification Companion/entrega offline antes de declarar o plugin necessário.
- **Decisão proposta:** A0.4 instala o Hermes vanilla + Dashboard nos 2 PCs. O plugin Relay só entra se as notificações exigirem. Antes de executar o `install.ps1` remoto, baixá-lo, ler e fixar o hash (Regra 8).

### 🔐 A1 — Broker de Login (reaproveitar o login)
**Contrato de planejamento revisado:** celular autenticado no Command; Bridge guarda as credenciais do Dashboard com DPAPI e mantém sessões upstream separadas por dispositivo Command e PC. HTTP para consultas/configuração, WS para streaming. O Bridge obtém um novo ticket de uso único a cada conexão WS ao Gateway; preserva Host/Origin/IP e não registra tickets. O Dashboard permanece em loopback. Rotas do plugin, se necessário, serão confirmadas em A0; não presumir que a API Relay substitui a autenticação Dashboard.
- [ ] **A1.1:** `HermesRelayController` (`/api/v1/hermes-relay`): status sem segredos e contratos explícitos de chat/modelos/esforço; broker HTTP + WS autenticado, sem aceitar URL/path/canal arbitrário. Credenciais, cookies e tickets upstream nunca chegam ao celular. Contrato WS incompleto, replay ou origem inválida devem negar acesso.
- [ ] **A1.2:** Qualquer celular pareado pode se conectar ao Hermes (D-v1.5-07). Auditar o evento sem registrar o código nem o token.
- [ ] **A1.3:** Manter tokens/sessões Hermes somente no Bridge, vinculados ao dispositivo Command, PC e identidade upstream exata. Listar, encurtar e revogar sem renovar silenciosamente; revogação Command fecha conexões e invalida a sessão associada. Proibir fallback por nome quando ID exato estiver ausente, duplicado ou conflitante. Convite/código temporário só no fluxo local autorizado do PC.
- [ ] **A1.4:** Evidência: Hermes ausente/offline; ticket expirado/reutilizado; Host/Origin/IP inválidos; sessão revogada; dois PCs com perfis homônimos; troca de alvo durante resposta; nenhum segredo/caminho privado em logs. Verificar separadamente roles Command e autorização Dashboard/Relay.

### 💬 A2 — Aba Hermes no App
- [ ] **A2.1:** Aba **Hermes** na navegação principal, seguindo DESIGN/Amethyst. Quando o Dashboard estiver configurado via broker, substituir o card passivo; plugin ausente não impede chat upstream. Separar estados de Dashboard e extensões opcionais.
- [ ] **A2.2:** Chat em streaming pelo broker, com estados offline/não configurado/sessão expirada e transcript/rascunho preservados por PC/conversa. Histórico com janela recente de até 500 mensagens, retry em páginas menores, limites agregados de bytes/memória e erro explícito para mensagem grande demais. Recuperar turno silencioso pelo estado autoritativo sem Stop, reenvio automático ou duplicação. Não mudar para Direct API silenciosamente.
- [ ] **A2.3:** Carregar modelos ao abrir o seletor, antes da primeira mensagem; modelo/esforço por conversa e PC, liberados para qualquer celular pareado. Se A0.3 mostrar que esforço não é suportado, ocultar o controle (sem controle fictício).
- [ ] **A2.4:** Não lidas e notificações isoladas por PC/agente/conversa, com permissão explícita e privacidade de tela de bloqueio da v0.6. Não usar nome/conteúdo sensível na tela bloqueada; abrir sempre a conversa de origem.
- [ ] **A2.5:** Com 2 PCs conectados, a aba mostra com qual PC/Hermes você está falando e permite trocar.
- [ ] **A2.5b:** Clarify em lote, uma pergunta por vez, preservando progresso confirmado por ID de solicitação/PC/conversa. Aprovar somente operações tipadas permitidas; pedidos desconhecidos, shell ou sudo ficam indisponíveis com motivo, mesmo com confirmação humana. Coleta de segredos fica fora até existir contrato específico aprovado; nunca em logs. Reconexão não repete aprovação.
- [ ] **A2.5c:** Anexos, se incluídos no contrato A0, usam raízes autorizadas, limite atual de 100 MiB, validação de caminho/tipo e SHA-256. Mídia temporária com dono e expiração; limpeza não apaga arquivos do usuário. Download arbitrário de arquivos do host não é autorizado pelo chat.
- [ ] **A2.6:** Testes de widget e unidade com servidor WSS mockado.

### 📡 D0 — Descoberta e Reconexão
- [ ] **D0.1:** O Bridge anuncia `_command._tcp` via mDNS (nome amigável + porta), desativável na configuração.
- [ ] **D0.2:** O app lista os PCs descobertos para parear e atualiza o endereço dos PCs já pareados quando o IP muda, sempre validando a identidade/certificado do Bridge, nunca só o nome.
- [ ] **D0.3:** Fallback LAN → USB habilitado e homologado (U0.3) → Tailscale → último endereço conhecido, sem repetir candidato, sempre por PC e identidade validada. Sem USB aprovado, seguir LAN → Tailscale. `:10443` é referência de topologia Hermes, não porta obrigatória do Bridge nem autorização para expor Dashboard.

### 📦 T0 — Transferências Retomáveis
- [ ] **T0.1:** Upload e download em blocos (ex.: 4 MiB) com `offset`, mantendo o limite, a blocklist e a proteção anti-traversal atuais.
- [ ] **T0.2:** Retomar após queda de rede ou do app; SHA-256 final obrigatório; partes órfãs expiram e são limpas no startup.
- [ ] **T0.3:** Testes: interrupção no meio, bloco corrompido, retomada com hash divergente → rejeitar.

### 🚀 I0 — Instalador Windows próprio e Distribuição
**Direção atualizada a pedido (2026-10-20 e 2026-10-24):** priorizar instalação direta por `Command-Setup.exe`; zip portátil e script assistido são alternativas. Reutilizar o Velopack já presente, sem novo framework de instalação. O proprietário antecipou I0.3a/b para instalar a Bridge nos PCs antes do checkpoint físico M1. Foi criada uma prerelease privada do piloto em 2026-10-24; não há importação automática de perfis/credenciais nem atualização remota até existir um feed Command aprovado. A intenção D-v1.5-11 de publicação pública permanece condicionada a I0.7; disponibilizar este piloto no repositório privado não torna o repositório público.

**Achado verificado:** `.github/workflows/release.yml` usa `DroidDeckPC`, título DroidDeck e artefato DroidDeck-Setup.exe; `DroidDeck/Lib/AppUpdater.cs` aponta para `ggfto/DroidDeck`. Corrigir identidade e origem antes de distribuir para não instalar/atualizar o produto errado.
- [ ] **I0.1 (gate obrigatório antes de publicar):** varredura de segredos em **todo o histórico Git** (gitleaks/trufflehog): chaves de assinatura, `key.properties`, `.env`, tokens, API keys, IPs/hostnames privados e evidências com dados pessoais. Se encontrar algo, rotacionar o segredo e limpar o histórico **antes** de tornar o repo público. Revisar `docs/evidence/` e `docs/assets/` (screenshots reais).
- [ ] **I0.2:** Conferir licenças por componente: raiz DroidDeck Apache-2.0, `app/LICENSE` GPL-3.0, Hermes-Relay MIT. Preservar avisos/atribuições e preparar o código-fonte correspondente aos binários sujeitos a essas obrigações. Resolver distribuição antes de liberar artefatos, sem assumir que todo o fork é Apache.
- [ ] **I0.3a:** Empacotar `Command-Setup.exe` com identidade Velopack própria e metadados Command, mantendo executável interno compatível. Atualizador consulta somente releases Command; definir tag/canal e impedir fallback para upstream. Auditar caminhos e migração dos dados antes de renomear diretórios/packId; preservar instalação DroidDeck independente e credenciais DPAPI do Command.
- **Registro do piloto local (2026-10-24):** setup `1.1.0-local.20261024.x64` gerado com PackId `CommandPC`, runtime `win-x64`, web Flutter e Bridge .NET autocontidos; SHA-256 e manifesto conferidos. Atualizador remoto desativado porque o feed Command permanece privado. Authenticode `NotSigned`; instalação em PC físico e migração/coexistência continuam pendentes. Uma tentativa anterior foi empacotada como x86 por falta de `--runtime`; ela está sinalizada como inválida e não deve ser instalada.
- **Registro das prereleases privadas (2026-10-24/25):** [Command Bridge 1.1.0 — Windows x64](https://github.com/playertwo1/Command/releases/tag/command-v1.1.0-local.20261024.x64) contém setup, SHA-256, manifesto e licenças Apache-2.0/GPL-3.0. O tag aponta para `f36351c`, já publicado na `main`; `sourceWorkingTreeDirty=true`, logo aquele binário inclui alterações locais que o código-fonte do tag não reproduz. O APK Android [Command v1.1.1 — Multi-PC (piloto M1)](https://github.com/playertwo1/Command/releases/tag/command-v1.1.1) contém o APK, guia e checksum; compilado no commit `2c9e7eb`, versionCode 12, assinatura compatível com 1.1.0. A correção 1.1.2 foi publicada em [prerelease privada](https://github.com/playertwo1/Command/releases/tag/command-v1.1.2); em 2026-10-25, o proprietário confirmou que está 100% funcional nos dois PCs e aprovou o aceite visual de M1. A validação física e visual da correção está aceita; as validações conectadas restantes de M1 continuam pendentes.
- **Pré-varredura de segredos (2026-10-24):** Gitleaks 8.30.1 percorreu 238 commits e encontrou oito correspondências genéricas de 8 caracteres em fixtures/testes e uma constante legada removida; a varredura do diff atual e do script/documentação não encontrou correspondências. O secret scanning do GitHub está desativado. Nenhuma credencial real foi confirmada; revisão de IPs/hostnames e evidências pessoais em todo o histórico permanece pendente, portanto I0.1 continua aberto para distribuição pública.
- [ ] **I0.3b:** Instalação por usuário sem admin: atalho, tray, autostart opcional e QR temporário local. Firewall privado exige consentimento e elevação legítima quando necessária, com recuperação clara se negada. Instalador não contorna UAC/SmartScreen nem inclui tokens, chaves ou dados pessoais.
- [ ] **I0.3c:** Publicar manifesto de versão e SHA-256 junto ao instalador e zip portátil; documentar assinatura de código existente ou ausente. Preparar `install.ps1` que resolve uma release específica, valida integridade antes de executar e aborta em divergência. Não colocar token de repositório privado no script/binário; distribuição privada ou pública será definida em I0.7.
- [ ] **I0.4:** Etapa opcional "Instalar Hermes? [s/N]": roda o instalador oficial do Hermes (auditado e com hash fixado em A0.4), configura o Dashboard em `127.0.0.1:9119` e entrega as credenciais ao Bridge via DPAPI.
- [ ] **I0.5:** Desinstalação pelo Windows e alternativa assistida: remover só arquivos/atalhos/regras pertencentes ao Command; preservar dados por padrão e pedir opção explícita para apagá-los. Documentar falha de atualização e recuperação para versão anterior compatível. SmartScreen não é contornado; informar origem e situação da assinatura.
- [ ] **I0.6:** Evidência na segunda máquina física limpa: instalar, abrir tray, parear, reiniciar, atualizar, simular download corrompido/falha de rede e desinstalar. Conferir preservação de dados, coexistência DroidDeck/Command, origem do updater e funcionamento sem Hermes. Não marcar PASS com base apenas na geração do setup.
- [ ] **I0.7:** Tornar o repositório público — **somente** após I0.1/I0.2 PASS e confirmação explícita do proprietário no momento da publicação.

### ✅ H0 — Homologação
- [ ] **H0.1:** E2E com **2 máquinas físicas**, cada uma com Bridge e Hermes Dashboard; plugin somente quando exigido pelo contrato A0. Segundo PC instalado pelo setup Command.
- [ ] **H0.2:** Bateria: métricas paralelas, ação no PC certo, trackpad, texto livre, prévia ao vivo, pareamento Hermes sem segundo login, chat, notificações, troca de modelo/esforço, mDNS após troca de IP, transferência interrompida e retomada e o app inteiro funcionando com o relay desligado.
- [ ] **H0.3:** `dotnet test` + `flutter test` + `flutter analyze` verdes; evidências em `docs/evidence/v1.5/`; atualizar `STATE.md`. Testes antigos não substituem execução no build homologado.
- [ ] **H0.4:** Evidenciar isolamento de PCs/credenciais, revogação durante streaming, ViewerOnly, UAC/bloqueio, logs sanitizados, anexos fora da raiz negados e transporte USB somente se incluído. Aceite humano da UI e do instalador separado do PASS técnico.

---

### 🔄 U0 — Sincronização seletiva com upstream (2026-10-20)
**Base e método:** fork originado em DroidDeck v1.9.1, com alterações próprias posteriores. Revisão de v1.10/v1.11 e Hermes Android 1.15–1.19 / Plugin 1.11–1.13.1 em 2026-10-20. **Porte manual seletivo é o padrão**. Apenas `270a5a1`, `9608517`, `70f09f0` e `31c099a` passaram no `git apply --check` individual; isso não comprova cherry-pick de três vias, dependências ou execução. Matriz completa em `docs/UPSTREAM_IDEIAS_2026-10-20.md`, seção 4.

- [ ] **U0.0 — gate por porte:** conferir árvore suja, caminhos afetados, licença/URL/SHA/data em `research/UPSTREAM.md`, regras 3/4/6/8 e dependências. Inspecionar o diff selecionado; não reintroduzir endpoints genéricos, marca upstream nem telas removidas. Evidência nova de testes/build/UI pertence ao porte, não à revisão documental.

**Aproveitar (DroidDeck):**
- [x] **U0.1:** (2026-10-20, portado à mão — os arquivos do commit não existem no fork; `flutter test` 174 PASS. Aceite visual no aparelho `NOT_RUN`.) Correções de texto/estado de conexão honestos (`b4647a6`) — conversa direto com a pendência do M1 sobre o erro Dio exibido cru.
- [ ] **U0.2a — APROVEITAR / M / após U0.4:** volume e botões grandes (`4c6ec61`), reaproveitando Mixer e DTOs tipados. Validar range, permissões, PC-alvo e resposta real ao arrastar; GIF só com limite de bytes/dimensões e impacto de memória definido. Validar gesto e acessibilidade no AVD.
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

**Aproveitar (Hermes-Relay, referência de protocolo para A1/A2 — sem copiar código Kotlin):**
- Plugin 1.13.1: alvo por `device_id` exato, sem fallback por nome para outro PC → adotar a mesma regra no broker A1 com 2 PCs.
- Plugin 1.13.0: novos convites com rotas/certificado são descritos para CLI+UI; avaliar conceito em A1.3/D0.2 sem presumir compatibilidade Flutter. Plugin 1.13.1: cadeia PEM, exportação só do certificado folha e gestão de sessões são referências para A1.3.
- Android 1.15.0 ("upstream-first"): chat, anexos, arquivos do host e avisos usam os contratos autenticados do Dashboard/Gateway; o plugin Relay é só camada extra → confirma a decisão do A0 (Hermes vanilla + Dashboard, plugin opcional). Transcript, rascunho e sessão sobrevivem a logout/queda sem trocar de rota.
- Android 1.16.0: login do Dashboard **amarrado à sua conexão** ao trocar de gateway; a rota de um não invalida a sessão do outro; perfis homônimos em gateways diferentes não se confundem → requisito direto do A1.3/A2.5 com 2 PCs.
- Android 1.17.0: Clarify em lote respondido uma pergunta por vez, com progresso confirmado entre reconexões → entra no A2.5b.
- Plugin 1.11.0: ingresso Relay pela origem Dashboard com rotas allowlistadas e autenticações independentes; referência para A0.4. Listener `:10443` é opção da topologia Hermes, não substitui identidade/autorização Command nem justifica abrir novas portas.
- Plugin 1.11.3/1.12.0: WebSocket com ticket de uso único + checagem Host/Origin/IP; falha de auth não grava campos do cliente em log → mesmas regras no proxy do A1.
- **Não aproveitar:** CLI+UI 0.4.0-beta.6…10 (controle do computador via CUA, terminal, "mãos" no PC) — viola a Regra 3; Git workspace do plugin 1.11.0, voz Realtime/overlay e Bot Mode — fora do escopo da v1.5.
- Android 1.18.0: aproveitar modelos ao abrir seletor; cards sujeitos à allowlist A2.5b. Sudo/segredos não entram por confirmação genérica; consentimento HTTP não substitui transporte protegido. Android 1.18.1: login em segundo plano somente se houver futura decisão de OIDC móvel, desnecessário no broker atual.
- Android 1.19.0: histórico limitado, recuperação sem Stop, não lidas e notificações por conversa em A2.2/A2.4. Não assumir que screenshot está resolvido: issues upstream #743/#745 permaneciam citadas como abertas nas releases consultadas.

## 4. Fora do escopo da v1.5
Voz do Hermes, dashboard completo do agente (chaves, skills, perfis), mais de 2 PCs simultâneos, streaming de alta taxa/áudio, controle sem sessão desbloqueada, clipboard automático, análise de prints por IA e app Wear OS. Ficam para avaliação na v2.0.

## 5. Pendências
- M1: **DONE em 2026-10-25**, com confirmação humana de funcionamento geral nos dois PCs e aceite visual. Testes/build previamente registrados; não foram fornecidos logs detalhados dos fluxos físicos. U0.4b, U0.4c e U0.4d receberam aceite visual humano em 2026-10-25, com escopo de evidência individual registrado; próximo item ativo: U0.2a. M0 também está registrado como DONE.
- U0.0: completar auditoria por arquivo antes de cada porte; apenas itens APROVEITAR entram na sequência. Itens AVALIAR precisam de conclusão documentada; ausência de decisão não significa aprovação.
- A0.1: atualizar e auditar clone Hermes; o novo SHA já está registrado como referência de release, não como código integralmente auditado.
- Resultado de A0.3 (suporte a esforço) e de A0.4 (instalação no Windows) pode exigir ajustar A2 antes de implementá-la.
- I0: fechar identidade/canal do updater, migração de dados e obrigações de distribuição; publicação, commit e push continuam exigindo pedido explícito.

## 6. Evidência e retomada por outro agente

Executar uma subfase por vez. Antes de alterar produção, ler STATE, este roadmap, DESIGN para UI e a linha correspondente da matriz upstream. Identificar arquivos existentes e dependências; não aplicar os commits em lote.

Ao encerrar, registrar: item/arquivos, SHA de origem, alterações concorrentes presentes, comandos realmente executados, resultado técnico, captura/ambiente e pendências. Usar `NOT_RUN` para teste/build/dispositivo não executado e `PENDING_HUMAN` para aceite visual. Os critérios de teste deste roadmap são trabalho futuro, não evidência produzida pela edição documental.

**Próxima execução concreta:** iniciar U0.2a após U0.4d: auditar por arquivo o diff `4c6ec61`, confirmar URL/licença/SHA em `research/UPSTREAM.md`, validar o contrato existente de volume e ações tipadas e só então portar mixer/controles grandes. Definir ranges, PC-alvo, permissões e evidência visual de gesto/acessibilidade antes de ampliar escopo. U0.2b/U0.3 e U0.5 continuam inativos; não iniciar instalação Hermes, USB ou publicação enquanto suas fases/gates não forem alcançados.
