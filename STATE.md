# STATE — ponto de retomada

Comece por este arquivo. Para v1.5, o escopo aprovado está em `ROADMAP_V1.5.md`; os roadmaps anteriores preservam o histórico.

**Atualizado:** 2026-10-25 · **Marco ativo:** Onda v1.5 / U0.4d · **Estado:** M1 e U0.4b/U0.4c fechados com aceite funcional/visual do proprietário. U0.4c foi aprovado visualmente em 2026-10-25; countdown/pomodoro, atalhos dense em desktop e testes automatizados continuam `NOT_RUN`. Próxima frente ativa: porte seletivo U0.4d, após revisão do diff e dos gates U0.0.

## Retomada atual — v1.5
- U0.4b (2026-10-25): porte manual dos commits DroidDeck `88f528c622097b8f58195c0793b61d31c1612d40` e `0e1e1f2d0f460e5dda235ba62f1b564a996a2b7a`; licença GPL-3.0 por `app/LICENSE` conferida em ambos. Grade móvel reorganiza visualmente botões fora da área visível sem persistir coordenadas; fora de edição centraliza área ocupada e permite rolagem. Navegação vira rail em paisagem compacta, labels longos ajustam ao espaço, medidores ficam circulares e deck vazio recebe orientação Command em PT/EN. Não muda ações/execução, pareamento, logs ou transferências; nenhum código upstream editado. Após correção de sobreposição do CTA com tela cheia, `git diff --check` PASS e `flutter build apk --debug --no-pub` PASS (25,7 s); APK instalado no `Medium_Phone` Android 17/API 37, 1080×2400. AVD com fixture local offline e sem pareamento com PCs reais: hierarquia `uiautomator dump` e capturas em `app/build/` confirmaram reflow retrato, anéis CPU/RAM/GPU, rótulo longo, grade de 48 botões com rolagem até os itens finais, navegação rail em paisagem e CTA de deck vazio sem sobreposição em retrato/paisagem. Cache ainda guarda coordenadas originais de teste (CPU 0,0; RAM 0,1; rótulo 0,9; GPU 7,9). Telemetria real e integração com PCs físicos `NOT_RUN`; testes automatizados `NOT_RUN`. Proprietário aprovou o aceite visual de U0.4b em 2026-10-25 (`PASS_HUMAN`). Árvore tinha alterações concorrentes Windows/.NET/web/instalador; foram preservadas.
- U0.4c (2026-10-25): porte manual do timer/contador e alinhamento dos botões dense de backup, com origem GPL-3.0/SHA em `research/UPSTREAM.md`. Texto operacional permanece ≥12 px; espaço vertical disponível agora desconta padding da moldura antes de decidir exibir o ícone, removendo overflow visual de 4,4 px no contador; a barra de progresso só aparece quando cabe. Dense backup fica alinhado à esquerda com altura mínima 38 px; disponibilidade/importação e ações permanecem inalteradas. `flutter build apk --debug --no-pub` PASS (45,6 s), `flutter build web --no-pub` PASS (57,0 s) e `git diff --check` PASS. No `Medium_Phone` Android 17/API 37, 1080×2400, fixture local sem PC real: captura `app/build/u04c-final-counter.png` mostra contador 0 e rótulo Contador sem overflow. O proprietário aprovou visualmente a captura em 2026-10-25 (`PASS_HUMAN`). Countdown/pomodoro, visual dense desktop e testes automatizados `NOT_RUN`; integração com PC real `NOT_RUN`.
- APK Android 1.1.2 publicado em 2026-10-25: [prerelease privada de correção Multi-PC](https://github.com/playertwo1/Command/releases/tag/command-v1.1.2), tag no commit `7449fde6acf7ab25890c38c3d597b9501af316e3`, versionCode 13. Build release local Flutter 3.47.8, assinatura igual à 1.1.1 e alinhamento PASS; APK de 77.079.592 bytes, SHA-256 `002f6cd8d57357c357bf8a7857b92f04475af1bc9acc0999123d2d1579e7eb17`, digest confirmado no asset GitHub. Guia e checksum anexados. Emulador nesta correção: `NOT_RUN`; proprietário confirmou em 2026-10-25 que a correção está 100% funcional nos dois PCs, incluindo a alternância/estado online (`PASS_HUMAN`), e aprovou o aceite visual de M1 (`PASS_HUMAN`). Alterações locais anteriores do instalador/.NET e capturas privadas foram preservadas fora dos commits desta correção.
- Retorno físico do proprietário (2026-10-25): instalador funcionou nos dois PCs e o app alternou entre eles. As capturas mostram apenas um hub Online e, em uma delas, alvo diferente do cabeçalho de telemetria. Diagnóstico confirmado no código e reproduzido em testes: sem escolha manual de paralelo o segundo hub não era aberto, a topologia não era reativa e o cartão alterava somente o alvo; o menu também preservava o alvo antigo. Correção 1.1.2: recuperação automática dos dois perfis já pareados, respeito à desconexão explícita, reabertura do PC anterior em paralelo, painel reativo e seleção única para menu/cartão/telemetria. `flutter test --no-pub -j 1` nos cinco arquivos de conexões, perfis, painel, apps/atividade e rotinas — 32 PASS; análise dos arquivos tocados: seis infos preexistentes, sem erros/warnings. Build release local 1.1.2+13 PASS; assinatura e alinhamento verificados; publicada na prerelease privada 1.1.2. Validação física da correção: inicialmente `PENDING_HUMAN`; proprietário confirmou 100% funcional em ambos os PCs em 2026-10-25 (`PASS_HUMAN`). Aceite visual geral de M1 aprovado pelo proprietário em 2026-10-25 (`PASS_HUMAN`). As capturas recebidas permanecem locais; não foram publicadas.
- Instalador piloto gerado em 2026-10-24: `dist/command-installer/1.1.0-local.20261024.x64/Command-Setup.exe`; PackId `CommandPC`, runtime `win-x64`, Velopack 1.2.161. `flutter build web --release --no-pub` e `dotnet publish ... -r win-x64 --self-contained true` — PASS; manifesto e SHA-256 conferidos. Hash: `ed8c7c3eb0d7253db0b35934c0a8cc96341debe2462f5bc963c3f20291667e10`. Authenticode: `NotSigned`; updater remoto desativado; testes automatizados e instalação em PC físico: `NOT_RUN`. Prerelease privada: [Command Bridge 1.1.0 — Windows x64](https://github.com/playertwo1/Command/releases/tag/command-v1.1.0-local.20261024.x64). O tag aponta para `f36351c`, agora publicado na `main`; o pacote foi construído com alterações locais não commitadas (`sourceWorkingTreeDirty=true`), portanto não é reproduzido exatamente pelo código-fonte do tag.
- Uma tentativa anterior sem `--runtime` foi classificada pelo VPK como x86; não instalar `dist/command-installer/1.1.0-local.20261024/Command-Setup.exe`. O diretório permanece no disco com aviso `INVALID-X86-DO-NOT-INSTALL.txt`; a tentativa de removê-lo foi rejeitada pela política de execução. O SDK temporário também permanece em `%TEMP%\CommandInstallerTask-20261024-adda2c4c87e34dee85c4166da25907e5` após rejeição de limpeza.
- Atualização remota continua desativada. U0.4b e U0.4c foram concluídos e aprovados; U0.4d é a fase ativa.
- APK Android 1.1.1 piloto M1 (2026-10-24): build release local com Flutter 3.47.8 stable no commit `2c9e7eb`; Android `versionName=1.1.1`, `versionCode=12`; SHA-256 `172fa2950d20bda2ed1f83098c5591bce4f690c0cc4bc8a10981e8b55aca3fc7`. `apksigner verify` e `zipalign -c -v 4` — PASS; a impressão digital da assinatura coincide com a versão 1.1.0. Prerelease privada: [Command v1.1.1 — Multi-PC (piloto M1)](https://github.com/playertwo1/Command/releases/tag/command-v1.1.1), com APK, guia e SHA-256 anexados. O workflow do GitHub Actions não iniciou devido ao bloqueio de cobrança/limite da conta; o build foi compilado localmente. Testes automatizados, instalação no emulador, pareamento com duas Bridges físicas e aceite visual: `NOT_RUN`/`PENDING_HUMAN`; M1 continua aberto.
- M0: dois hubs independentes, estado/métricas por PC, reconexão ao retomar e classificação de revogação 401 implementados.
- M1.1: implementação do cartão combinado "Meus 2 PCs" com CPU/RAM/estado e seleção do PC-alvo; validação com dois perfis Command e aceite humano pendentes.
- M1.2: implementação encaminha apps/ações permitidas, rotinas, controles de energia e transferências pelo PC-alvo; confirmações destrutivas identificam o nome do PC e respostas antigas são descartadas ao trocar o alvo. Validação conectada e aceite humano pendentes.
- Editor de captura: fixture PNG de 640×360 torna o gesto de anotação representativo e estável.
- Evidência atual de M1.3: `flutter test -j 1 test/app_catalog_and_jobs_test.dart` — 4 PASS; `flutter build apk --debug --no-pub` — PASS; APK instalado e aberto no AVD `Pixel_9` (API 37, 1080×2424). A tela Status e o filtro `Todos os PCs` renderizam; o histórico aparece indisponível no único perfil salvo, que aponta para a upstream DroidDeckPC, não para uma Bridge Command. Serviços/Top Processos exibem mensagem amigável para HTTP 404. Não houve agregação real entre duas Bridges Command. `flutter analyze` nos dois arquivos tocados reportou 3 diagnósticos `info` já existentes e nenhum erro/warning. Aceite humano: `PENDING_HUMAN`; M1 permanece aberto.
- Atualização de planejamento (2026-10-20): U0.1 registra porte técnico dos erros amigáveis e 174 testes Flutter PASS no roadmap; a revisão documental não reexecutou essa evidência nem o AVD. O erro Dio cru acima pertence à captura anterior ao porte. Aceite do build atual permanece pendente.
- M1.3 avançou em 2026-10-20: feed unificado dos até dois perfis, ordenação temporal, rótulo/filtro por PC e limpeza confirmada com tratamento de falha parcial. Testes de widget cobrem agregação/filtro/cancelamento; no AVD foi verificado apenas o estado de histórico indisponível contra a Bridge upstream.
- ADB do `Pixel_9` foi recuperado por cold boot; `adb devices` reportou `emulator-5554 device`, o APK atual foi instalado e a tela foi aberta. A Bridge DroidDeckPC ativa é upstream, não uma segunda Bridge Command. Não houve pareamento, ação remota, alteração de perfil nem validação de dois PCs.
- Registro 2026-10-22: alterações de M1/U0.4a, roadmap e proveniência upstream foram consolidadas em commit local na `main`; não houve push. As oito capturas em `docs/evidence/v1.5/` foram preservadas apenas localmente porque exibem nome do PC, IP local e detalhes de erro. Não há outras worktrees ou branches locais para limpar; M1 permanece aberto e as validações com duas Bridges e o aceite visual seguem pendentes.
- M1.4 (2026-10-20): implementação técnica concluída. `executeRoutine` envia `deviceId` pelo header `X-Device-Id`; a ação dupla consulta as listas dos dois perfis ativos, exige hubs `Connected`, comparação integral de `toJson()`, confirmação com nomes/passos e apresenta resultados separados sem retry. Testes direcionados `routine_client_test.dart`, `workspace_routines_test.dart` e `app_catalog_and_jobs_test.dart`: 12 PASS; o último emitiu um aviso de toque fora da área visível no teste do filtro. `flutter analyze` terminou com 6 diagnósticos `info` em trechos existentes de `status_page.dart`, sem erros/warnings nem diagnósticos no código M1.4. `flutter build apk --debug --no-pub` — PASS; APK instalado e iniciado no AVD `emulator-5554` (API 37), sem revisão visual. Duas Bridges Command físicas, header chegando ao Bridge e isolamento real de captura: `NOT_RUN`; aceite visual: `PENDING_HUMAN`. Após U0.4a, retomar as validações conectadas antes de fechar M1 e avançar para U0.4b.
- U0.4a (2026-10-21): porte manual do commit `47d15ff2df3f5c4a175ab3c8dc0f91a55eb408ef`; chave do painel por `(id, row, column)` evita reaproveitar rascunho entre botões sem ID. `flutter test -j 1 --no-pub test/stream_deck_desktop_layout_test.dart` — 1 PASS; `flutter build web --no-pub` — PASS. O navegador abriu a saída estática; sem Bridge/perfil/API, a sequência manual em perfil persistido ficou `NOT_RUN`. A origem `app/LICENSE` GPL-3.0 foi verificada no commit exato; URL/SHA registrados em `research/UPSTREAM.md`. Sem commit/push. Próxima ação: checkpoint M1 com duas Bridges físicas; M1 segue aberto.

- Limpeza autorizada do repositório (2026-10-20): removidos intermediários de build, caches Dart/Gradle/.NET e ZIPs redundantes dos SDKs extraídos; preservados APKs debug/release atuais, SDKs extraídos, `dist/` e clone upstream sujo. O espaço livre em C: aumentou 14,34 GiB durante a operação. Build/testes após a limpeza: `NOT_RUN`; dependências removidas precisarão ser restauradas nos próximos builds.

## Planejamento revisado — upstream e instalador (2026-10-20)

- Pedido do proprietário: incorporar a revisão upstream ao roadmap; nesta atividade foram alterados somente documentos, sem implementação, instalação, commit ou publicação.
- Ordem: U0.4a (priorizado e portado em 2026-10-21) → checkpoint M1 + aceite U0.1 → U0.4b/c/d → U0.2a → R → A → D (USB condicional) → T → I → H. `AVALIAR` e backlog v2 não entram automaticamente na execução.
- U0 usa porte seletivo por padrão; checagem textual dos patches não é comprovação de cherry-pick/build. Matriz e respostas em `docs/UPSTREAM_IDEIAS_2026-10-20.md`, seção 4; URL/SHA/licenças em `research/UPSTREAM.md`.
- Hermes: broker HTTP/WS, credenciais/sessões upstream no PC, ticket de uso único e isolamento por dispositivo/PC; Dashboard em loopback, plugin opcional. Sem sudo, shell ou coleta genérica de segredos pelo chat.
- Instalador: prioridade `Command-Setup.exe` usando Velopack existente; corrigir identidade DroidDeck e updater que ainda aponta ao upstream. Entrega local não depende de tornar o repositório público; I0.7 mantém confirmação específica.
- Gate atual continua M1. Testes/build/AVD desta revisão documental: `NOT_RUN`; não houve novo aceite humano. Clone Hermes permanece no SHA antigo até A0.1.

## O que existe hoje
- Repositório Git conectado ao upstream `https://github.com/ggfto/DroidDeck.git` (v1.9.1 / `5cd2ddc`).
- In-tree fork concluído com histórico preservado e mesclado no branch `main`.
- **Pacotes Oficiais v0.6.0 e Documentação de Entrega:**
  - `dist/command-bridge-v0.6.0-win-x64.zip` (SHA-256: `a4b72463b0598d4f57cb54eae3cd2fb7f95cf63ab2a1e6b43337c5ee70c8d3f2`).
  - `dist/command-app-v0.6.0-debug.apk` (SHA-256: `27789ea19d9d9da50d6ebbfc3c7970686ecd26bf869e2cbfa7e1ddef7f01d6f0`).
- **Pacotes Anteriores (v0.3.0, v0.2.0 e v0.1.0):**
  - `dist/command-bridge-v0.3.0-win-x64.zip` / `dist/command-app-v0.3.0-debug.apk`
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

- ID: W4-RELEASE-V0.6.0-AND-ONDAS-V04-V05-V06 (2026-10-18)
  - Execução completa e orquestrada das Ondas v0.4, v0.5 e v0.6 via arquitetura Diretor + Trabalhadores Flash (Gemini 3.8 Flash):
    - **Onda v0.4 (Módulo Hermes IA Opcional):** Backend (`HermesContextSanitizer`, `HermesService`, `HermesController`), Frontend (`HermesConfigSheet`, `HermesAssistantPage`, `QuickCommandBar`). Sanitização estrita de dados privados e validação de allowlist com confirmação humana obrigatória. Suíte: 251 C# / 123 Flutter PASS.
    - **Onda v0.5 (Automação, Perfis e Macros Encadeadas):** Backend (`RoutineService`, `WebhookNotificationService`, `RoutinesController`), Frontend (`WorkspaceRoutinesCard`, `RoutineBuilderPage`). Execução sequencial com delay e HMAC-SHA256. Suíte: 261 C# / 130 Flutter PASS.
    - **Onda v0.6 (Mobilidade Expandida, WoL, Energia e Dock Mode):** Backend (`PowerControlService`, `PowerController` com Win32 `LockWorkStation` e `SetSuspendState`), Frontend (`WakeOnLanService`, `PowerControlCard`, `DockDashboardPage`, `MobileNotificationService`, Android App Shortcuts `shortcuts.xml`). Suíte: 268 C# / 145 Flutter PASS.
  - Suíte consolidada: **268/268 testes C# (.NET 8) PASS**, **145/145 testes Flutter PASS** (Total: **413 testes automatizados PASS**), `flutter analyze --no-fatal-infos` exit 0 (0 erros, 0 avisos).
  - Pacotes Oficiais v0.6.0 gerados em `dist/`:
    - `dist/command-bridge-v0.6.0-win-x64.zip` (SHA-256: `a4b72463b0598d4f57cb54eae3cd2fb7f95cf63ab2a1e6b43337c5ee70c8d3f2`).
    - `dist/command-app-v0.6.0-debug.apk` (SHA-256: `27789ea19d9d9da50d6ebbfc3c7970686ecd26bf869e2cbfa7e1ddef7f01d6f0`).
    - `dist/SHA256SUMS-v0.6.0.txt` gerado e salvo.

## Registro histórico — v1.1.0 (preservado)

O bloco abaixo registra a entrega anterior; o estado ativo e a próxima ação são os do topo deste arquivo e de `ROADMAP_V1.5.md`.

**Atualizado:** 2026-10-18 · **Marco ativo:** Release v1.1.0 (Produção e Configurador Web Integrado) · **Estado:** v1.1.0 CONCLUÍDA COM SUCESSO (100% PASS - 461 testes automatizados)

## O que existe hoje
- Repositório Git conectado ao upstream `https://github.com/ggfto/DroidDeck.git` (v1.9.1 / `5cd2ddc`).
- In-tree fork concluído com histórico preservado e mesclado no branch `main`.
- **Pacotes Oficiais v1.1.0 e Documentação de Entrega:**
  - `dist/command-bridge-v1.1.0-win-x64.zip` (SHA-256: `38e630aabfcde2b1400c0f8717b0c3b590ae3f8a5109b8973b6f1f627dd99aff`).
  - `dist/command-app-v1.1.0.apk` (SHA-256: `56827877a0f2643354578730faa673358a64f08bdc73df829c10e135e7af7be8`).
  - `dist/SHA256SUMS-v1.1.0.txt` gerado e salvo.
- **Correção v1.1.0 (Configurador Web `http://localhost:4787/` — Fix `401 Unauthorized`):**
  - Empacotamento completo de `wwwroot/` (Flutter Web Configurator) no `command-bridge-v1.1.0-win-x64.zip` e inclusão de `<CopyToPublishDirectory>PreserveNewest</CopyToPublishDirectory>` em `DroidDeck.csproj`.
  - Configuração explícita de `UseContentRoot` e `UseWebRoot` em `Program.cs` para resolução determinística do `wwwroot/` mesmo quando o executável é iniciado fora do seu diretório.
  - Detecção automática do SDK Flutter local em `scripts/deploy-web.ps1`.
- **Entregas Principais da Onda v1.0:**
  - **Fase P0 (Permissões Granulares por Dispositivo, Auditoria e Biometria/PIN - D-005):**
    - Backend: `SecurityPolicyService` gerenciando roles (`FullControl` vs `ViewerOnly`), bloqueio de mutações com log de auditoria sanitizado em `SecurityAuditEntryDto`. Controller `/api/security` e `/api/v1/security`.
    - Mobile: `BiometricGuardService` com proteção por PIN/Biometria configurável em memória/preferências antes de ações críticas.
  - **Fase P1 (Backup Criptografado AES-256-GCM + PBKDF2-SHA256):**
    - Backend: `EncryptedBackupService` derivando chave de 256 bits via PBKDF2-SHA256 (100.000 iterações), nonce de 12 bytes, tag GCM de 16 bytes e checksum de integridade SHA-256. Controller `/api/backup/encrypted`.
    - Mobile: `EncryptedBackupSheet` com exportação e importação de envelope JSON com validação de senha e checksum.
  - **Fase P2 (Verificação Segura de Atualizações e Integridade Velopack):**
    - Backend: `UpdateVerificationService` expondo status de release v1.1.0 estável e validação criptográfica de payloads SHA-256. Controller `/api/system/update`.
    - Mobile: `SecurityCenterCard` com consulta de versão, status e validação visual de integridade.
  - **Fase P3 (Autodiagnóstico de Estabilidade e Recursos da Bridge):**
    - Backend: `SystemStabilityMonitor` monitorando WorkingSet RAM, Handles Win32, Threads ativas e Uptime com classificação de saúde (`Healthy`/`Warning`). Endpoint `/api/system/stability`.
  - **Fase P4 (Homologação Final, Pacotes e Maestro E2E):**
    - 301 testes C# (.NET 8) PASS (0 falhas).
    - 160 testes Flutter PASS (0 falhas), `flutter analyze --no-fatal-infos` exit 0 (Total: 461 testes automatizados PASS).
    - Fluxo Maestro `flow_command_v10.yaml` executado no emulador `Pixel_9` com sucesso e evidência capturada em `docs/evidence/v1.0/emulator_v10_status.png`.

## Evidência histórica — release v1.1.0
- `dotnet test tests/DroidDeck.Tests/DroidDeck.Tests.csproj`: 301 PASS, 0 FAIL.
- `flutter test -j 1`: 160 PASS, 0 FAIL.
- `flutter analyze --no-fatal-infos`: exit 0 (0 errors, 0 warnings).
- Maestro E2E (`flow_command_v10.yaml`): 100% COMPLETED no emulador Pixel 9.

## Próxima ação
- **Onda v1.5 APROVADA (2026-10-19)** — plano em `ROADMAP_V1.5.md`. M0 concluído; M1.1/M1.2 implementados. Revisão visual offline no AVD realizada; validação conectada e aceite humano ainda pendentes. Repositório segue privado até a fase I0.
- Versão de Produção v1.1.0 consolidada, homologada e publicada no GitHub (`command-v1.1.0`).

## Bloqueios e aprovações humanas
- Push remoto e publicação da release v1.1.0: AUTORIZADO pelo proprietário.
- Release v1.1.0: 100% CONCLUÍDA com sucesso.

## Progresso v1.5 — 2026-10-20
- M0.1 concluído anteriormente; worktree estava limpo antes desta continuação.
- M0.2 e M0.3 concluídos: UI por PC, classificação de falha de autenticação 401 como revogado, registro de última telemetria e CPU/RAM por hub; ciclo Flutter suspende os dois hubs em background e os reabre ao retomar, preservando o teto de duas conexões.
- Validação: `test/pc_connections_test.dart` 9/9 PASS; a suíte completa oscilou — uma execução deu 169 PASS, duas deram 168 PASS e falharam em `screenshot_editor_test.dart` (anotação/desfazer); esse arquivo isolado passou 2/2. `dart analyze` dos cinco arquivos alterados exit 0, com três infos antigas em `ConfigPage`.
- Continuação M1.1/M1.2: implementados painel de dois PCs, seletor de alvo e roteamento por perfil para apps, rotinas, energia e transferências; alvo aparece nas telas/confirmações críticas.
- Fixture do `screenshot_editor_test.dart` agora é um PNG real de 640×360; o teste completo da suíte passou após essa correção.
- Testes: `flutter test -j 1` — 170/170 PASS; `flutter analyze --no-fatal-infos` — exit 0, sem erros/avisos (67 infos preexistentes).
- Revisão visual inicial (antes de U0.1): executada no AVD `Pixel_9` (API 37, 1080×2424), somente no estado desconectado. Os cartões e rótulos do PC-alvo renderizaram; Serviços e Top Processos ainda mostravam exceções Dio completas. Essa captura é histórica; métricas ao vivo, segundo perfil e diálogos de confirmação ficaram `NOT_RUN`; aceite humano `PENDING_HUMAN`.
- Complemento 2026-10-20: U0.1 registrou o porte de mensagens amigáveis e 174 testes PASS (não reexecutados nesta continuação). M1.3 consolida e filtra atividade por PC; teste direcionado 4/4 PASS. Uma tentativa anterior de iniciar o AVD ficou `offline` e não instalou o APK; a tentativa posterior e bem-sucedida está registrada no estado atual no topo.
- Próxima ação registrada antes da priorização mais recente: disponibilizar dois perfis apontando a Bridges Command e validar isolamento, troca de alvo, revogação, confirmação destrutiva e histórico unificado; registrar evidência sanitizada e obter aceite humano. A direção atual — revisar M1.4 antes dessas validações — está registrada no topo deste arquivo.

## 2026-10-20 — U0.1 portado (DroidDeck b4647a6)
- `friendlyPcError` em `app/lib/src/home/status_page.dart`: Serviços e Top Processos do painel M1 mostram orientação (sem rede / 401 repareie / 403 / erro do corpo) em vez da exceção Dio crua.
- Textos de pareamento do upstream em `home_page.dart` e `config_page.dart` + traduções EN.
- `flutter test`: 174 PASS (inclui `test/friendly_pc_error_test.dart`); `flutter analyze`: só infos pré-existentes. Aceite visual no AVD: `NOT_RUN`.
