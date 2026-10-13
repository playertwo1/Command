# AGENTS.md — Command

Contrato curto para Codex, Claude, Gemini e outros agentes. Comece por `STATE.md`; abra apenas os documentos necessários à tarefa.

## Fontes de verdade
- `STATE.md` — estado atual e próxima ação.
- `ROADMAP.md` — escopo aprovado, ordem e critérios detalhados.
- `PROJECT.md` — visão, MVP e exclusões.
- `DESIGN.md` — referência visual; ler antes de qualquer trabalho de interface.
- `docs/DECISIONS.md` — decisões e pendências.
- `docs/RELEASE_CHECKLIST.md` — evidência técnica e aceite.

## Regras do projeto
1. Execute apenas a fase ativa do `ROADMAP.md`. Não implemente componentes de produção antes de concluir F0 e receber aprovação humana das bases escolhidas.
2. Hermes é opcional. O controle direto do PC deve funcionar sem IA.
3. Não crie endpoint de shell ou execução arbitrária. Ações do PC precisam de IDs, parâmetros tipados, allowlist e confirmação adequada.
4. Pareamento deve ser explícito, revogável e temporário. O token temporário pode aparecer somente no fluxo local autorizado no PC; nunca registre credenciais persistentes, tokens ou dados privados em logs ou evidências.
5. Não contorne bloqueio de sessão, UAC ou limitações do Windows para capturar tela ou iniciar apps.
6. Transferências ficam restritas às pastas autorizadas, com validação de caminho, limite e integridade.
7. Preserve os documentos de origem e as alterações de outras pessoas. Não altere repositórios upstream durante a pesquisa.
8. Distinga fato verificado, hipótese e proposta. Registre licença, URL, SHA e data antes de copiar código de terceiros.
9. `NOT_RUN` nunca é `PASS`; teste, build, execução em dispositivo e aceite visual precisam de evidência atual.
10. Não faça commit, push ou publicação sem pedido explícito. Atualize `STATE.md` ao encerrar trabalho relevante.

## Comandos
- Instalar/rodar/verificar: ainda não definidos; determinar após escolha da base em F0.

## Git
O projeto está conectado ao repositório GitHub privado `playertwo1/Command`. Commits e push continuam exigindo autorização explícita do proprietário.
