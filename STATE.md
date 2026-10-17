# STATE — ponto de retomada

Comece por este arquivo. O roadmap oficial aprovado está em `ROADMAP.md`.

**Atualizado:** 2026-10-17 · **Marco ativo:** F3 — Telemetria de Hardware e Tema Amethyst · **Estado:** READY

## O que existe hoje
- Repositório Git conectado ao upstream `https://github.com/ggfto/DroidDeck.git` (v1.9.1 / `5cd2ddc`).
- In-tree fork concluído com histórico preservado e mesclado no branch `main` (`commit 0f4a14d`).
- **Backend .NET 8 (`DroidDeck/`):**
  - WinForms Tray + ASP.NET Core API + SignalR + Web Configurator.
  - Monitoramento de telemetria estendido em `SystemMonitorService.cs`: CPU, RAM, GPU, Rede, Disco do Sistema e Uptime.
  - Endpoint HTTP autenticado `GET /api/metrics` mapeado.
  - 163/163 testes unitários e de integração aprovados (0 falhas).
- **Frontend Flutter (`app/`):**
  - Aplicativo móvel e Web configurator.
  - Tema **Amethyst Command** (`#050408`, `#13101B`, `#1E1829`, `#A78BFA`) configurado como preset no `app_theme.dart`.
  - Nova aba **Status** no app móvel (`StatusPage`) exibindo métricas de hardware em tempo real (CPU, RAM, Disco, GPU, Rede, Uptime), badge Online/Offline e card do Hermes IA isolado ("Não configurado").
  - 50/50 testes de widgets e unitários aprovados (0 falhas), `flutter analyze` exit 0.
- **Módulos e segurança nativos preservados:** OBS Studio, Discord RPC, Tuya/Smart Life, Soundboard MyInstants, Mixer de áudio, Mídia WinRT, Steam Launcher, Perfis e pareamento nativo via QR (`droiddeck://pair`) com API key protegida por DPAPI.

## Última atividade
- ID: F3-IMPL (2026-10-17)
- Resultado:
  - Implementado tema Amethyst Dark em `app_theme.dart`.
  - Enriquecido modelo e serviço de telemetria no C# com medição de Disco e Uptime monotônico.
  - Mapeado endpoint `GET /api/metrics`.
  - Criado widget `StatusPage` e integrado à navegação principal do app (`HomePage`).
  - Criados testes `CommandTelemetryTests.cs` e `status_page_test.dart`.
- Testes/build:
  - `dotnet test DroidDeck.sln --filter "Category!=RequiresDesktop"`: 163 PASS, 0 FAIL.
  - `flutter test`: 50 PASS, 0 FAIL.
  - `flutter analyze --no-fatal-infos`: exit 0.

## Próxima ação
- F4 — Catálogo e execução de aplicativos/projetos (FL-1 Obsidian, FL-2 Editor de projeto/Orbit, FL-5 Encerrar app permitido com confirmação).

## Bloqueios e aprovações humanas
- Direção de fork in-tree e modelo DroidDeck: APROVADO pelo proprietário.
- D-004 (O que é o projeto “Orbit” do FL-2): aguarda definição da pasta/comando do editor.
- Push remoto: PENDING autorização explícita do proprietário (Regra 10 de `AGENTS.md`).
