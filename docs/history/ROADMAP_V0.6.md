# ROADMAP v0.6 — Command: Mobilidade Expandida, Wake-on-LAN, Widgets e Acesso Imediato

**Status:** CONCLUÍDO (2026-10-18)  
**Pré-requisito:** Onda v0.5 (`v0.5.0`)  
**Meta Principal:** Permitir monitoramento e acionamento imediato do PC sem precisar abrir o aplicativo completo, entregando **Wake-on-LAN (Magic Packet UDP)** para ligar o PC remotamente na rede local, **Estado de Energia/Suspensão**, **Notificações Android de Saúde** e **Painel Compacto / Quick Tile**.

---

## 1. Regras Inegociáveis da Onda v0.6

1. **Segurança em Ações de Energia (Regra 3 & Regra 5):** Comandos de energia do PC (Suspender, Bloquear Estação) exigem confirmação explícita com contagem/modal de segurança no celular.
2. **Privacidade em Tela de Bloqueio / Widgets (Regra 4):** Widgets e notificações Android nunca exibem IPs completos, tokens, nomes de arquivos privados ou conteúdo de capturas de tela.
3. **Baixo Consumo de Bateria no Android:** Atualizações em segundo plano e widgets devem respeitar intervalos econômicos sem manter conexões WebSocket abertas permanentemente quando a tela do celular estiver apagada.

---

## 2. Estrutura de Fases e Subfases (v0.6)

### ⚡ Fase W0 — Wake-on-LAN (WoL) e Descoberta de MAC Address
**Objetivo:** Permitir que o celular ligue um PC pareado que esteja desligado ou em suspensão na mesma LAN via pacote mágico UDP.

- [x] **W0.1:** No Backend (`PowerControlService` / `GET /api/system/network-info`), incluir o endereço físico `MacAddress` da interface de rede principal e endereço de broadcast da sub-rede.
- [x] **W0.2:** No Mobile (`PowerControlCard` / `SavedPc`), suportar `macAddress` e endereço de broadcast (`255.255.255.255` / portas UDP `9` e `7`).
- [x] **W0.3:** Implementar `WakeOnLanService.dart` no Flutter capaz de montar o *Magic Packet* padrão IEEE (6 bytes `0xFF` + 16 repetições do MAC de 6 bytes = 102 bytes) e disparar via `RawDatagramSocket` UDP.
- [x] **W0.4:** Adicionar botão **"Ligar PC (Wake-on-LAN)"** no `PowerControlCard` da `StatusPage` com diálogo de confirmação/inserção de MAC Address.
- [x] **W0.5:** Criar testes unitários de construção e validação de Magic Packet em `app/test/wake_on_lan_test.dart`.

---

### 🔒 Fase W1 — Controles Seguros de Energia e Sessão Windows
**Objetivo:** Permitir bloquear a tela do PC ou colocá-lo em suspensão quando o usuário se afastar da mesa.

- [x] **W1.1:** Implementar ações tipadas no Backend (`PowerControlService.cs`):
  - `system.lock_workstation` (via Win32 `LockWorkStation()`, seguro e nativo com dry-run em testes)
  - `system.sleep` (via `SetSuspendState(false, false, false)` com dry-run em testes)
- [x] **W1.2:** Expor endpoints autenticados com registro obrigatório no `JobHistoryService`:
  - `POST /api/system/lock` (`/api/v1/system/lock`)
  - `POST /api/system/sleep` (`/api/v1/system/sleep`)
- [x] **W1.3:** Adicionar botões **"Bloquear PC"** e **"Suspender PC"** na `StatusPage` (`PowerControlCard`) com diálogo de confirmação dupla (*"Atenção: Ao bloquear ou suspender o PC, a captura de tela ficará indisponível até o desbloqueio local"*).
- [x] **W1.4:** Criar testes unitários em `tests/Command.Tests/PowerControlTests.cs` (`7/7` PASS) e `app/test/power_control_ui_test.dart` (`4/4` PASS).

---

### 🔔 Fase W2 — Notificações Locais e Monitoramento Resiliente no Android
**Objetivo:** Notificar o usuário no celular quando um alerta crítico de saúde (Temperatura, CPU, Disco ou Bateria do Notebook) ocorrer ou quando um job longo terminar.

- [x] **W2.1:** Implementar `MobileNotificationService.dart` com canais de notificação estruturados:
  - Canal `command_critical_alerts` (Alertas térmicos/recursos críticos)
  - Canal `command_transfer_jobs` (Conclusão de transferências e rotinas)
- [x] **W2.2:** Sanitização estrita de privacidade (mascaramento de IPs IPv4 privados e caminhos `C:\Users\<nome>`) e cooldown configurável (padrão 5 minutos por chave).
- [x] **W2.3:** Controle de ativação/desativação (`enabled`) no serviço de notificações.
- [x] **W2.4:** Criar testes unitários em `app/test/mobile_notification_test.dart` (`4/4` PASS).

---

### 📲 Fase W3 — Modo Mini-Dashboard (Quick Glance / PiP & Atalhos do Launcher)
**Objetivo:** Oferecer acesso de 1 segundo às métricas vitais e ações principais direto do ícone do app (App Shortcuts) e modo compacto para uso em mesa/dock.

- [x] **W3.1:** Configurar **App Shortcuts** estáticos no Android (`app/android/app/src/main/res/xml/shortcuts.xml`) para acesso direto da Home: *"Status do PC"*, *"Capturar Tela"*, *"Modo Trabalho"*, *"Wake-on-LAN"*.
- [x] **W3.2:** Criar modo **Mini-Dashboard (`DockDashboardPage`)** em tela cheia de alto contraste com relógio digital, gauges grandes de CPU/RAM/GPU/Temp e botões rápidos (`Bloquear PC`, `Capturar Tela`, `Sair do Dock`).
- [x] **W3.3:** Criar testes de widget em `app/test/dock_mode_test.dart` (`3/3` PASS).

---

### 🏁 Fase W4 — Homologação E2E, Pacotes `v0.6.0` e Sincronização
**Objetivo:** Homologar todas as entregas da Onda v0.6 no emulador Pixel 9 e gerar release `v0.6.0`.

- [x] **W4.1:** Executar suíte completa (`dotnet test` 268/268 PASS + `flutter test` 145/145 PASS + `flutter analyze --no-fatal-infos` exit 0).
- [x] **W4.2:** Gerar pacotes `dist/command-bridge-v0.6.0-win-x64.zip` e `dist/command-app-v0.6.0-debug.apk` com hashes SHA-256.
- [x] **W4.3:** Validar Wake-on-LAN, Controles de Sessão e Mini-Dashboard Dock Mode no emulador Pixel 9 (`emulator-5554`).
- [x] **W4.4:** Atualizar `STATE.md`, sincronizar NexusVault e realizar commit + push.

---

## 3. Checklist Mestre de Progresso (v0.6)

- [x] **W0** — Fullstack: Wake-on-LAN (Magic Packet UDP + Descoberta de MAC)
- [x] **W1** — Fullstack: Controles Seguros de Sessão e Energia (Bloquear / Suspender)
- [x] **W2** — Mobile: Notificações Inteligentes de Alertas Críticos e Jobs
- [x] **W3** — Mobile: App Shortcuts Android e Modo Mini-Dashboard (Dock de Mesa)
- [x] **W4** — QA/Release: Homologação E2E no Pixel 9 e Pacotes `v0.6.0`
