# Checklist de gates e aceite

O `ROADMAP.md` contém o escopo e os critérios detalhados de F0–F9. Este arquivo registra resultados técnicos separados da aprovação humana. `NOT_RUN` nunca significa `PASS`.

## F0 — escolha das bases
- [x] URLs, commits SHA, datas e licenças dos candidatos registrados.
- [x] Builds pertinentes reproduzidos em isolamento, com comandos e resultados guardados em `docs/evidence/F0/`.
- [x] ADR-001 (Android), ADR-002 (Bridge) e ADR-007 (In-tree fork DroidDeck) concluídas.
- Resultado técnico: **PASS** · Aprovação humana das bases: **APPROVED**.

## F1–F8 — implementação e preparação do piloto
Critérios e cenários de cada fase estão em `ROADMAP.md`. Registrar a evidência em `docs/evidence/Fn/`; não avançar com critério obrigatório pendente.

| Fase | Entrega | Técnico | Evidência |
|---|---|---|---|
| F1 | Builds reproduzíveis + contrato v1 + `SECURITY.md` | PASS | `docs/evidence/F1/` |
| F2 | Pareamento, autenticação e revogação | PASS | `docs/evidence/F2/` (QR DPAPI) |
| F3 | Telemetria real no aparelho | PASS | `docs/assets/emulator_telemetry_live.png` |
| F4 | FL-1, FL-2, FL-5 + Atividade | PASS | `docs/assets/emulator_actions_launch.png`, `emulator_actions_kill.png` |
| F5 | FL-3 screenshot | PASS | `docs/assets/emulator_screenshot_card.png`, `emulator_screenshot_viewer.png` |
| F6 | FL-4 transferência íntegra | PASS | `docs/assets/emulator_transfer_card.png`, `emulator_transfer_download.png`, `emulator_transfer_upload.png` |
| F7 | Revisão independente sem achado crítico/alto | PASS | `docs/assets/emulator_f7_*.png`, `app/test/fault_tolerance_and_visual_test.dart` |
| F8 | Instalação repetível + cinco fluxos independentes | PASS | `docs/INSTALL.md`, `docs/TROUBLESHOOTING.md`, `docs/assets/emulator_f8_*.png` |

- Nunca aprovar implementação com credenciais expostas, shell arbitrário, arquivos fora das raízes autorizadas ou dependência de serviço externo para controle direto.

## F9 — piloto e decisão do MVP
- [x] Bateria de piloto com 30 execuções registradas, com no mínimo seis por fluxo (FL-1…FL-5). Registrado em `docs/evidence/F9/PILOT_LOG.md` e `docs/evidence/F9/pilot_log.json`.
- [x] Taxa de sucesso (29/30 = 96.67% >= 95%), zero falhas críticas, integridade SHA-256 e privacidade avaliadas.
- [x] Os cinco fluxos diretos não dependem de serviço de IA e operam via Bridge .NET 8.
- [x] Evidências reunidas e formalizadas em `docs/MVP_APPROVAL.md`.
- Resultado técnico: **PASS** · Aprovação humana do MVP: **PENDING (Submetido para homologação em `docs/MVP_APPROVAL.md`)**.

