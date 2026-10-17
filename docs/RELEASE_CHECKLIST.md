# Checklist de gates e aceite

O `ROADMAP.md` contém o escopo e os critérios detalhados de F0–F9. Este arquivo registra resultados técnicos separados da aprovação humana. `NOT_RUN` nunca significa `PASS`.

## F0 — escolha das bases
- [x] URLs, commits SHA, datas e licenças dos candidatos registrados.
- [x] Builds pertinentes reproduzidos em isolamento, com comandos e resultados guardados em `docs/evidence/F0/`.
- [x] ADR-001 (Android), ADR-002 (Bridge) e ADR-007 (In-tree fork DroidDeck) concluídas.
- Resultado técnico: **PASS** · Aprovação humana das bases: **APPROVED**.

## F1–F8 — implementação e preparação do piloto
Critérios e cenários de cada fase estão em `ROADMAP.md`. Registrar a evidência em `docs/evidence/Fn/`; não avançar com critério obrigatório pendente.

| Fase | Entrega | Técnico | Evidência |
|---|---|---|---|
| F1 | Builds reproduzíveis + contrato v1 + `SECURITY.md` | PASS | `docs/evidence/F1/` |
| F2 | Pareamento, autenticação e revogação | PASS | `docs/evidence/F2/` (QR DPAPI) |
| F3 | Telemetria real no aparelho | PASS | `docs/assets/emulator_telemetry_live.png` |
| F4 | FL-1, FL-2, FL-5 + Atividade | PASS | `docs/assets/emulator_actions_launch.png`, `emulator_actions_kill.png` |
| F5 | FL-3 screenshot | PASS | `docs/assets/emulator_screenshot_card.png`, `emulator_screenshot_viewer.png` |
| F6 | FL-4 transferência íntegra | PASS | `docs/assets/emulator_transfer_card.png`, `emulator_transfer_download.png`, `emulator_transfer_upload.png` |
| F7 | Revisão independente sem achado crítico/alto | EM ANDAMENTO | Em execução |
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
