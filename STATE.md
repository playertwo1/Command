# STATE — ponto de retomada

Comece por este arquivo. O roadmap oficial aprovado está em `ROADMAP.md`.

**Atualizado:** 2026-10-17 · **Marco ativo:** Onda v0.3 — Tela e Arquivos Avançados · **Estado:** ONDA v0.3 CONCLUÍDA COM SUCESSO (T0 a T7 - 100% PASS)

## O que existe hoje
- Repositório Git conectado ao upstream `https://github.com/ggfto/DroidDeck.git` (v1.9.1 / `5cd2ddc`).
- In-tree fork concluído com histórico preservado e mesclado no branch `main`.
- **Pacotes Oficiais v0.3.0 e Documentação de Entrega:**
  - `dist/command-bridge-v0.3.0-win-x64.zip` (SHA-256: `1843ad0f4d6636e57951d9d84dc52a9f2dbe6ca23f2459879311576a5d7263b7`).
  - `dist/command-app-v0.3.0-debug.apk` (SHA-256: `a644199536cd25e2fef87a06ae517960c69fc6624325244da414392b9e6fda13`).
- **Pacotes Anteriores (v0.2.0 e v0.1.0):**
  - `dist/command-bridge-v0.2.0-win-x64.zip` / `dist/command-app-v0.2.0-debug.apk`
- **Pacotes Oficiais v0.1.0 (Legado):**
  - `dist/command-bridge-v0.1.0-win-x64.zip` (SHA-256: `0E07436E4D310DD21C7E7CCA06FE3A55F3C1231F85524A62D9CFD85DDD4D32E7`).
  - `dist/command-app-v0.1.0-debug.apk` (SHA-256: `537D38913DB4E6DB36C85CFB85488C3BEC46B6F201AC2D3423E1DA649784E975`).
  - `docs/INSTALL.md` com instruções detalhadas de instalação sem admin, execução, firewall privado, pareamento QR + DPAPI, parada, revogação e desinstalação.
  - `docs/TROUBLESHOOTING.md` com diagnósticos de rede/LAN/Tailscale, limites de segurança de captura Win32, transferências e independência de IA.
