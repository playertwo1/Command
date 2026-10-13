# Checklist de gates e aceite

O `ROADMAP.md` contém o escopo e os critérios detalhados de F0–F9. Este arquivo registra resultados técnicos separados da aprovação humana. `NOT_RUN` nunca significa `PASS`.

## F0 — escolha das bases
- [ ] URLs, commits SHA, datas e licenças dos candidatos registrados.
- [ ] Builds pertinentes reproduzidos em isolamento, com comandos e resultados guardados em `docs/evidence/F0/`.
- [ ] ADR-001 (Android), ADR-002 (Bridge) e matriz de APIs concluídas.
- Resultado técnico: **NOT_RUN** · Aprovação humana das bases: **PENDING**.

## F1–F8 — implementação e preparação do piloto
- Critérios, tarefas e verificações estão descritos por fase em `ROADMAP.md`.
- Registrar evidência de cada gate; não avançar com critérios obrigatórios pendentes.
- Nunca aprovar implementação com credenciais expostas, shell arbitrário, arquivos fora das raízes autorizadas ou dependência de Hermes para controle direto.

## F9 — piloto e decisão do MVP
- [ ] Sete dias corridos e pelo menos 30 execuções, com no mínimo seis por fluxo.
- [ ] Taxa de sucesso, falhas críticas, integridade, duplicação e privacidade avaliadas.
- [ ] Hermes ausente/desligado durante os cinco fluxos diretos.
- [ ] Evidências reunidas em `docs/MVP_APPROVAL.md`.
- Resultado técnico: **NOT_RUN** · Aprovação humana do MVP: **PENDING**.

## Critérios visuais
- [ ] Capturas do app real comparadas com `DESIGN.md` e as referências Stitch.
- [ ] Estados offline, erro, carregamento, confirmação e sucesso final conferidos.
- [ ] Acessibilidade, contraste e alvos de toque verificados.
- Aceite visual humano: **PENDING** até F7.
