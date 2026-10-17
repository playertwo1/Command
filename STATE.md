# STATE — ponto de retomada

Comece por este arquivo. O roadmap oficial aprovado está em `ROADMAP.md`.

**Atualizado:** 2026-10-17 · **Marco ativo:** Onda v0.2 — Saúde, Diagnóstico, Alertas e Multi-PC · **Estado:** S2 CONCLUÍDO (PASS) -> Avançando para S3

## O que existe hoje
- Repositório Git conectado ao upstream `https://github.com/ggfto/DroidDeck.git` (v1.9.1 / `5cd2ddc`).
- In-tree fork concluído com histórico preservado e mesclado no branch `main`.
- **Pacotes Oficiais v0.1.0 e Documentação de Entrega:**
  - `dist/command-bridge-v0.1.0-win-x64.zip` (Bridge Windows auto-suficiente / self-contained .NET 8 com SHA-256 publicado).
  - `dist/command-app-v0.1.0-debug.apk` (APK Android de teste assinado com SHA-256 publicado).
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

## Próxima ação
- Iniciar **Fase S3 — Backend: Serviços Windows e Top 5 Processos (Somente Leitura)** conforme [`ROADMAP_V0.2.md`](ROADMAP_V0.2.md).

## Bloqueios e aprovações humanas
- Direção de fork in-tree e modelo DroidDeck: APROVADO pelo proprietário.
- D-004 (O que é o projeto “Orbit” do FL-2): RESOLVIDO (`C:\Users\notefael\projetos\orbit-pj` no VS Code/Explorer).
- Push remoto e atualização contínua do Vault: AUTORIZADO pelo proprietário ("sempre faca commit e push apos o fim de uma fase e atualize o vault crie diagramas e imagens do projeto, depois avance").
- Onda v0.2: Fases S0, S1 e S2 concluídas com sucesso.
