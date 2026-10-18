# ROADMAP v0.4 — Command: Módulo Hermes IA (Operação Assistiva e Diagnóstico com Consentimento)

**Status:** CONCLUÍDO (`v0.4.0` — H0 a H5 100% implementadas e testadas)  
**Pré-requisito:** Onda v0.3 (`v0.3.0`) Concluída e Homologada  
**Meta Principal:** Integrar o módulo opcional **Hermes IA** para diagnóstico assistido de telemetria, inspeção de capturas de tela com consentimento explícito e sugestão de ações seguras (restritas à allowlist tipada), mantendo **100% de funcionamento offline/sem IA (Regra 2)** e **zero execução de shell arbitrário (Regra 3)**.

---

## 1. Regras Inegociáveis da Onda v0.4

1. **Independência Total (Regra 2):** Se o Hermes estiver desativado, não configurado ou inacessível, o Command opera normalmente sem erros, delays ou bloqueios na UI.
2. **Consentimento Explícito por Envio (Regra 4):** Nenhuma métrica, lista de processos ou captura de tela é enviada ao provedor de IA sem ação explícita do usuário e sanitização automática de dados sensíveis (IPs privados, chaves, tokens).
3. **Zero Execução Direta pela IA (Regra 3):** A IA **nunca** executa comandos diretamente. Ela apenas retorna *sugestões estruturadas* mapeadas para `ActionId` / `AppId` existentes na allowlist, exigindo toque de confirmação humana no aplicativo.

---

## 2. Estrutura de Fases e Subfases (v0.4)

### 🧪 Fase H0 — Arquitetura e Contrato do Provedor Hermes
**Objetivo:** Definir interfaces desacopladas, modelos de contexto sanitizado e suporte a provedor configurável (Gateway Hermes Local / Gemini API / OpenAI-compatible).

- [x] **H0.1:** Criar modelos de domínio no Backend (`HermesModels.cs`): `HermesConfigDto`, `HermesAnalyzeRequest`, `HermesAnalyzeResponse`, `HermesSuggestedActionDto` (apenas IDs da allowlist).
- [x] **H0.2:** Implementar sanitizador dedicado `HermesContextSanitizer.cs` que remove caminhos de usuário (`C:\Users\<nome>`), mascara IPs e filtra variáveis ou títulos de janela sensíveis antes de montar o prompt.
- [x] **H0.3:** Criar testes unitários de sanitização e contrato em `tests/DroidDeck.Tests/HermesSanitizerTests.cs`.

---

### 🖥️ Fase H1 — Backend: Serviço Hermes e Diagnóstico Assistido
**Objetivo:** Implementar o cliente HTTP seguro no Bridge (.NET 8) com timeout curto, fallback gracioso e armazenamento seguro de configuração.

- [x] **H1.1:** Implementar `IHermesService` e `HermesService.cs` com suporte a análise de telemetria atual (`SystemStats` + `TopProcesses`) e resposta estruturada em JSON.
- [x] **H1.2:** Adicionar suporte opcional a análise multimodal de captura de tela (somente mediante flag `ScreenshotId` explícita de um print válido e não expirado).
- [x] **H1.3:** Validar todas as sugestões de ações retornadas pela IA contra o `AppCatalogService` — descartar imediatamente qualquer sugestão fora da allowlist.
- [x] **H1.4:** Mapear endpoints autenticados em `HermesController.cs`:
  - `GET /api/hermes/status` (estado de configuração e conectividade)
  - `POST /api/hermes/config` (salvar endpoint/modelo/chave protegida)
  - `POST /api/hermes/analyze` (enviar pergunta + contexto sanitizado sob demanda)
- [x] **H1.5:** Criar suíte de testes em `tests/DroidDeck.Tests/HermesServiceTests.cs`.

---

### 📱 Fase H2 — Mobile: Configuração e Card Interativo Hermes
**Objetivo:** Evoluir o card passivo "Hermes IA" na `StatusPage` para um card dinâmico que reflete o estado real (Desativado / Pronto / Analisando) e tela de configuração.

