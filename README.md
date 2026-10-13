# Command

Aplicativo Android e Bridge Windows para controlar um PC pessoal por ações explícitas, com Hermes como módulo de IA opcional.

## Estado atual

O roadmap do MVP v0.1 foi aprovado e o projeto inicia **F0 — escolha de bases e preparação técnica**. Esta pasta contém o planejamento, referências visuais e estrutura inicial; ainda não há aplicativo ou Bridge implementados. Consulte [STATE.md](STATE.md) para a próxima ação e [ROADMAP.md](ROADMAP.md) para a sequência oficial.

## Comece por aqui

| Pergunta | Arquivo |
|---|---|
| Onde paramos e qual é a próxima ação? | [STATE.md](STATE.md) |
| Qual é o produto e o que fica fora do MVP? | [PROJECT.md](PROJECT.md) |
| Quais são os gates e a sequência aprovada? | [ROADMAP.md](ROADMAP.md) |
| Qual é a referência visual do Android? | [DESIGN.md](DESIGN.md) e [referências do Stitch](references/stitch/README.md) |
| Quais decisões ainda faltam? | [docs/DECISIONS.md](docs/DECISIONS.md) |
| Como registrar evidência e aceite? | [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) |
| Quais regras os agentes seguem? | [AGENTS.md](AGENTS.md) (`CLAUDE.md` importa este arquivo) |

## Documentos de origem

- [Manual do MVP](COMMAND_Manual_MVP.docx) — visão e requisitos iniciais; [transcrição em Markdown](docs/MANUAL_MVP.md) para leitura por agentes.
- [Roadmap original](docs/history/ROADMAP-2026-10-10-original.md) — preservado como histórico.
- [Plano aprovado](docs/plans/2026-10-12-mvp-inicial.md) — texto exato aprovado em 2026-10-12 (não editar; mudanças vão para `ROADMAP.md`).

A estrutura documental foi adaptada manualmente do kit [`ideias_standard`](https://github.com/playertwo1/ideias_standard); o exemplo de Command desse repositório descreve um escopo anterior e não foi copiado por cima dos documentos atuais.

## Estrutura

```text
apps/android/          app Kotlin/Compose (F1 após decisão F0)
apps/windows-bridge/   Bridge C#/.NET (F1 após decisão F0)
contracts/             contratos versionados da API (F1)
docs/adr/              decisões de base e arquitetura (F0)
docs/evidence/         evidências reproduzíveis dos gates
references/stitch/     capturas de referência do projeto visual
research/upstream/     checkout temporário de candidatos; não versionar código upstream
tests/                 testes de contrato, integração e segurança (F1+)
```

## Como rodar e verificar

Ainda não há comandos de instalação, execução ou verificação: a stack e a base dos componentes serão confirmadas em F0. Não declare build ou testes aprovados antes de executar os comandos reais definidos após essa decisão.
