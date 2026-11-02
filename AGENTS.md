# AGENTS.md — Command

Contrato curto para Codex, Claude, Gemini e outros agentes. Comece por `STATE.md`; abra apenas os documentos necessários à tarefa.

## Fontes de verdade
- `STATE.md` — estado atual e próxima ação.
- `ROADMAP_V1.5.md` — escopo ativo aprovado, ordem e critérios detalhados.
- `ROADMAP.md` — histórico e visão geral de marcos do projeto.
- `PROJECT.md` — visão, MVP e exclusões.
- `DESIGN.md` — referência visual; ler antes de qualquer trabalho de interface.
- `docs/DECISIONS.md` — decisões e pendências.
- `docs/RELEASE_CHECKLIST.md` — evidência técnica e aceite.
- `docs/WATCHDOG.md` — escopo, anti-drift, ações de alto risco e regra de parada.
- `docs/AUDIT.md` — auditoria final independente antes de declarar `DONE`.

## Comandos e Ferramentas Locais
- **.NET 8 SDK:** `c:\Users\notefael\projetos\Command\research\upstream\.tools\dotnet-8.0.426\dotnet.exe`
- **Flutter SDK:** `c:\Users\notefael\projetos\Command\research\upstream\.tools\flutter\bin\flutter.bat`
- **Checar Governança (Ideias Standard):** `python scripts/check.py . --strict`

## Regras do projeto
1. Execute apenas a fase ativa de `ROADMAP_V1.5.md`. Não implemente componentes fora do escopo aprovado.
2. O controle direto do PC não depende de serviços de IA ou de terceiros.
3. Não crie endpoint de shell ou execução arbitrária. Ações do PC precisam de IDs, parâmetros tipados, allowlist e confirmação adequada.
4. Pareamento deve ser explícito, revogável e temporário. O token temporário pode aparecer somente no fluxo local autorizado no PC; nunca registre credenciais persistentes, tokens ou dados privados em logs ou evidências.
5. Não contorne bloqueio de sessão, UAC ou limitações do Windows para capturar tela ou iniciar apps.
6. Transferências ficam restritas às pastas autorizadas, com validação de caminho, limite e integridade.
7. Preserve os documentos de origem e as alterações de outras pessoas. Não altere repositórios upstream durante a pesquisa.
8. Distinga fato verificado, hipótese e proposta. Registre licença, URL, SHA e data antes de copiar código de terceiros.
9. `NOT_RUN` nunca é `PASS`; teste, build, execução em dispositivo e aceite visual precisam de evidência atual.
10. Não faça commit, push ou publicação sem pedido explícito. Atualize `STATE.md` ao encerrar trabalho relevante.

## Orquestração no Antigravity (Diretor + Flash Worker)
Consulte a skill global [`director-flash-orchestrator`](file:///C:/Users/notefael/.gemini/config/skills/director-flash-orchestrator/SKILL.md).
- **Agente Principal (Diretor):** Pensa, planeja, define contratos/assinaturas exatas, alinha com o usuário, integra pontos críticos, atualiza `STATE.md`/`ROADMAP*.md`/Vault e executa tarefas pequenas direto.
- **Subagentes (`Model: "flash"` — Gemini 3.8 Flash):** Trabalhadores econômicos para código volumoso, services, telas e suítes de testes.
- **Gate de Delegação:** Somente para tarefas com >6 chamadas ou código volumoso, contrato 100% definido, arquivos isolados e retorno conciso (máx. 8 linhas).

## Emulador Android
- Iniciar: `powershell -File $env:USERPROFILE\scripts\emu.ps1 start`; parar ao terminar: `... stop`.
- Usar o MCP `maestro` para interagir com o app; preferir ler a hierarquia de UI (texto) a screenshots.
- Build/execução: `flutter run` ou `flutter build apk --debug`. Logs: `adb logcat -d *:E` (só erros).

## Git
O projeto está conectado ao repositório GitHub privado `playertwo1/Command`. Commits e push continuam exigindo autorização explícita do proprietário.
