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
| F7 | Revisão independente sem achado crítico/alto | PASS | `docs/assets/emulator_f7_*.png`, `app/test/fault_tolerance_and_visual_test.dart` |
| F8 | Instalação repetível + cinco fluxos sem Hermes | PASS | `docs/INSTALL.md`, `docs/TROUBLESHOOTING.md`, `docs/assets/emulator_f8_*.png` |

- Nunca aprovar implementação com credenciais expostas, shell arbitrário, arquivos fora das raízes autorizadas ou dependência de Hermes para controle direto.

## F9 — piloto e decisão do MVP
- [ ] Sete dias corridos e pelo menos 30 execuções, com no mínimo seis por fluxo (FL-1…FL-5).
- [ ] Taxa de sucesso, falhas críticas, integridade, duplicação e privacidade avaliadas.
- [x] Hermes ausente/desligado durante os cinco fluxos diretos (Card "Not configured", 0 chamadas de IA, operação 100% autônoma via Bridge .NET 8).
- [ ] Evidências reunidas em `docs/MVP_APPROVAL.md`.
- Resultado técnico: **NOT_RUN** · Aprovação humana do MVP: **PENDING**.

## Critérios visuais
- [x] Capturas do app real comparadas com `DESIGN.md` e as referências Stitch (Amethyst Dark #050408, #13101B, #1E1829, #352B45, #A78BFA).
- [x] Estados offline, erro, carregamento, confirmação e sucesso final conferidos (Banner de reconexão transparente, sem retry automático em mutações, dicas acionáveis para falhas).
- [x] Acessibilidade, contraste e alvos de toque verificados (remoção de controles não entregues como backup e macros).
- Aceite visual humano: **PASS (Evidências no emulador Pixel 9 / API 37 em docs/assets/emulator_f7_*.png)**.
