# WATCHDOG — guardião de execução

> Origem: [playertwo1/ideias_standard](https://github.com/playertwo1/ideias_standard) (`template/docs/WATCHDOG.md`) adaptado ao **Command**.
> O que já é regra no `AGENTS.md` ou gate no `docs/RELEASE_CHECKLIST.md` permanece como referência central. Sem marcadores a preencher.

Leia antes de mudança média, grande ou arriscada (`AGENTS.md`, regra 4). Objetivo: dar autonomia ao agente sem deixá-lo sair do escopo, quebrar o que existe ou tomar decisões perigosas sem perceber.

**READ → UNDERSTAND → PLAN → CHANGE → TEST → AUDIT → FINISH.**  
*Nunca: ASSUME → CHANGE EVERYTHING → HOPE IT WORKS.*

---

## 1. Antes de alterar
1. Entenda o pedido atual e examine o estado real do projeto (`STATE.md`, `ROADMAP_V1.5.md`, `git status`, código relacionado).
2. Identifique os arquivos envolvidos e o que depende deles (chamadas, serviços, testes, contratos).
3. Faça só o necessário para o objetivo; valide antes de declarar concluído.

Suposição não é fato. Se documentação e código divergirem, investigue antes de alterar e registre em `STATE.md`.

## 2. Hierarquia de decisão
Em conflito, respeite esta ordem:
1. Pedido explícito do usuário.
2. `AGENTS.md` do Command.
3. Este arquivo (`WATCHDOG.md`).
4. Documentação do projeto (`PROJECT.md`, `DESIGN.md`, `docs/DECISIONS.md`).
5. Arquitetura e padrões existentes no repositório.
6. Julgamento técnico do agente.

Silêncio nunca autoriza mudança destrutiva ou expansão de escopo.

## 3. Escopo e anti-drift
Não aproveite a tarefa para:
- Reescrever partes não relacionadas;
- Trocar arquitetura, dependências ou bibliotecas sem necessidade;
- Adicionar ou remover endpoints de controle ou regras de segurança;
- Reorganizar pastas do projeto arbitrariamente;
- Adicionar funcionalidades extras que ninguém pediu ("para o futuro");
- Transformar uma correção pontual em reconstrução de tela ou serviço.

Melhorias percebidas no caminho viram sugestão no handoff ou linha de Ideias no roadmap, **nunca código**. Primeiro termine com precisão o que foi pedido.

Na dúvida entre (A) mudança ampla baseada em suposição e (B) preservar o estado atual, escolha (B) e investigue.

## 4. Proteção contra regressão
Antes de alterar código existente, pergunte:
- O que depende disso? Pode quebrar outro fluxo do celular ou do PC?
- Estou alterando contratos de API tipados, DTOs, schemas de eventos ou preferências salvas?
- Existe solução menos invasiva com menos linhas de diff?

Prefira mudanças pequenas, pontuais, incrementais e fáceis de reverter.

## 5. Ações de alto risco
Exigem confirmação explícita prévia do usuário:
- Apagar arquivos de código, configurações ou dados de banco/perfis;
- Alterar política de segurança de portas, tokens ou allowlist de aplicativos;
- Adicionar endpoints com execução de código arbitrário ou terminal/shell (estritamente proibido pelo projeto);
- Mexer em rotinas criptográficas (AES-256-GCM, DPAPI, PBKDF2);
- Comandos destrutivos no sistema do usuário;
- `git push --force` ou reescrita de histórico;
- Remoção em massa de código existente ou de testes.

## 6. Não esconda problemas
Proibido fazer o sistema "parecer funcionar" com:
- Falsos sucessos ou mocks disfarçados em fluxos de produção;
- Erros capturados e silenciados (`catch (_) {}`) sem registro adequado;
- Validações de segurança, certificados ou integridade afrouxadas;
- Asserções de teste modificadas apenas para fazer o teste passar verde. Corrija a causa raiz.

## 7. Loop de erro
Após 3 tentativas com falhas similares, pare de tentar variações cegas:
- Releia o erro detalhado e a stack trace;
- Reavalie a hipótese inicial e procure a causa raiz real no código conectado;
- Se continuar bloqueado, registre o diagnóstico e a pendência em `STATE.md`.

## 8. Preserve o trabalho existente
Antes de qualquer alteração, confira `git status` e separe as mudanças da tarefa anterior das novas. Não reverta nem sobrescreva modificações locais feitas pelo usuário.

## 9. Dependências
Zero dependências novas desnecessárias. Use o que a biblioteca padrão (.NET BCL / Dart Core) ou os pacotes já instalados oferecem.

## 10. Regra de parada
Se surgir decisão irreversível, destrutiva, arquiteturalmente crítica, incompatível com o pedido ou de risco de segurança: **pare antes de executar**, explique o que encontrou, o risco, as opções e a recomendação técnica.

---
*Autônomo na execução. Conservador nas mudanças. Cético com suposições. Rigoroso na validação. Transparente na incerteza.*
