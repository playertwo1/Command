# Checklist de gates e aceite

O `ROADMAP.md` contém o escopo e os critérios detalhados de F0–F9. Este arquivo registra resultados técnicos separados da aprovação humana. `NOT_RUN` nunca significa `PASS`.

## F0 — escolha das bases
- [ ] URLs, commits SHA, datas e licenças dos candidatos registrados.
- [ ] Builds pertinentes reproduzidos em isolamento, com comandos e resultados guardados em `docs/evidence/F0/`.
- [ ] ADR-001 (Android), ADR-002 (Bridge) e matriz de APIs concluídas.
- Resultado técnico: **NOT_RUN** · Aprovação humana das bases: **PENDING**.

## F1–F8 — implementação e preparação do piloto
Critérios e cenários de cada fase estão em `ROADMAP.md`. Registrar a evidência em `docs/evidence/Fn/`; não avançar com critério obrigatório pendente.

| Fase | Entrega | Técnico | Evidência |
|---|---|---|---|
| F1 | Builds reproduzíveis + contrato v1 + `SECURITY.md` | NOT_RUN | — |
| F2 | Pareamento, autenticação e revogação | NOT_RUN | — |
| F3 | Telemetria real no aparelho | NOT_RUN | — |
| F4 | FL-1, FL-2, FL-5 + Atividade | NOT_RUN | — |
| F5 | FL-3 screenshot | NOT_RUN | — |
| F6 | FL-4 transferência íntegra | NOT_RUN | — |
| F7 | Revisão independente sem achado crítico/alto | NOT_RUN | — |
| F8 | Instalação repetível + cinco fluxos sem Hermes | NOT_RUN | — |

- Nunca aprovar implementação com credenciais expostas, shell arbitrário, arquivos fora das raízes autorizadas ou dependência de Hermes para controle direto.

## F9 — piloto e decisão do MVP
- [ ] Sete dias corridos e pelo menos 30 execuções, com no mínimo seis por fluxo (FL-1…FL-5).
- [ ] Taxa de sucesso, falhas críticas, integridade, duplicação e privacidade avaliadas.
- [ ] Hermes ausente/desligado durante os cinco fluxos diretos.
- [ ] Evidências reunidas em `docs/MVP_APPROVAL.md`.
- Resultado técnico: **NOT_RUN** · Aprovação humana do MVP: **PENDING**.

## Critérios visuais
- [ ] Capturas do app real comparadas com `DESIGN.md` e as referências Stitch.
- [ ] Estados offline, erro, carregamento, confirmação e sucesso final conferidos.
- [ ] Acessibilidade, contraste e alvos de toque verificados.
- Aceite visual humano: **PENDING** até F7.
