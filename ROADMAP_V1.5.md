# ROADMAP v1.5 — Command: Multi-PC Simultâneo, Controle Remoto, Aba Hermes e Conectividade sem Atrito

**Status:** APROVADO pelo proprietário em 2026-10-19 — em execução (M0). Repositório continua privado até I0.7.
**Pré-requisito:** Release v1.1.0 (`command-v1.1.0` — 461 testes PASS)
**Meta Principal:** Manter **2 PCs conectados ao mesmo tempo** no app, adicionar **trackpad/teclado remoto com prévia ao vivo**, uma **aba Hermes** (chat, notificações, escolha de modelo e de esforço via Hermes-Relay) usando o mesmo pareamento do Command, **descoberta automática por mDNS** e **transferências retomáveis**.

**Ordem de entrega:** Multi-PC (M) → Controle remoto (R) → Hermes (A) → Descoberta (D) → Transferências (T) → Homologação (H).

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
| **M0** | Mobile | Multi-PC simultâneo (2 conexões paralelas) | — | `IN_PROGRESS` |
| **M1** | Mobile | Painel combinado dos PCs + seletor de alvo | M0 | `TODO` |
| **R0** | Backend | API de entrada remota (mouse/teclado) | — | `TODO` |
| **R1** | Mobile | Trackpad + teclado virtual | R0, M0 | `TODO` |
| **R2** | Full | Prévia ao vivo (`ScreenStreamController`) com toque-para-clicar | R0 | `TODO` |
| **A0** | Pesquisa/Infra | Auditoria + instalação do Hermes-Relay nos 2 PCs | — | `TODO` |
| **A1** | Backend | Broker de pareamento Hermes no Bridge (reaproveita o login) | A0 | `TODO` |
| **A2** | Mobile | Aba Hermes: chat, notificações, modelo e esforço | A1, M0 | `TODO` |
| **D0** | Full | Descoberta mDNS + reconexão LAN ↔ Tailscale | M0 | `TODO` |
| **T0** | Full | Transferência retomável em blocos | — | `TODO` |
| **I0** | Infra | Instalador de 1 comando (`irm … \| iex`) + repositório público | T0 | `TODO` |
| **H0** | Full | Homologação E2E em 2 máquinas físicas (2ª instalada via I0) | todas | `TODO` |

### 🖥️🖥️ M0 — Multi-PC Simultâneo
**Hoje (v0.2 S7):** o `PcProfileManager` salva vários PCs, mas só **um** fica ativo por vez (troca rápida).
- [x] **M0.1:** Trocar o cliente ativo único por um registro de conexões por `pcId` (um `BridgeClient` + hub SignalR por PC), cada uma com ciclo de vida independente.
- [ ] **M0.2:** Estado por PC: online/offline/revogado, `last_seen` e métricas próprias. A queda de um PC não afeta o outro.
- [ ] **M0.3:** Limite **fixo de 2** conexões ativas. Os outros perfis salvos continuam disponíveis para troca. Em segundo plano, só polling econômico, sem WebSocket permanente (regra da v0.6).
- [x] **M0.4:** Testes: dois PCs mockados, falha de um isolada, revogação de um sem derrubar o outro, ação roteada ao `pcId` correto e recusa de uma 3ª conexão.

### 📊 M1 — Painel Combinado
- [ ] **M1.1:** Visão "Meus 2 PCs" com cartões lado a lado (CPU/RAM/estado), indicando qual PC está offline.
- [ ] **M1.2:** Cada ação, rotina e transferência mostra e exige o **PC-alvo** de forma explícita; confirmações destrutivas exibem o nome do PC.
- [ ] **M1.3:** Atividade recente unificada, filtrável por PC.
- [ ] **M1.4:** (Opcional) Rotina "nos dois": a mesma ação da allowlist nos 2 PCs, com resultado por PC (sem sucesso agregado falso).

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
**Fato verificado (2026-10-19):** clone local em `research/upstream/hermes-relay`, SHA `62de6b51289d933a3f8d68841652b044130aa72f` (2026-10-07), licença **MIT** (Axiom Labs). O app upstream é **Kotlin nativo**; a aba será um **cliente Flutter novo**, escrito contra o protocolo documentado (`docs/relay-protocol.md`: WSS `/ws`, envelopes por canal).
- [ ] **A0.1:** Registrar URL, SHA, data e licença em `research/UPSTREAM.md`. Criar a ADR `docs/adr/ADR-00x-hermes-relay.md` com a decisão D-v1.5-04.
- [ ] **A0.2:** Mapear os canais usados (chat, notificações, modelos/esforço) e os excluídos (voz, terminal, bridge/hands, dashboard completo), além dos limites de rate do servidor.
- [ ] **A0.3:** **Hipótese a verificar:** a escolha de modelo vem de `GET /v1/models` (Hermes WebAPI). Confirmar se o protocolo expõe um parâmetro de **esforço/raciocínio**; se não expuser, registrar a limitação e propor a alternativa antes de A2.
- [ ] **A0.4:** Documentar e executar a instalação do `hermes-agent` + plugin Hermes-Relay **nos 2 PCs**, em `docs/INSTALL_HERMES.md`: dependências, porta 8767, firewall privado e como desligar. Revisar os scripts `install.sh`/`uninstall.sh` antes de executar qualquer um, e confirmar se existe caminho oficial para Windows.
- [ ] **A0.5:** Comparar com o `HermesController` atual (v0.4): o que a aba substitui e o que continua.