- **Backend .NET 8 (`DroidDeck/`):**
  - WinForms Tray + ASP.NET Core API + SignalR + Web Configurator.
  - Monitoramento de telemetria estendido em `SystemMonitorService.cs`: CPU, RAM, GPU, Rede, Disco do Sistema e Uptime.
  - Catálogo de aplicativos e projetos autorizados em `AppCatalogService.cs` (`obsidian`, `orbit`, `test_notepad`).
  - Executor de comandos com rastreamento persistente de jobs em `JobHistoryService.cs` (`accepted`, `running`, `succeeded`, `failed`, `cancelled`), proteção contra replay e toque duplicado (idempotência por RequestId).
  - Encerramento seguro de processos permitidos com revalidação de PID e tempo de início (`CanKill = true` exclusivo para `test_notepad`).
  - **Captura de Tela Manual e Proteção de Sessão (`ScreenshotService.cs` + `WindowsDesktopCaptureProvider.cs`):**
    - Captura sob demanda do monitor principal via GDI `BitBlt` em thread dedicada vinculada ao desktop de entrada (`SetThreadDesktop`).
    - Detecção estrita de área de trabalho bloqueada ou UAC via Win32 `OpenInputDesktop` retornando `ERROR_ACCESS_DENIED (5) -> SESSION_LOCKED (423 Locked)` sem bypass.
    - Armazenamento temporário seguro em `%LocalAppData%\DroidDeck\screenshots` com validade de 10 minutos (`ExpiresAtUtc`), expurgo automático e retorno `410 Gone`.
    - Isolamento de entrega por `DeviceId` (somente o dispositivo solicitante pode acessar o arquivo) e auditoria de metadados sanitizados em jobs.
    - Controladores REST `ScreenshotsController.cs` mapeados em `/api/screenshots/capture`, `/api/screenshots/{id}` e `/api/screenshots/{id}/info` (com aliases `/api/v1/`).
  - **Transferência Restrita de Arquivos (`TransferService.cs` + `TransfersController.cs`):**
    - Duas raízes isoladas sob `%LocalAppData%\DroidDeck\transfers\`: `inbound` (upload) e `outbound` (download).
    - Proteção estrita anti-traversal (`..`, `/`, `\`, ADS `:`, UNC, nomes reservados Win32 como `CON`, `NUL`, `PRN`, e symlinks).
    - Blocklist de extensões perigosas (`.exe`, `.bat`, `.cmd`, `.ps1`, `.sh`, `.dll`, etc.).
    - Limite estrito de 100 MiB por arquivo e escrita temporária atômica via `.tmp`.
    - Validação bidirecional de integridade criptográfica SHA-256 e prevenção contra colisão de arquivos (409 Conflict).
    - Auditoria de operações `transfer.download` e `transfer.upload` em `JobHistoryService`.
    - Endpoints REST mapeados em `/api/transfers/{rootId}`, `/api/transfers/{rootId}/{fileName}` e `/api/transfers/upload`.
  - 38/38 testes de integração Command aprovados (0 falhas).
- **Frontend Flutter (`app/`):**
  - Aplicativo móvel e Web configurator.
  - Tema **Amethyst Command** (`#050408`, `#13101B`, `#1E1829`, `#A78BFA`) configurado como preset padrão e padrão escuro no `app_theme.dart` e `theme_controller.dart`.
  - Remoção de controles não entregues (botões de backup em `config_page.dart` e macro tipo `multi` em `action_picker.dart`).
  - Resiliência e recuperação de falhas:
    - Banner persistente `Command Bridge Desconectado` no topo da `StatusPage` quando offline, com botão `Reconectar` de 1 toque que reestabelece SignalR e recarrega métricas.
    - Notificações de erro (SnackBars) em mutações com aviso explícito de que **não há retry automático**.
    - Histórico recente com timestamps em fonte monoespaçada e orientações de recuperação para jobs em estado `unknown` ou `failed`.
  - Aba **Status** no app móvel (`StatusPage`) exibindo:
    - Métricas de hardware em tempo real (CPU, RAM, Disco, GPU, Rede, Uptime).
    - Card do Hermes IA isolado e passivo ("Not configured"), sem chamadas de rede ou chats falsos.
    - Card **Ações Autorizadas** com listagem dos apps permitidos, status de execução, botão "Abrir" e botão "Encerrar" protegido por diálogo de confirmação explícita.
    - Card **Captura de Tela** com thumbnail preview real da tela do Windows, resolução, tamanho em KB, validade de 10 min, botões "Visualizar" e "Compartilhar", e banner de alerta contra sessão bloqueada.
    - Visualizador de tela cheia `ScreenshotViewerPage` com `InteractiveViewer` (pinch-to-zoom 0.5x a 5.0x e navegação panorâmica) e folha de compartilhamento nativa Android (`SharePlus`).
    - Card **Transferência de Arquivos** com listagem dos arquivos disponíveis na pasta `outbound` do PC, botão "Baixar" com validação estrita de integridade SHA-256 no cliente e botão "Enviar Arquivo para o PC (Inbound)" com cálculo de hash prévio e confirmação visual.
    - Card **Atividade Recente** exibindo o histórico de jobs em tempo real com estados coloridos, hora monoespaçada, orientações e opções de atualizar e limpar histórico.
  - 67/67 testes de widgets e unitários aprovados (0 falhas), `flutter analyze` exit 0.
- **Módulos e segurança nativos preservados:** OBS Studio, Discord RPC, Tuya/Smart Life, Soundboard MyInstants, Mixer de áudio, Mídia WinRT, Steam Launcher, Perfis e pareamento nativo via QR (`droiddeck://pair`) com API key protegida por DPAPI.

