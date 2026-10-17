# STATE — ponto de retomada

Comece por este arquivo. O roadmap oficial aprovado está em `ROADMAP.md`.

**Atualizado:** 2026-10-17 · **Marco ativo:** F5 — Screenshot manual · **Estado:** DONE -> Avançando para F6

## O que existe hoje
- Repositório Git conectado ao upstream `https://github.com/ggfto/DroidDeck.git` (v1.9.1 / `5cd2ddc`).
- In-tree fork concluído com histórico preservado e mesclado no branch `main`.
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
  - 179/179 testes unitários e de integração aprovados (0 falhas).
- **Frontend Flutter (`app/`):**
  - Aplicativo móvel e Web configurator.
  - Tema **Amethyst Command** (`#050408`, `#13101B`, `#1E1829`, `#A78BFA`) configurado como preset no `app_theme.dart`.
  - Aba **Status** no app móvel (`StatusPage`) exibindo:
    - Métricas de hardware em tempo real (CPU, RAM, Disco, GPU, Rede, Uptime).
    - Card do Hermes IA isolado ("Não configurado").
    - Card **Ações Autorizadas** com listagem dos apps permitidos, status de execução, botão "Abrir" e botão "Encerrar" protegido por diálogo de confirmação explícita.
    - Card **Captura de Tela** com thumbnail preview real da tela do Windows, resolução, tamanho em KB, validade de 10 min, botões "Visualizar" e "Compartilhar", e banner de alerta contra sessão bloqueada.
    - Visualizador de tela cheia `ScreenshotViewerPage` com `InteractiveViewer` (pinch-to-zoom 0.5x a 5.0x e navegação panorâmica) e folha de compartilhamento nativa Android (`SharePlus`).
    - Card **Atividade Recente** exibindo o histórico de jobs em tempo real com estados coloridos, hora e opções de atualizar e limpar histórico.
  - 56/56 testes de widgets e unitários aprovados (0 falhas), `flutter analyze` exit 0.
- **Módulos e segurança nativos preservados:** OBS Studio, Discord RPC, Tuya/Smart Life, Soundboard MyInstants, Mixer de áudio, Mídia WinRT, Steam Launcher, Perfis e pareamento nativo via QR (`droiddeck://pair`) com API key protegida por DPAPI.

## Última atividade
- ID: F5-UAT-EMULATOR (2026-10-17)
- Resultado:
  - Validação ao vivo no emulador Android Pixel 9 (API 37) com backend DroidDeck (.NET 8) ativo em segundo plano na porta 4787.
  - Disparo de "Capturar Tela Agora" na tela do emulador -> captura real do monitor principal do Windows concluída com sucesso.
  - Thumbnail da área de trabalho exibida dinamicamente no Card de Captura com metadados (1080x1920, 389.8 KB, "Válido por 10 min").
  - Toque em "Visualizar" abriu `ScreenshotViewerPage` em tela cheia com zoom interativo funcional.
  - Toque em "Compartilhar" disparou folha nativa do sistema Android (`Sharing image` com Quick Share, Drive, Gmail, etc.).
  - Job auditado com sucesso no Card Atividade Recente (`screenshot.capture (primary_screen) succeeded`).
  - Evidências visuais salvas em `docs/assets/emulator_screenshot_*.png` e sincronizadas no NexusVault (`90_Anexos/` e `01_Projetos/Command.md`).
- Testes/build:
  - `dotnet test DroidDeck.sln --filter "Category!=RequiresDesktop"`: 179 PASS, 0 FAIL.
  - `flutter test`: 56 PASS, 0 FAIL.
  - `flutter analyze --no-fatal-infos`: exit 0.
  - Live E2E Emulator Pixel 9: PASS.

## Próxima ação
- F6 — Transferência restrita de arquivos (duas raízes isoladas no PC sob allowlist, upload de até 100 MiB com validação SHA-256 e escrita temporária atômica, download restrito da pasta de saída, proteção rigorosa contra path traversal, symlinks e caminhos UNC/absolutos).

## Bloqueios e aprovações humanas
- Direção de fork in-tree e modelo DroidDeck: APROVADO pelo proprietário.
- D-004 (O que é o projeto “Orbit” do FL-2): RESOLVIDO (`C:\Users\notefael\projetos\orbit-pj` no VS Code/Explorer).
- Push remoto e atualização contínua do Vault: AUTORIZADO pelo proprietário ("sempre faca commit e push apos o fim de uma fase e atualize o vault crie diagramas e imagens do projeto, depois avance").
