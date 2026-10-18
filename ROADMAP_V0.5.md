# ROADMAP v0.5 — Command: Automação, Perfis de Ambiente e Macros Encadeadas

**Status:** CONCLUÍDO (`v0.5.0` — M0 a M4 100% implementadas e testadas)  
**Pré-requisito:** Onda v0.4 (`v0.4.0`)  
**Meta Principal:** Elevar a produtividade operacional com **Modos de Ambiente em 1 Toque** (Trabalho, Jogo, Desenvolvimento, Foco), **Sequências de Ações Tipadas com Rollback/Parada Segura** e integração segura via Webhooks locais/n8n — sempre respeitando a **Regra 3 (zero shell arbitrário, apenas ações tipadas da allowlist)**.

---

## 1. Regras Inegociáveis da Onda v0.5

1. **Composição Estrita sobre Allowlist (Regra 3):** Nenhuma macro ou rotina pode conter scripts livres (`cmd`, `powershell`, `bash`). Cada passo de uma rotina deve referenciar exclusivamente um `ActionType` + `TargetId` validado pelo catálogo seguro.
2. **Cancelamento e Parada de Emergência:** Sequências com múltiplos passos devem suportar cancelamento imediato (`CancellationToken`) e política explícita em caso de falha (`StopOnError` como padrão).
3. **Rastreabilidade Completa:** Cada execução de rotina e cada sub-passo deve ser registrado com status individual (`succeeded`, `failed`, `skipped`).

---

## 2. Estrutura de Fases e Subfases (v0.5)

### ⚙️ Fase M0 — Motor de Sequências e Perfis de Ambiente (Backend .NET 8)
**Objetivo:** Criar o executor transacional de rotinas compostas por passos tipados, com delays controlados e interrupção segura em caso de erro.

- [x] **M0.1:** Criar modelos `RoutineModels.cs`: `RoutineDefinitionDto`, `RoutineStepDto` (`actionType`, `targetId`, `delayMs`, `continueOnError`), `RoutineExecutionResponse`.
- [x] **M0.2:** Implementar `IRoutineService` e `RoutineService.cs` com 3 presets nativos prontos para uso (`preset_study_vault`, `preset_dev_orbit`, `preset_focus_cleanup`).
- [x] **M0.3:** Implementar execução passo a passo com `CancellationToken`, validação estrita de allowlist e abort-on-failure (`skipped`).
- [x] **M0.4:** Mapear endpoints em `RoutinesController.cs` (`/api/routines`, `/api/routines/{id}/execute`, `/api/routines/webhook`).
- [x] **M0.5:** Criar testes unitários e de falha/rollback em `tests/DroidDeck.Tests/RoutineServiceTests.cs`.

---

### 📱 Fase M1 — Mobile: Seletor de Modos de Ambiente (Workspace Modes)
**Objetivo:** Permitir ativar modos de produtividade na `StatusPage` com feedback visual de progresso passo a passo.

- [x] **M1.1:** Criar modelos Dart em `app/lib/core/droiddeck_client/models/routine_models.dart` e integrar no `DroidDeckClient`.
- [x] **M1.2:** Criar card `WorkspaceRoutinesCard` na `StatusPage` exibindo os modos de ambiente e rotinas com lista dos passos que serão executados.
- [x] **M1.3:** Exibir diálogo de confirmação explícita detalhando os passos da rotina e modal de resultado passo a passo (`succeeded`, `failed`, `skipped`).
- [x] **M1.4:** Criar testes de widget em `app/test/workspace_routines_test.dart`.

---

### 🛠️ Fase M2 — Construtor Visual de Rotinas Seguras (Custom Routines)
**Objetivo:** Permitir ao usuário criar e editar suas próprias sequências combinando exclusivamente ações já autorizadas no catálogo.

- [x] **M2.1:** Estender `RoutineService.cs` no Backend para salvar/deletar rotinas customizadas validando cada passo contra a allowlist.
- [x] **M2.2:** Criar tela `RoutineBuilderPage` no Flutter permitindo escolher nome, descrição, adicionar passos restritos ao catálogo (`obsidian`, `orbit`, `test_notepad`, `primary`), delay e salvar.
- [x] **M2.3:** Criar testes em `tests/DroidDeck.Tests/RoutineServiceTests.cs` e `app/test/routine_builder_test.dart`.

---

### 🔔 Fase M3 — Gatilhos Defensivos por Alerta e Webhooks Locais (n8n Ready)
**Objetivo:** Conectar o motor de rotinas a notificações externas sanitizadas via Webhook.

- [x] **M3.1:** Integrar rotinas de limpeza e foco (`Limpeza de Foco`) na `StatusPage`.
- [x] **M3.2:** Criar `IWebhookNotificationService` e `WebhookNotificationService.cs` com sanitização estrita via `HermesContextSanitizer`.
- [x] **M3.3:** Criar testes em `tests/DroidDeck.Tests/WebhookNotificationServiceTests.cs`.

---

### 🏁 Fase M4 — Homologação E2E, Pacotes `v0.5.0` e Documentação
**Objetivo:** Validar todas as rotinas e modos de ambiente.

- [x] **M4.1:** Executar suíte completa (`261/261` testes C# PASS + `130/130` testes Flutter PASS + `flutter analyze --no-fatal-infos` exit 0).
- [x] **M4.2:** Integrado ao fluxo contínuo v0.4 -> v0.5 -> v0.6 com subagentes Gemini 3.8 Flash.
- [x] **M4.3:** Presets de ambiente e construtor visual validados sem regressão.
- [x] **M4.4:** `ROADMAP_V0.5.md` atualizado.

---

## 3. Checklist Mestre de Progresso (v0.5)

- [x] **M0** — Backend: Motor de Sequências, Presets de Ambiente e Cancelamento Seguro
- [x] **M1** — Mobile: Card de Modos de Ambiente e Progresso Passo a Passo
- [x] **M2** — Fullstack: Construtor Visual de Rotinas Customizadas (Restrito à Allowlist)
- [x] **M3** — Integração: Ações Rápidas e Webhook Sanitizado
- [x] **M4** — QA/Release: Validação Completa da Onda v0.5