## Última atividade
- ID: F9-PILOT-AND-AUDIT (2026-10-17)
- Resultado:
  - Bateria automatizada de 30 operações nos 5 fluxos piloto (FL-1 a FL-5) executada no emulador Pixel 9 Pro (API 37) contra o Bridge Windows release (.NET 8 na porta 4787 via `adb reverse`).
  - Total de execuções: 30 | Sucessos confirmados: 29 (96.67% de taxa de sucesso >= 95% do Roadmap ➔ PASS).
  - Detalhamento por fluxo:
    - FL-1 (Obsidian): 6/6 (100% PASS), média ~395 ms.
    - FL-2 (Orbit PJ): 6/6 (100% PASS), média ~482 ms.
    - FL-3 (Screenshot Win32 GDI BitBlt): 6/6 (100% PASS), média ~471 ms.
    - FL-4 (Transferência de Arquivos SHA-256): 6/6 (100% PASS), média ~560 ms.
    - FL-5 (Encerramento Seguro Bloco de Notas): 5/6 (83.3% PASS, 1 timeout na Rodada 1 resolvido nas rodadas 2-6).
  - Auditoria de segurança: Zero violações de privilégio, zero vazamento de credenciais, zero chamadas de shell arbitrário, zero bypass de UAC/sessão bloqueada e zero dependência de IA (Hermes inativo).
  - Documento formal de aceite entregue em `docs/MVP_APPROVAL.md` com resultado técnico PASS.
  - Evidências salvas em `docs/evidence/F9/pilot_log.json`, `docs/evidence/F9/PILOT_LOG.md`, `docs/assets/f9_*.png` e sincronizadas no NexusVault (`90_Anexos/` e `01_Projetos/Command.md`).
- Testes/build:
  - `flutter test`: 67 PASS, 0 FAIL.
  - `dotnet test` (Command): 38 PASS, 0 FAIL.
  - Live E2E Emulator Pixel 9 (Bateria 30 execuções): 29 PASS, 1 timeout de sync corrigido (96.67% PASS).

- ID: S0-SPIKE-SENSORS-POWER (2026-10-17)
  - Spike técnico executado no host Windows (`BOOKFAEL` / Samsung NP960XJG-LG1BR, Intel Core Ultra X7 358H, Intel Arc B390):
    - Win32 `GetSystemPowerStatus`: 100% PASS sem elevação (Bateria 90%, carregando, detecção de desktop sem bateria).
    - `LibreHardwareMonitorLib` v0.9.6: Inicialização e enumeração de hardware 100% funcional. Confirmada exigência de driver kernel/elevação para MSR de temperatura em CPUs Intel Core Ultra.
    - Matriz de fallback estabelecida: `CpuTempC` e `GpuTempC` como `float?` no DTO, retornando `null` com segurança em modo não-elevado (padrão de segurança sem UAC).
  - Relatório formal gerado em `docs/evidence/v0.2/S0_SPIKE.md`.
- ID: S1-THERMAL-BATTERY-BACKEND (2026-10-17)
  - Integração do `HardwareSensorProvider` no `SystemMonitorService` com cache de amostragem (3s) e fallback gracioso sem impacto no loop de 1s.
  - Adição de `CpuTempC`, `GpuTempC`, `BatteryPercent`, `IsCharging` e `HasBattery` em `SystemStats.cs`.
  - Mapeamento e validação de `GET /api/metrics` e alias `GET /api/v1/metrics`.
  - Testes: 210/210 testes unitários C# aprovados (`dotnet test`), incluindo 5 novos testes de `HardwareSensorsTests.cs`.
  - Validação ao vivo no host Windows com retorno real: Bateria 90%, na tomada, e fallback nulo para termômetros MSR em modo usuário.