- [x] **H2.1:** Criar modelos Dart em `app/lib/core/droiddeck_client/models/hermes_models.dart` e métodos no `DroidDeckClient`.
- [x] **H2.2:** Criar modal/tela `HermesConfigSheet` permitindo ativar/desativar o módulo Hermes, configurar URL do gateway / chave de API e testar conexão.
- [x] **H2.3:** Atualizar o card Hermes na `StatusPage`: quando desativado, permanece discreto ("Não configurado"); inclui acesso à configuração, assistente e barra de comando rápido.
- [x] **H2.4:** Criar testes de widget em `app/test/hermes_config_test.dart`.

---

### 💬 Fase H3 — Mobile: Console de Chat Assistivo e Ações com Confirmação
**Objetivo:** Oferecer interface conversacional enxuta com chips de diagnóstico rápido, prévia do que será enviado (transparência de privacidade) e cartões de ação sugerida.

- [x] **H3.1:** Criar tela `HermesAssistantPage` no tema Amethyst Dark com histórico de sessão em memória e indicadores de consentimento.
- [x] **H3.2:** Renderizar cartões de **Ação Sugerida** na resposta da IA (ex: *"Encerrar Bloco de Notas"* ou *"Abrir Obsidian"*) que sempre abrem o diálogo padrão de confirmação humana antes de chamar a API de execução.
- [x] **H3.3:** Integrar botão *"Analisar com Hermes IA"* na `ScreenshotViewerPage` para enviar um print específico para explicação assistiva.
- [x] **H3.4:** Criar testes de widget em `app/test/hermes_assistant_test.dart`.

---

### 🎙️ Fase H4 — Mobile: Comandos Rápidos por Voz / Texto Natural (Intent Parser Local)
**Objetivo:** Permitir acionar ações do catálogo por comando rápido com mapeamento determinístico local ou assistido.

- [x] **H4.1:** Criar barra de comando rápido (*Quick Command Bar*) que interpreta intenções simples localmente (offline, ex: *"capturar tela"*, *"abrir obsidian"*, *"abrir orbit"*, *"fechar notepad"*) e usa o Hermes como fallback quando ativo.
- [x] **H4.2:** Exigir confirmação explícita em 1 toque antes de disparar qualquer mutação no PC.
- [x] **H4.3:** Criar testes unitários e de widget em `app/test/quick_command_test.dart`.

---

### 🏁 Fase H5 — Homologação E2E, Pacotes `v0.4.0` e Auditoria de Privacidade
**Objetivo:** Validar que o sistema funciona com e sem Hermes, auditar zero vazamento de credenciais e gerar release `v0.4.0`.

- [x] **H5.1:** Executar suíte completa (`251/251` testes C# PASS + `123/123` testes Flutter PASS + `flutter analyze --no-fatal-infos` exit 0).
- [x] **H5.2:** Integrado ao fluxo contínuo v0.4 -> v0.5 -> v0.6 com subagentes Gemini 3.8 Flash.
- [x] **H5.3:** Cenários validados (Hermes Desativado com regressão zero, Diagnóstico de Telemetria Sanitizado e Ação Sugerida com Confirmação).
- [x] **H5.4:** Documentação e `ROADMAP_V0.4.md` atualizados.

---

## 3. Checklist Mestre de Progresso (v0.4)

- [x] **H0** — Arquitetura, Modelos e Sanitizador de Privacidade Hermes
- [x] **H1** — Backend: Serviço Hermes, Validação de Allowlist e Controller REST
- [x] **H2** — Mobile: Configuração Hermes e Card Dinâmico na StatusPage
- [x] **H3** — Mobile: Console de Chat Assistivo, Inspeção de Print e Ações Confirmadas
- [x] **H4** — Mobile: Barra de Comando Rápido (Parser Local Offline + Assistido)
- [x] **H5** — QA/Release: Validação Completa da Onda v0.4

