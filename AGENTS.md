# AGENTS.md — Command

Contrato curto para Codex, Claude, Gemini e outros agentes. Comece por `STATE.md`; abra apenas os documentos necessários à tarefa.

## Fontes de verdade
- `STATE.md` — estado atual e próxima ação.
- `ROADMAP_V1.5.md` — escopo ativo aprovado, ordem e critérios detalhados.
- `ROADMAP.md` — histórico do MVP v0.x.
- `PROJECT.md` — visão, MVP e exclusões.
- `docs/MANUAL_MVP.md` — transcrição do manual original (`.docx`), incluindo catálogo de repositórios e ideias pós-MVP.
- `DESIGN.md` — referência visual; ler antes de qualquer trabalho de interface.
- `docs/DECISIONS.md` — decisões e pendências.
- `docs/RELEASE_CHECKLIST.md` — evidência técnica e aceite.

## Regras do projeto
1. Execute apenas a fase ativa de `ROADMAP_V1.5.md`; `ROADMAP.md` é histórico do MVP v0.x. Não implemente componentes de produção antes de concluir F0 e receber aprovação humana das bases escolhidas.
2. O controle direto do PC não depende de serviços de IA ou de terceiros.
3. Não crie endpoint de shell ou execução arbitrária. Ações do PC precisam de IDs, parâmetros tipados, allowlist e confirmação adequada.
4. Pareamento deve ser explícito, revogável e temporário. O token temporário pode aparecer somente no fluxo local autorizado no PC; nunca registre credenciais persistentes, tokens ou dados privados em logs ou evidências.
5. Não contorne bloqueio de sessão, UAC ou limitações do Windows para capturar tela ou iniciar apps.
6. Transferências ficam restritas às pastas autorizadas, com validação de caminho, limite e integridade.
7. Preserve os documentos de origem e as alterações de outras pessoas. Não altere repositórios upstream durante a pesquisa.
8. Distinga fato verificado, hipótese e proposta. Registre licença, URL, SHA e data antes de copiar código de terceiros.
9. `NOT_RUN` nunca é `PASS`; teste, build, execução em dispositivo e aceite visual precisam de evidência atual.
10. Não faça commit, push ou publicação sem pedido explícito. Atualize `STATE.md` ao encerrar trabalho relevante.

## Comandos e Ferramentas Locais
- **.NET 8 SDK:** `c:\Users\notefael\projetos\Command\research\upstream\.tools\dotnet-8.0.426\dotnet.exe`
- **Flutter SDK:** `c:\Users\notefael\projetos\Command\research\upstream\.tools\flutter\bin\flutter.bat`

## Orquestração no Antigravity (Diretor + Flash Worker)
Consulte a skill global [`director-flash-orchestrator`](file:///C:/Users/notefael/.gemini/config/skills/director-flash-orchestrator/SKILL.md).
- **Agente Principal (Diretor):** Pensa, planeja, define contratos/assinaturas exatas, alinha com o usuário, integra pontos críticos, atualiza `STATE.md`/`ROADMAP*.md`/Vault e executa tarefas pequenas direto.
- **Subagentes (`Model: "flash"` — Gemini 3.8 Flash):** Trabalhadores econômicos para código volumoso, services, telas e suítes de testes.
- **Gate de Delegação (só delegue se TODAS forem SIM):**
  1. Exigiria >6 chamadas de ferramenta ou escrita de múltiplos arquivos/testes extensos;
  2. O contrato técnico já está 100% mastigado pelo Diretor (sem ambiguidade de arquitetura);
  3. Escopo de arquivos isolado (máx. 2 agentes simultâneos, ex: 1 Backend C# e 1 Mobile Dart, zero arquivo compartilhado ao mesmo tempo);
  4. Resultado verificável por comando objetivo (`dotnet test`, `flutter test`, `flutter analyze`).
- **Antes de delegar:** Registre em 1 linha a justificativa e o ownership de arquivos. Reutilize o mesmo subagente via `send_message` na mesma frente. Exija retorno de no máximo 8 linhas (`STATUS | arquivos | validação | pendências`, sem diffs/logs longos).

## Emulador Android
- Iniciar: `powershell -File $env:USERPROFILE\scripts\emu.ps1 start`; parar ao terminar: `... stop`.
- Usar o MCP `maestro` para interagir com o app.
- Preferir ler a hierarquia de UI (texto) a screenshots; screenshot só para validar layout visual.
- Não abrir o Android Studio; build e execução pelo terminal: `flutter run` (instala e roda no emulador ligado) ou `flutter build apk --debug` (só gera o APK).
- Logs: `adb logcat -d *:E` (só erros), nunca logcat contínuo.
- Fluxos repetidos viram arquivos `.maestro/*.yaml` e são executados com `maestro test`.

## Git
O projeto está conectado ao repositório GitHub privado `playertwo1/Command`. Commits e push continuam exigindo autorização explícita do proprietário.