- ID: S2-HISTORY-AND-DISKS-BACKEND (2026-10-17)
  - Implementação de buffer circular FIFO de 60 posições (`MetricSampleDto`) em `SystemMonitorService.cs` thread-safe com lock dedicado.
  - Implementação de enumeração de volumes de disco fixos (`DiskVolumeDto`) via `DriveInfo.GetDrives()`, preenchendo `Disks` e preservando compatibilidade com o volume primário legado (`DiskTotalGB`, `DiskAvailableGB`, `DiskUsage`).
  - Atualização do payload de `GET /api/metrics` e SignalR `ReceiveSystemStats` com `History` (60s) e `Disks`.
  - Correção de isolamento estático no runner xUnit (`[assembly: CollectionBehavior(DisableTestParallelization = true)]`), eliminando concorrência sobre variáveis de ambiente.
  - Testes: 215/215 testes unitários C# aprovados (`dotnet test`), incluindo 5 novos testes de `HistoryAndDisksTests.cs`.
  - Validação ao vivo no host Windows com retorno real: Volume `C:` (919 GB total, 436.7 GB livre, 52.5% uso) e amostras no buffer de histórico.

- ID: S5-SPARKLINE-SERVICES-PROCESSES-UI (2026-10-17)
  - `MetricSparkline`: Componente visual leve com `CustomPainter` renderizando a curva dos últimos 60s com gradiente translúcido Amethyst (`#A78BFA`) e Cyan (`#38BDF8`).
  - `DroidDeckClient`: Modelos `WindowsServiceItem`, `TopProcessItem` e `TopProcessesData` e métodos `getServices()` e `getTopProcesses()`.
  - `StatusPage`: Card `Histórico de Carga (60s)` com sparklines sincronizados de CPU e RAM, Card `Serviços do Windows` com badges `Ativo`, `Parado` e `Ausente`, e Card `Top Processos` com alternador por Memória (RAM) e CPU em fonte monoespaçada com PIDs.
  - Testes: 74/74 testes Flutter aprovados (`flutter test`), 222/222 testes C# aprovados (`dotnet test`).

- ID: S6-HEALTH-ALERTS-ENGINE (2026-10-17)
  - `HealthAlertService`: Motor reativo de alertas com limites configuráveis (CPU, RAM, Temperatura, Disco, Bateria), persistência em `SharedPreferences` e *cooldown* anti-spam de 60 segundos.
  - `HealthAlertSettingsPage`: Tela de ajustes com sliders e validação de limiares.
  - Testes: 80/80 testes Flutter aprovados.

- ID: S7-MULTI-PC-PROFILES (2026-10-17)
  - `PcStore` / `PcProfileManager`: Suporte a múltiplos computadores pareados, seleção rápida com 1-toque, persistência de `lastConnectedAt` e modal de alternância na `StatusPage`.
  - Testes: 85/85 testes Flutter aprovados.

- ID: S8-CONNECTIVITY-AND-LATENCY (2026-10-17)
  - Backend ASP.NET Core: `GET /api/ping` e `GET /api/v1/ping` leves retornando `hostName`, `serverTimeUtc` e status `ok` com overhead mínimo.
  - Frontend Flutter: `PingResult` model, `client.ping()` com cálculo de RTT, medição periódica de `latencyMs` e cálculo de `jitterMs`, e badge semafórico de latência integrado ao lado do status `Online`.
  - Testes: 224/224 testes C# aprovados, 91/91 testes Flutter aprovados (Total: 315 testes aprovados).

- ID: S9-HEALTH-REPORT-EXPORT (2026-10-17)
  - `HealthReportGenerator`: Gerador de relatórios técnicos em Markdown e JSON estruturados, cobrindo telemetria completa, temperaturas (CPU/GPU), bateria, volumes de disco, serviços do Windows, top 5 processos (memória/CPU) e latência/jitter RTT.
  - Sanitização Estrita (Regra 4): Mascaramento de endereços IP de LAN (`192.168.*.***`), omissão total e absoluta de `apiKey`, tokens e credenciais.
  - Interface do Usuário: Botão de exportação na AppBar e Card de Diagnóstico do Sistema na `StatusPage` abrindo modal com preview do relatório, alternador Markdown/JSON, toggle de sanitização, botão de cópia com SnackBar e compartilhamento nativo via `SharePlus`.
  - Testes: 97/97 testes Flutter aprovados (`health_report_generator_test.dart`), 224/224 testes C# aprovados, `flutter analyze` exit 0 (Total: 321 testes aprovados).