**Caminho mais fácil (pesquisado em 2026-10-19 no clone local):**
- O **Hermes-Relay CLI** (`desktop/`, instalado com `install.ps1`) é um **cliente**: ele dá ao agente "mãos" no PC (terminal, PowerShell, arquivos). Isso conflita com a Regra 3, e ele não é o servidor de chat. **Não usar.**
- O app oficial deles conversa, no caminho padrão, com o **Hermes Dashboard/Gateway vanilla** (`hermes dashboard`, porta 9119). Isso cobre chat, sessões e **Manage (modelos)** sem nenhum plugin. Há instalador oficial para Windows: `iex (irm https://hermes-agent.nousresearch.com/install.ps1)` → `hermes setup --portal` → `hermes dashboard --no-open --host 0.0.0.0 --port 9119`. O login é feito com usuário/senha (`HERMES_DASHBOARD_*` em `~/.hermes/.env`).
- O **plugin Relay** (porta 8767) é opcional e só é necessário para as **notificações**.
- **Decisão proposta:** A0.4 instala o Hermes vanilla + Dashboard nos 2 PCs. O plugin Relay só entra se as notificações exigirem. Antes de executar o `install.ps1` remoto, baixá-lo, ler e fixar o hash (Regra 8).

### 🔐 A1 — Broker de Login (reaproveitar o login)
**Proposta (revisada):** o celular já está autenticado no Bridge (API key DPAPI + roles da v1.0). O Bridge guarda as credenciais do Dashboard local protegidas por DPAPI e faz o login no Hermes do mesmo PC via loopback (`127.0.0.1:9119`), atuando como proxy autenticado do chat. Assim o usuário **não precisa fazer um segundo login**, e o Dashboard não precisa ficar exposto na LAN. Se as notificações exigirem o plugin Relay, o código de pareamento vem da rota loopback `/pairing/register`.
- [ ] **A1.1:** `HermesRelayController` (`/api/v1/hermes-relay`): `GET status` (instalado, online e versão, sem segredos) e as rotas de chat, modelos e esforço, todas repassadas ao Dashboard local via loopback, **somente** para dispositivos autenticados no Command. A senha do Dashboard nunca chega ao celular.
- [ ] **A1.2:** Qualquer celular pareado pode se conectar ao Hermes (D-v1.5-07). Auditar o evento sem registrar o código nem o token.
- [ ] **A1.3:** O app troca o código por um token de sessão do relay e guarda esse token no armazenamento seguro, **por PC** (cada PC tem o seu Hermes). Revogar o dispositivo no Command também descarta a sessão Hermes daquele PC.
- [ ] **A1.4:** Testes: relay ausente, relay offline, código expirado ou reutilizado, dispositivo revogado.

### 💬 A2 — Aba Hermes no App
- [ ] **A2.1:** Nova aba **Hermes** na navegação principal, seguindo o `DESIGN.md`/Amethyst Command. Quando o relay está disponível, ela substitui o card passivo "Not configured".
- [ ] **A2.2:** Chat em streaming via WSS, com reconexão, histórico da sessão e os estados offline, não configurado e sessão expirada.
- [ ] **A2.3:** Seletor de **modelo** e de **esforço** por conversa, liberado para qualquer celular pareado. Se A0.3 mostrar que o esforço não é suportado, o controle não aparece (sem controle fictício).
- [ ] **A2.4:** Notificações do agente no Android, respeitando a privacidade de tela de bloqueio da v0.6.
- [ ] **A2.5:** Com 2 PCs conectados, a aba mostra com qual PC/Hermes você está falando e permite trocar.
- [ ] **A2.6:** Testes de widget e unidade com servidor WSS mockado.

