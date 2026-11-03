# STATE — ponto de retomada

**Atualizado:** 2026-11-03 · **Marco ativo:** Onda v1.6 (release 1.6.1) · **Estado:** IN_PROGRESS

## CI
- O push da 1.6.1 falhou no analyzer (`223e2e1`). O CI seguinte passou no analyzer e falhou em `screenshot_editor_test`: o arrasto no centro do canvas não acertava o detector. O canvas de anotação agora preenche a área e recebe o gesto.

## O que funciona hoje (confirmado no código)
- **Ambientes & Rotinas Customizáveis (Fase R4):** Exclusão e customização desbloqueadas para qualquer rotina (incluindo os 3 presets de fábrica); persistência automática das rotinas no PC em `%AppData%\Command\routines.json`; construtor de rotinas expandido com catálogo dinâmico de aplicativos autorizados, atalhos do teclado (`system.shortcut`), controle multimídia (`media.control`), energia (`power.action`) e pausas configuráveis (`delay`); menu de contexto no app móvel com opções de Editar, Duplicar e Excluir (com confirmação explícita).
- **Desktop Remoto Integrado (Fase R3):** Captura Full-DPI nativa sem cortes via Win32 `GetDeviceCaps` (`DESKTOPHORZRES`/`DESKTOPVERTRES`), vídeo MJPEG ao vivo embutido no fundo do Trackpad e Teclado remoto no celular, com modo híbrido (`Trackpad Relativo` vs `Toque Direto` com coordenadas normalizadas e ripple visual), pausa de vídeo para economia de banda/bateria e atalhos rápidos de teclado.
- **Identidade Visual Android Oficial (Release v1.6.0):** Nome e rotulagem "Command" em 100% dos manifests, strings e packaging; ícone adaptativo Amethyst (`#13101B`, `#1E1829`, `#A78BFA`) gerado para todas as densidades de tela (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi) a partir do `logo.png` oficial; instalador Windows `Command-Setup.exe` v1.6.0 e APK release sincronizados.
- **Multi-PC Simultâneo:** Monitoramento paralelo, alternância transparente e execução de rotinas e ações direcionadas para até dois PCs salvos.
- **Dashboard (Fase C0):** A StatusPage não mostra mais o card "Ações Autorizadas" e não busca o catálogo de apps ao abrir. O catálogo continua no Stream Deck e nas rotinas. Encerrar um app pelo comando rápido ainda pede confirmação.
- **Controle de Energia (Fase W2):** Bloquear, suspender, desligar e reiniciar no card do app, com confirmação explícita. Desligar e reiniciar usam `ExitWindowsEx` e `SeShutdownPrivilege`. Wake-on-LAN e Modo Dock continuam no mesmo card. Rotinas seguem limitadas a bloquear e suspender.
- **Temperatura (Fase T1):** A leitura tenta LibreHardwareMonitor e, se faltar CPU ou GPU, usa a zona ACPI (WMI) e o driver da placa (NVAPI ou ADL), sem pedir admin. Amostra a cada 3 s. O card "Meus 2 PCs" mostra CPU e GPU com verde até 60°C, âmbar até 80°C e vermelho acima. Acima de 85°C o card avisa e o banner de saúde continua crítico. O botão de temperatura do deck usa o mesmo valor.
- **Stream Deck (Fase K0):** Cor HEX com opacidade, ícones por categoria, PNG/SVG/GIF, rótulo de 8–18 px com alinhamento e opção de ocultar, cantos, borda e vibração. Grade fixa 2–8 × 2–6, espaço 4–24, margem, fundo em cor, gradiente ou imagem. Widgets de CPU, RAM, GPU, temperatura, relógio e faixa em reprodução com play/pausa e faixa. No celular dá para gravar atalho da allowlist (`Ctrl+C`, `Win+D`) e app do catálogo. Caminho livre de programa, janela e HTTP continuam só no configurador do PC.
- **Stream Deck:** Grades dinâmicas de botões com ações do sistema, controle de volume de áudio por dispositivo, lançamento de aplicativos autorizados e telemetria básica.
- **Transferência Segura de Arquivos:** Envio e recebimento restritos a pastas autorizadas, validação de integridade por hash SHA-256 e suporte a transferências retomáveis.