## Critérios visuais
- [x] Capturas do app real comparadas com `DESIGN.md` e as referências Stitch (Amethyst Dark #050408, #13101B, #1E1829, #352B45, #A78BFA).
- [x] Estados offline, erro, carregamento, confirmação e sucesso final conferidos (Banner de reconexão transparente, sem retry automático em mutações, dicas acionáveis para falhas).
- [x] Acessibilidade, contraste e alvos de toque verificados (remoção de controles não entregues como backup e macros).
- Aceite visual humano: **PASS (Evidências no emulador Pixel 9 / API 37 em docs/assets/emulator_f7_*.png)**.

## Ondas v0.4, v0.5 e v0.6 — Entregas e Gates Técnicos

| Onda | Entrega | Status | Testes | Evidência |
|---|---|---|---|---|
| **v0.5** | Automação, Perfis de Workspace e Macros Encadeadas | PASS | 261 C# / 130 Flutter PASS | `ROADMAP_V0.5.md`, `RoutineServiceTests.cs`, `WebhookNotificationServiceTests.cs`, `workspace_routines_test.dart` |
| **v0.6** | Mobilidade Expandida, Wake-on-LAN, Energia e Modo Dock | PASS | 268 C# / 145 Flutter PASS | `ROADMAP_V0.6.md`, `PowerControlTests.cs`, `power_control_ui_test.dart`, `wake_on_lan_test.dart`, `dock_mode_test.dart` |

## Onda v1.0 — Robustez Operacional, Segurança Avançada, Backup e Auto-Update

| Fase | Entrega | Status | Testes | Evidência |
|---|---|---|---|---|
| **P0** | Permissões Granulares por Dispositivo, Auditoria e Guardião PIN/Biometria | PASS | 301 C# / 160 Flutter PASS | `SecurityPolicyTests.cs`, `security_center_test.dart` |
| **P1** | Backup Criptografado AES-256-GCM + PBKDF2-SHA256 e Restauração | PASS | Integrado | `EncryptedBackupTests.cs`, `encrypted_backup_test.dart` |
| **P2** | Verificador Seguro de Atualização (Velopack & SHA-256) | PASS | Integrado | `UpdateVerificationTests.cs`, `security_center_test.dart` |
| **P3** | Autodiagnóstico de Estabilidade de Longa Duração (RAM/Handles/Threads) | PASS | Integrado | `SystemStabilityTests.cs` |
| **P4** | Release v1.0.0 e Homologação Maestro E2E no Pixel 9 | PASS | 100% PASS (461 testes) | `e2e_maestro/flow_command_v10.yaml`, `docs/assets/emulator_v10_status.png` |
| **v1.1.0** | Correção do Configurador Web Local (`http://localhost:4787/`) e Empacotamento `wwwroot/` | PASS | 100% PASS (461 testes) | `Program.cs`, `DroidDeck.csproj`, `scripts/deploy-web.ps1` |

- **Artefatos Oficiais de Produção v1.1.0:**
  - `dist/command-bridge-v1.1.0-win-x64.zip` (SHA-256: `38e630aabfcde2b1400c0f8717b0c3b590ae3f8a5109b8973b6f1f627dd99aff`)
  - `dist/command-app-v1.1.0.apk` (SHA-256: `56827877a0f2643354578730faa673358a64f08bdc73df829c10e135e7af7be8`)
  - `dist/SHA256SUMS-v1.1.0.txt`

- **Artefatos Anteriores v1.0.0:**
  - `dist/command-bridge-v1.0.0-win-x64.zip` (SHA-256: `a2cf893ae36c0332769d51971d376d2372bdde64bc9b1c9dfd59f63a200b3593`)
  - `dist/command-app-v1.0.0-debug.apk` (SHA-256: `814777662bd42c6173c4df78877bb3fb80530f1501398ecdc40bd0c2f2fa8600`)
  - `dist/SHA256SUMS-v1.0.0.txt`

## Onda v1.5 — Multi-PC Simultâneo, Entrada Remota, Prévia ao Vivo, mDNS, Transferências Retomáveis e Instalador Assistido

| Fase | Entrega | Status | Testes | Evidência |
|---|---|---|---|---|
| **M0** | Multi-PC Simultâneo (2 conexões paralelas e hubs independentes) | PASS | 9 Flutter PASS | `pc_connections_test.dart` |
| **M1** | Painel Combinado dos 2 PCs, Ações Direcionadas e Feed Unificado | PASS | 32 Flutter PASS | `docs/evidence/v1.5/`, aceite visual `PASS_HUMAN` |
| **R0** | API de Entrada Remota tipada (/api/v1/input), Sessão e Bloqueio 423 | PASS | 71 C# PASS | `RemoteInputControllerTests.cs`, `RemoteControlSessionTests.cs` |
| **R1** | Trackpad Virtual, Atalhos Rápidos e Teclado com Limite 500 chars | PASS | 30 Flutter PASS | `trackpad_page_test.dart`, `remote_input_client_test.dart` |
| **R2** | Prévia ao Vivo (ScreenStreamController) com Toque-para-Clicar | PASS | 12 Flutter / 4 C# PASS | `stream_view_tap_click_test.dart`, `DesktopLiveStreamControllerTests.cs` |
| **D0** | Descoberta Automática mDNS (_command._tcp) e Reconexão LAN/Tailscale | PASS | 5 C# / 10 Flutter PASS | `MdnsDiscoveryTests.cs`, `reconnection_fallback_service_test.dart` |
| **T0** | Transferências em Blocos (4 MiB) Retomáveis com Integridade SHA-256 | PASS | 6 C# / 5 Flutter PASS | `TransferServiceTests.cs`, `resumable_transfer_test.dart` |
| **I0.2** | Matriz de Licenciamento Formalizada (Apache-2.0 / GPL-3.0) | PASS | Documentado | `docs/LICENSES.md` |
| **I0.3a** | Identidade do Instalador e Pipelines GitHub Actions | PASS | Integrado | `.github/workflows/release.yml`, `package.json` |
| **I0.3b** | Instalação por Usuário sem Admin e Autostart Opcional (HKCU) | PASS | Integrado | `docs/INSTALL.md` |
| **I0.3c** | Migração Segura de Dados Legados DroidDeck (DPAPI + CLI) | PASS | 11 C# PASS | `LegacyDataMigrationTests.cs`, `LegacyDataMigrationService.cs` |
| **I0.3d** | Instalador Assistido com Validação Estrita SHA-256 (`install.ps1`) | PASS | Validado | `scripts/install.ps1`, `install.ps1` |
| **I0.5** | Desinstalação com Preservação Padrão de Dados (`uninstall.ps1`) | PASS | Validado | `scripts/uninstall.ps1`, `uninstall.ps1` |
| **I0.6 / H0** | Homologação Física E2E em 2 Máquinas Físicas | AGUARDANDO | 637 testes PASS | `docs/evidence/v1.5/H0_HOMOLOGACAO.md` (`PENDING_HUMAN`) |

- **Suíte Total de Testes Automatizados v1.5:**
  - .NET 8 (Backend Bridge): **390/390 PASS**
  - Flutter (App Mobile): **247/247 PASS**
  - Total: **637/637 testes automatizados PASS (0 falhas)**
  - Análise Estática Flutter: **exit 0 (0 erros, 0 avisos)**

- **Artefatos Oficiais de Produção v1.5.0:**
  - `dist/command-installer/1.5.0-local.20261026.x64/Command-Setup.exe` (SHA-256: `522e1d66bbfba576c40f6792a713df7975794c0c1977ec54156b43901e0b6da6`)
  - `dist/command-bridge-v1.5.0-win-x64.zip` (SHA-256: `d6eb550a117d9b49532559199ec896e5da244c5e0da598f1b66e3447be114e4b`)
  - `dist/command-app-v1.5.0.apk` / `dist/Command.apk` (SHA-256: `643f3ee9c4d69f347cb21d3ca36c98421c7035a8d14aae6fbbca235416e00c30`)
  - `dist/SHA256SUMS-v1.5.0.txt`