- ID: T7-RELEASE-V0.3.0-AND-E2E (2026-10-17)
  - Suíte completa de testes automatizados: **241/241 testes C# (.NET 8) PASS**, **111/111 testes Flutter PASS** (Total: **352 testes automatizados PASS**), `flutter analyze --no-fatal-infos` exit 0 (0 erros, 0 avisos).
  - Pacotes oficiais gerados em `dist/`:
    - `dist/command-bridge-v0.3.0-win-x64.zip` (SHA-256: `1843ad0f4d6636e57951d9d84dc52a9f2dbe6ca23f2459879311576a5d7263b7`).
    - `dist/command-app-v0.3.0-debug.apk` (SHA-256: `a644199536cd25e2fef87a06ae517960c69fc6624325244da414392b9e6fda13`).
  - Entregas principais da Onda v0.3:
    - **T0 & T1:** Streaming contínuo MJPEG (`GET /api/stream/desktop`), com lock de concorrência de 1 cliente, cancelamento cooperativo e frame informativo de bloqueio sem bypass de segurança do Windows.
    - **T2:** Player móvel `DesktopLiveStreamViewer` na `StatusPage` com controle Play/Pause, badge dinâmico de FPS, dropdown de qualidade (Standard/Eco/Performance) e modo fullscreen zoom/pan.
    - **T3 & T4:** Navegação e download hierárquico em sandbox (`outbound`/`inbound`) com proteção anti-traversal e symlink rejection, e gerenciador móvel `RemoteFileManagerPage` com breadcrumbs e integridade SHA-256.
    - **T5:** Compartilhamento direto Android → PC via `ACTION_SEND` e `ACTION_SEND_MULTIPLE` com `ShareReceiverSheet` e limite de 100 MiB.
    - **T6:** Editor de screenshots na `ScreenshotViewerPage` com retângulo de destaque, caneta livre, ações de desfazer/limpar e exportação não-destrutiva via `RepaintBoundary`.
  - Validação E2E ao vivo realizada no emulador Pixel 9 Pro (`emulator-5554` / API 37):
    - App v0.3.0 instalado e validado visualmente (`emulator_v03_status.png`).
    - Navegação do Gerenciador de Arquivos Remoto validada ao vivo (`emulator_v03_file_manager.png`).
    - Card de Live Stream renderizado e funcional (`emulator_v03_stream_files.png`).
  - Evidências salvas em `docs/evidence/v0.3/` e `docs/assets/emulator_v03_*.png`, sincronizadas no NexusVault (`90_Anexos/` e `01_Projetos/Command.md`).

## Próxima ação
- Onda v0.3 concluída com sucesso (100% das 8 fases aprovadas).
- Apresentar relatório de encerramento da v0.3 ao usuário e iniciar planejamento da Onda v0.4 (Módulo Hermes IA ou Automação/Macros Encadeadas).

## Bloqueios e aprovações humanas
- Direção de fork in-tree e modelo DroidDeck: APROVADO pelo proprietário.
- D-004 (O que é o projeto “Orbit” do FL-2): RESOLVIDO (`C:\Users\notefael\projetos\orbit-pj` no VS Code/Explorer).
- Push remoto e atualização contínua do Vault: AUTORIZADO pelo proprietário ("sempre faca commit e push apos o fim de uma fase e atualize o vault crie diagramas e imagens do projeto, depois avance").
- Onda v0.1 (MVP), Onda v0.2 e Onda v0.3: 100% CONCLUÍDAS com sucesso.