## Última atividade
- **Fase T1 concluída:**
  - [`HardwareSensorProvider.cs`](file:///c:/Users/notefael/projetos/Command/DroidDeck/Services/HardwareSensorProvider.cs) completa a leitura com ACPI, NVAPI e ADL. [`pc_dashboard_card.dart`](file:///c:/Users/notefael/projetos/Command/app/lib/src/home/pc_dashboard_card.dart) mostra as duas temperaturas.
  - Testes: `dotnet test` 405/405 PASS; `flutter test` 259/259 PASS. Leitura confirmada numa máquina física: `NOT_RUN`.
- **Fase K0 concluída:**
  - Visual do botão, fundo do perfil e widgets vivos no app. Atalho remoto só passa se `KeyAllowlist` aceitar a tecla; `catalog_app` segue sem caminho livre.
  - Testes: `dotnet test` 403/403 PASS; `flutter test` 258/258 PASS.
- **Fase C0 concluída e início da K0:**
  - Removido o card e o ciclo `getApps()` da [`status_page.dart`](file:///c:/Users/notefael/projetos/Command/app/lib/src/home/status_page.dart). `AppCatalogService` e os endpoints permanecem.
  - Editor do deck: campo HEX e opacidade. Perfil: `useCustomGrid` com limites 2–8 × 2–6, no app e em `DeckProfile`.
  - Testes desta rodada: `dotnet test` 402/402 PASS; testes Flutter dos arquivos tocados PASS (`deck_models_test`, `app_catalog_and_jobs_test`, `fault_tolerance_and_visual_test`). Suíte Flutter inteira desta rodada: `NOT_RUN`. Análise dos arquivos tocados: 0 erros e 0 warnings; os `info` listados já existiam.
- **Fase W2 concluída:**
  - Backend: [`PowerControlService.cs`](file:///c:/Users/notefael/projetos/Command/DroidDeck/Services/PowerControlService.cs) aceita `shutdown` e `restart` só com `confirmed: true`, audita `system.shutdown` / `system.restart` no `JobHistoryService` e chama `WindowsProvider.TryExitWindows` quando a Bridge está em execução nativa. [`PowerController.cs`](file:///c:/Users/notefael/projetos/Command/DroidDeck/Controllers/PowerController.cs) ganhou `POST /api/power/shutdown` e `POST /api/power/restart`. A Bridge liga `AllowNativeExecution`; os testes unitários continuam simulados.
  - Mobile: [`power_control_card.dart`](file:///c:/Users/notefael/projetos/Command/app/lib/src/power/power_control_card.dart) tem "Desligar PC" e "Reiniciar PC". O diálogo nomeia o PC-alvo e avisa que a sessão será encerrada.
  - Testes desta rodada: `dotnet test` 402/402 PASS; `flutter test` 253/253 PASS; `flutter analyze` nos três arquivos Dart tocados sem issues. A análise do app inteiro segue com 74 `info` pré-existentes, 0 erros e 0 warnings. `python scripts/check.py . --strict` PASS (0 falhas, 0 avisos). Desligar ou reiniciar um PC real: `NOT_RUN`.
- **Fase R4 concluída:**
  - Backend: [`RoutinesController.cs`](file:///c:/Users/notefael/projetos/Command/DroidDeck/Controllers/RoutinesController.cs) e [`RoutineService.cs`](file:///c:/Users/notefael/projetos/Command/DroidDeck/Services/RoutineService.cs) atualizados permitindo exclusão e edição de qualquer rotina (inclusive presets padrão), persistência de rotinas no disco (`routines.json`) e expansão de ações permitidas (`system.shortcut`, `media.control`, `power.action`).
  - Mobile: [`routine_builder_page.dart`](file:///c:/Users/notefael/projetos/Command/app/lib/src/routines/routine_builder_page.dart) com catálogo dinâmico de apps, atalhos predefinidos e customizados, ações multimídia e de energia; [`workspace_routines_card.dart`](file:///c:/Users/notefael/projetos/Command/app/lib/src/routines/workspace_routines_card.dart) com menu popup (Editar, Duplicar, Excluir com diálogo de confirmação).
  - Identidade Android: Geração de todos os ícones `ic_launcher` e `ic_launcher_foreground` a partir de `logo.png`, eliminando o ícone padrão do Flutter no instalador do Android.
  - Testes: Suíte C# atualizada com 400/400 testes PASS (`RoutineServiceTests` e `ScreenStreamSpikeTests`), testes Flutter com 8/8 PASS em `workspace_routines_test.dart`, `flutter analyze` 0 erros/avisos, e governança `python scripts/check.py . --strict` com 0 falhas e 0 avisos.

## Próxima ação
- **H0 concluída** por confirmação humana do proprietário (2026-11-03), sem logs detalhados anexados. Próximo: I0.1 (varredura de segredos no histórico) e, só depois, decisão sobre I0.7 (repo público).
- Itens `AVALIAR` e a onda v2.0 continuam fora de implementação até uma decisão explícita.

## Bloqueios e aprovações humanas
- Nenhum bloqueio técnico. Homologação física dos dois PCs reais: confirmada pelo proprietário em 2026-11-03.

## Divergências entre roadmap e implementação
- Nenhuma divergência ativa no escopo v1.6.

---

## Histórico consolidado de marcos anteriores
- **v1.6.0 (2026-11-02):** Release oficial com identidade visual Command completa no Android e no Windows; publicação no GitHub; 399 testes C# e 247 testes Flutter PASS.
- **v1.5.0 (2026-10-26):** Publicada no GitHub (`tag: command-v1.5.0`); consolidação de Multi-PC paralelo, controle remoto de mouse/teclado e transferências de arquivos retomáveis.
- **v1.1.2 (2026-10-25):** Correção de sincronização reativa e recuperação dos dois perfis pareados; 100% funcional nos dois PCs físicos.
- **v1.0.0 (2026-10-20):** Permissões granulares por dispositivo, backup criptografado AES-256-GCM, instalador Velopack e auto-diagnóstico de estabilidade.
- **v0.1–v0.6 (2026-10-12 a 2026-10-20):** MVP inicial, telemetria em tempo real, screenshots manuais, catálogo de apps autorizados e rotinas locais. Documentos detalhados em `docs/history/`.
