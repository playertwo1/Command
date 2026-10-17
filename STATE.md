# STATE — ponto de retomada

Comece por este arquivo. O roadmap oficial aprovado está em `ROADMAP.md`.

**Atualizado:** 2026-10-17 · **Marco ativo:** F4 — Catálogo, Ações e Histórico · **Estado:** DONE -> Avançando para F5

## O que existe hoje
- Repositório Git conectado ao upstream `https://github.com/ggfto/DroidDeck.git` (v1.9.1 / `5cd2ddc`).
- In-tree fork concluído com histórico preservado e mesclado no branch `main`.
- **Backend .NET 8 (`DroidDeck/`):**
  - WinForms Tray + ASP.NET Core API + SignalR + Web Configurator.
  - Monitoramento de telemetria estendido em `SystemMonitorService.cs`: CPU, RAM, GPU, Rede, Disco do Sistema e Uptime.
  - Catálogo de aplicativos e projetos autorizados em `AppCatalogService.cs` (`obsidian`, `orbit`, `test_notepad`).
  - Executor de comandos com rastreamento persistente de jobs em `JobHistoryService.cs` (`accepted`, `running`, `succeeded`, `failed`, `cancelled`), proteção contra replay e toque duplicado (idempotência por RequestId).
  - Encerramento seguro de processos permitidos com revalidação de PID e tempo de início (`CanKill = true` exclusivo para `test_notepad`).
  - Controladores REST `AppsController.cs` e `JobsController.cs` mapeados em `/api/apps` e `/api/jobs`.
  - 172/172 testes unitários e de integração aprovados (0 falhas).
- **Frontend Flutter (`app/`):**
  - Aplicativo móvel e Web configurator.
  - Tema **Amethyst Command** (`#050408`, `#13101B`, `#1E1829`, `#A78BFA`) configurado como preset no `app_theme.dart`.
  - Aba **Status** no app móvel (`StatusPage`) exibindo:
    - Métricas de hardware em tempo real (CPU, RAM, Disco, GPU, Rede, Uptime).
    - Card do Hermes IA isolado ("Não configurado").
    - Card **Ações Autorizadas** com listagem dos apps permitidos, status de execução, botão "Abrir" e botão "Encerrar" protegido por diálogo de confirmação explícita.
    - Card **Atividade Recente** exibindo o histórico de jobs em tempo real com estados coloridos, hora e opções de atualizar e limpar histórico.
  - 53/53 testes de widgets e unitários aprovados (0 falhas), `flutter analyze` exit 0.
- **Módulos e segurança nativos preservados:** OBS Studio, Discord RPC, Tuya/Smart Life, Soundboard MyInstants, Mixer de áudio, Mídia WinRT, Steam Launcher, Perfis e pareamento nativo via QR (`droiddeck://pair`) com API key protegida por DPAPI.

## Última atividade
- ID: F4-IMPL (2026-10-17)
- Resultado:
  - Implementado `AppCatalogService` com allowlist estrita (Obsidian, Orbit PJ, Bloco de Notas).
  - Implementado `JobHistoryService` com persistência local em JSON, idempotência e auditoria.
  - Implementados `AppsController` e `JobsController` com rotas `/api/apps` e `/api/jobs`.
  - Atualizado `DroidDeckClient` no Flutter com métodos tipados de catálogo, execução e encerramento.
  - Implementados cards visuais de Ações e Atividade Recente no `StatusPage`.
  - Criados testes `AppCatalogAndJobsTests.cs` (.NET) e `app_catalog_and_jobs_test.dart` (Flutter).
- Testes/build:
  - `dotnet test DroidDeck.sln --filter "Category!=RequiresDesktop"`: 172 PASS, 0 FAIL.
  - `flutter test`: 53 PASS, 0 FAIL.
  - `flutter analyze --no-fatal-infos`: exit 0.

## Próxima ação
- F5 — Screenshot manual (captura do monitor principal sob demanda, rejeição em tela de bloqueio/UAC, visualização protegida).

## Bloqueios e aprovações humanas
- Direção de fork in-tree e modelo DroidDeck: APROVADO pelo proprietário.
- D-004 (O que é o projeto “Orbit” do FL-2): RESOLVIDO (`C:\Users\notefael\projetos\orbit-pj` no VS Code/Explorer).
- Push remoto e atualização contínua do Vault: AUTORIZADO pelo proprietário ("sempre faca commit e push apos o fim de uma fase e atualize o vault crie diagramas e imagens do projeto, depois avance").