### 📡 D0 — Descoberta e Reconexão
- [ ] **D0.1:** O Bridge anuncia `_command._tcp` via mDNS (nome amigável + porta), desativável na configuração.
- [ ] **D0.2:** O app lista os PCs descobertos para parear e atualiza o endereço dos PCs já pareados quando o IP muda, sempre validando a identidade/certificado do Bridge, nunca só o nome.
- [ ] **D0.3:** Fallback ordenado LAN → Tailscale → último endereço conhecido, por PC.

### 📦 T0 — Transferências Retomáveis
- [ ] **T0.1:** Upload e download em blocos (ex.: 4 MiB) com `offset`, mantendo o limite, a blocklist e a proteção anti-traversal atuais.
- [ ] **T0.2:** Retomar após queda de rede ou do app; SHA-256 final obrigatório; partes órfãs expiram e são limpas no startup.
- [ ] **T0.3:** Testes: interrupção no meio, bloco corrompido, retomada com hash divergente → rejeitar.

### 🚀 I0 — Instalador de 1 Comando e Publicação do Repositório
**Decisão D-v1.5-11 (2026-10-19):** tornar o repositório público para permitir `irm https://raw.githubusercontent.com/playertwo1/Command/main/install.ps1 | iex`.
- [ ] **I0.1 (gate obrigatório antes de publicar):** varredura de segredos em **todo o histórico Git** (gitleaks/trufflehog): chaves de assinatura, `key.properties`, `.env`, tokens, API keys, IPs/hostnames privados e evidências com dados pessoais. Se encontrar algo, rotacionar o segredo e limpar o histórico **antes** de tornar o repo público. Revisar `docs/evidence/` e `docs/assets/` (screenshots reais).
- [ ] **I0.2:** Conferir as licenças: o upstream DroidDeck permite o fork público? Registrar em `LICENSE`/`NOTICE` a atribuição do DroidDeck e do Hermes-Relay (MIT).
- [ ] **I0.3:** `install.ps1` na raiz: baixa o zip da última Release + `SHA256SUMS`, confere o hash (aborta se divergir), extrai em `%LocalAppData%` sem admin, cria o atalho de inicialização, pede consentimento para a regra de firewall privada e abre o QR de pareamento. Se já existir o `Setup.exe` do Velopack (v1.0), apenas baixá-lo, verificá-lo e executá-lo.
- [ ] **I0.4:** Etapa opcional "Instalar Hermes? [s/N]": roda o instalador oficial do Hermes (auditado e com hash fixado em A0.4), configura o Dashboard em `127.0.0.1:9119` e entrega as credenciais ao Bridge via DPAPI.
- [ ] **I0.5:** Desinstalação via `install.ps1 -Uninstall`. SmartScreen: só exibir a instrução de `Unblock-File`, sem contorná-lo automaticamente.
- [ ] **I0.6:** Testar em uma máquina limpa (a 2ª máquina física do H0) e registrar a evidência.
- [ ] **I0.7:** Tornar o repositório público — **somente** após I0.1/I0.2 PASS e confirmação explícita do proprietário no momento da publicação.

### ✅ H0 — Homologação
- [ ] **H0.1:** E2E com **2 máquinas físicas**, cada uma com Bridge e Hermes-Relay, controladas pelo mesmo app ao mesmo tempo.
- [ ] **H0.2:** Bateria: métricas paralelas, ação no PC certo, trackpad, texto livre, prévia ao vivo, pareamento Hermes sem segundo login, chat, notificações, troca de modelo/esforço, mDNS após troca de IP, transferência interrompida e retomada e o app inteiro funcionando com o relay desligado.
- [ ] **H0.3:** `dotnet test` + `flutter test` + `flutter analyze` verdes; evidências em `docs/evidence/V1.5/`; atualizar `STATE.md`.

---

## 4. Fora do escopo da v1.5
Voz do Hermes, dashboard completo do agente (chaves, skills, perfis), mais de 2 PCs simultâneos, streaming de alta taxa/áudio, controle sem sessão desbloqueada, clipboard automático, análise de prints por IA e app Wear OS. Ficam para avaliação na v2.0.

## 5. Pendências
- Aprovação final do proprietário para iniciar M0.
- Resultado de A0.3 (suporte a esforço) e de A0.4 (instalação no Windows) pode exigir ajustar A2 antes de implementá-la.
