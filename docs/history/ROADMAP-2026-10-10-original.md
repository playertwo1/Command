# COMMAND — ROADMAP DE IMPLEMENTAÇÃO

> **Versão:** 1.0 (planejamento)  |  **Data:** 10/10/2026  |  **Status:** DESIGN / SEM CÓDIGO APROVADO
> **Objetivo:** aplicativo Android nativo para controlar PCs Windows diretamente, com Hermes Agent como módulo de IA opcional e independente.
> **Premissa inegociável:** monitorar, abrir apps, tirar screenshots e transferir arquivos deve funcionar com Hermes desligado.

## 0. Visão e regras de escopo

**Produto:** Command Android + Command Bridge Windows, com módulo separado `HermesAdapter`. Primeiro alvo de teste: Galaxy S25 Ultra + um Windows pessoal; depois expandir aos notebooks.

**Duas rotas:**
- **Rota direta (sem IA):** estado, telemetria, processos, apps, tela, arquivos, comandos e logs — via Command Bridge autenticado.
- **Rota inteligente (Hermes):** chat, voz, contexto, skills, diagnósticos explicados e delegação para Codex/Claude/Antigravity — via gateway/adapter próprio.

**Princípios:** local-first; rede privada (Tailscale como opção de acesso remoto); ações explícitas; permissões mínimas; feedback verificável; app útil sem IA; sem terminal remoto irrestrito; Material 3 com tema preto AMOLED.

### Fora do MVP (não implementar antes do Gate MVP)
- Vídeo contínuo/desktop remoto, mouse/teclado, streaming de tela e captura automática.
- Wake-on-LAN fora de casa, widgets, Galaxy Watch, múltiplos PCs simultâneos, builder visual de macros.
- n8n avançado, integrações Codex/Claude/Antigravity, voice-first e comandos de IA com poder de execução.
- Administração remota arbitrária, shell livre, PowerShell genérico via entrada de texto.

## 1. Escopo do MVP v0.1 — aprovado somente após testes

**Entregas P0 (sem negociar):**
- [ ] Um APK Android instalável e um Command Bridge Windows funcionando na sessão do usuário.
- [ ] Parear Android ↔ Bridge por fluxo explícito (ex.: QR/token de uso único com expiração); opção de revogar aparelho.
- [ ] Ver online/offline com `last_seen`, origem do estado e falha claramente indicada.
- [ ] CPU %, RAM usada/total, disco usado/total e uptime por coleta real; temperatura é P1 se sensores/driver exigirem esforço.
- [ ] Lista de apps aprovados; **abrir** ao menos dois; **encerrar** apenas processo da lista permitida, com confirmação.
- [ ] Solicitar **uma screenshot manual**, visualizar, salvar/compartilhar; não capturar quando sessão Windows não permitir.
- [ ] **Enviar e baixar arquivo** dentro de duas pastas de teste explicitamente autorizadas, com tamanho limitado e validação de caminho.
- [ ] Histórico de ações: enviado, recebido, em execução, concluído/erro, horário, dispositivo e código de falha.
- [ ] Interface com estados loading, offline, erro, retry e confirmação de ação destrutiva.
- [ ] Prova de independência: todas as ações diretas funcionam com Hermes desligado.

**Escopo P1 (opcional, após P0 estável):**
- [ ] Temperatura CPU/GPU usando LibreHardwareMonitor quando sensor disponível; caso contrário `Indisponível` com motivo.
- [ ] Tela Hermes com chat/estado read-only apoiada em Hermes-Relay ou cliente Compose, sem capacidade de executar comandos arbitrários.
- [ ] Uma ação personalizada segura do tipo catálogo predefinido (sem shell arbitrário).

### 5 ações-modelo do primeiro piloto
1. Abrir Obsidian no Windows.
2. Abrir a pasta do projeto Orbit em editor escolhido.
3. Tirar print sob demanda e baixar/visualizar.
4. Enviar um arquivo de teste do Android ao PC e recebê-lo de volta.
5. Encerrar um aplicativo de teste permitido, com confirmação (nunca matar processo crítico).

## 2. Plano de implementação por gates (Codex executa e registra evidências)

### G0 — Inventário e decisão de fork (BLOQUEANTE)
- [ ] Clonar para `research/upstream/` ou analisar sem alterar os repositórios Hermes-Relay, DroidDeck e Hy4ri/hermes-mobile.
- [ ] Validar as licenças e avisos de terceiros no commit fixado; registrar URL, SHA, data e licença.
- [ ] Testar build reproduzível do Hermes-Relay Android e do DroidDeck Windows em isolamento.
- [ ] Mapear componentes reaproveitáveis: UX Hermes, autenticação, API, Bridge Windows, sensores.
- [ ] Produzir `docs/ADR-001-base-android.md` comparando fork Hermes-Relay × app Compose novo × Hy4ri.
- [ ] Produzir `docs/ADR-002-bridge.md` (fork seletivo DroidDeck × Bridge limpo).
**PASS:** duas ADRs com critérios de manutenção, segurança, cobertura, licença e custo; demos independentes compilam. **FAIL:** licença incerta ou build irreplicável → apenas inspiração, sem cópia.

### G1 — Repositório e contratos de comunicação
- [ ] Criar monorepo `command/` com `apps/android/`, `apps/windows-bridge/`, `contracts/`, `docs/`, `tests/`, `research/`.
- [ ] `AGENTS.md` na raiz; um `AGENTS.md` por componente definindo fronteiras e proibições.
- [ ] Documento `SECURITY.md`, `PROJECT_STATE.md`, `DECISIONS.md`, `CHANGELOG.md`.
- [ ] Contrato API v1 versionado + IDs estáveis de comando; definir tipos `DeviceState`, `MetricSample`, `ActionRequest`, `ActionResult`, `TransferJob`.
- [ ] Sem tokens, senhas, screenshots, dados de clientes ou arquivos pessoais nos commits/logs.
**PASS:** build CI Android + .NET em ambiente limpo e testes de contrato passam.

### G2 — Bridge Windows & segurança de acesso
- [ ] Iniciar bridge em sessão interativa (tray opcional); bind local/rede privada conforme configuração explícita.
- [ ] Pareamento autorizado fisicamente no PC com token temporário; segredo rotacionável; revogação de dispositivo.
- [ ] TLS ou túnel autenticado apropriado, sem expor endpoint sensível à internet pública.
- [ ] Allowlist de apps/ações; validação de parâmetros; nenhum endpoint `exec(string)`.
- [ ] Auditoria por comando, request-id/idempotency-key e proteção contra replay.
- [ ] Rate limiting e tamanho máximo para payloads.
**PASS:** dispositivo não pareado não consulta dados/execute ações; revogação funciona; comandos duplicados não duplicam efeitos.

### G3 — Android Compose: Home e Dispositivo
- [ ] Tema Material 3, AMOLED; bottom navigation: Início, PCs, Hermes, Ações, Atividade.
- [ ] Telas conectividade e estados explícitos; nunca mostrar uma métrica antiga como 'atual'.
- [ ] Tela de dispositivo: CPU, RAM, disco, uptime e `last_seen`; formatos localizados.
- [ ] Observação por pull ao abrir/recarregar; eventos WebSocket/SignalR somente se necessários.
- [ ] Histórico local Room sem segredo em texto puro; limpeza/retention policy.
**PASS:** todas as telas carregam com dados simulados e reais, offline e latência induzida; sem travamentos.

### G4 — Operações de PC
- [ ] `open_app` pelo catálogo; `close_app` com identificação precisa e confirmação.
- [ ] `screenshot.capture` só sob demanda, com consentimento claro; não coletar tela bloqueada/UAC.
- [ ] `transfer.upload` e `transfer.download` só em pastas autorizadas e com nomes normalizados.
- [ ] Validar path traversal, symlinks/junctions, extensões bloqueadas e limite de tamanho; SHA-256.
- [ ] Limpeza de arquivos temporários e cancelamento seguro após falha/desconexão.
- [ ] Distinguir comando aceito de resultado final; logs de erros sem conteúdo sensível.
**PASS:** 5 ações piloto passam 3x cada em rede local; 1 falha de rede não corrompe transferência nem duplica comando.

### G5 — Hermes independente e integração mínima
- [ ] Testar clientes Hermes-Relay e Hy4ri com a instalação existente, sem comprometer controles do PC.
- [ ] Definir `HermesAdapter` desacoplado com `connect`, `chat`, `sessions`, `health`, `disconnect`.
- [ ] Autenticação Hermes independente de credenciais Bridge; tokens jamais via logs.
- [ ] Opcional: chat básico e saúde do Hermes com status real; sem permissão para usar `open_app` automaticamente.
- [ ] Hermes desligado → apenas tela IA indisponível; ações diretas continuam.
**PASS:** teste de caos Hermes offline enquanto controle do PC permanece ativo.

### G6 — Piloto pessoal & Gate MVP
- [ ] Usar durante 7 dias corridos com tarefas reais e sem acesso ao terminal para as 5 ações piloto.
- [ ] Executar ≥30 ações diretas; contar acertos, falhas, lentidão e retrabalho.
- [ ] Testar Wi-Fi local e acesso remoto privado por Tailscale, quando configurado.
- [ ] Testar suspensão do notebook, bloqueio Windows, logout, reinício Bridge e troca de rede.
- [ ] Testar arquivo de tamanho médio, interrupção de transferência, permissão negada.
- [ ] Teste de privacidade: capturar screenshot contendo dados fictícios; garantir expiração/limpeza.
- [ ] `MVP_APPROVAL.md`: decisões PASS/FAIL/ESCALATE e anexos de evidência.
**PASS recomendado:** ≥95% das 30 ações concluídas corretamente; zero execução não autorizada; zero perda/corrupção de arquivo; nenhuma duplicação destrutiva; operação de PC independe do Hermes; UX de ações comuns ≤3 toques após escolher PC. Falha crítica = NO-GO.

## 3. Estrutura do repositório sugerida

```text
command/
├── AGENTS.md
├── README.md
├── ROADMAP.md
├── PROJECT_STATE.md
├── SECURITY.md
├── DECISIONS.md
├── apps/
│   ├── android/                 # UI Compose; Room; BridgeClient; HermesAdapter
│   │   └── AGENTS.md
│   └── windows-bridge/          # .NET; Windows adapters; sensores, arquivos e ações
│       └── AGENTS.md
├── contracts/                   # OpenAPI, JSON Schema, versionamento
│   └── AGENTS.md
├── tests/                       # Contract, integration, security smoke, e2e
├── docs/                        # ADRs, UX, privacy, install, troubleshooting
│   ├── adr/
│   └── evidence/
└── research/                    # Links/SHAs/licenças; forks NÃO entram no build
```

## 4. Contrato de segurança resumido

- Nunca aceitar shell genérico remoto (`powershell -Command` ou comando livre).
- Comandos por IDs e parâmetros tipados; lista de aplicativos configurada **no PC**, não pela IA.
- `close_app`, reiniciar serviço e operações sensíveis solicitam confirmação; permissões por capacidade e dispositivo.
- Dados de telas/arquivos nunca enviados ao Hermes sem ação consentida separada.
- Transferir via pasta sandbox; rejeitar traversal `../`, caminhos absolutos fora do sandbox e links simbólicos que escapam.
- Sessão bloqueada/screen seguro: informar impossibilidade; não tentar bypass.
- Audit trail mínimo sem imagem integral, nomes pessoais de arquivos e mensagens.
- Tailscale = transporte privado, **não substitui autenticação da API**.
- Chaves Android guardadas com Android Keystore; revogação e rotação testadas.

## 5. UX & regras de aceitação

| Tela | Conteúdo MVP | Ação principal |
|---|---|---|
| Início | PC favorito, conexão, ação recente, acesso rápido | Abrir ações |
| PCs | Lista / 1 PC inicial, status verdadeiro | Abrir detalhes |
| PC detalhe | CPU/RAM/disco/uptime, apps, print e arquivos | Executar ação autorizada |
| Hermes | Gateway conectado/desconectado, chat P1 | Conversar quando disponível |
| Ações | Catálogo limitado e favorito | Executar com confirmação adequada |
| Atividade | ID, status e timestamp com erro legível | Revisar/repetir seguro |

**Estados obrigatórios:** offline, sem permissão, não pareado, em andamento, sucesso confirmado, falhou, hardware sem sensor, aguardando confirmação. Nunca usar sucesso otimista para operação que ainda roda no PC.

## 6. Regra de execução por agentes (Codex / auditor)

- O Codex implementa no branch de trabalho, documenta SHA de upstream e evidências por gate.
- Auditor independente revisa segurança, licenças, testes e escopo. Autoridade humana aprova G0 e G6.
- Nada de merge na main por automação sem aprovação explícita. Não modificar Hermes upstream nem dados reais dos projetos.
- Toda fase termina com `PASS | FAIL | ESCALATE`, evidência reproduzível e próximo gate.
- Preferir ajustes locais/contratos pequenos; não criar framework multiagente novo dentro do Command.

## 7. Evolução PÓS-GATE MVP (não codificar antes de aprovação)

### v0.2 — Observabilidade
- [ ] Temperatura CPU/GPU e bateria por modelo de hardware, gráficos curtos, alertas de sobrecarga.
- [ ] Serviços Windows predefinidos, ações Windows seguras, histórico avançado.
- [ ] Multi-PC, context switching, painel de saúde geral.

### v0.3 — Transferência & tela
- [ ] Transferências retomáveis e fila; recebimento por menu compartilhar Android.
- [ ] Screenshot com marcação e recorte local, fluxo explícito 'analisar com Hermes'.
- [ ] Integração/abertura do RustDesk externo para desktop remoto ao vivo (sem incorporá-lo).

### v0.4 — Hermes profissional
- [ ] Perfis Diretor/Builder/Auditor, sessões, status de jobs, logs e permissões.
- [ ] Conversa multimodal controlada, voz, diagnósticos explicáveis usando telemetria real.
- [ ] Delegação a Codex, Claude, Antigravity `agy` por skills testadas e confirmação humana.
- [ ] Limites de uso/custo de modelos, aprovação por tarefa, rastreio de execuções.

### v0.5 — Workflows e macros
- [ ] n8n API/webhooks com confirmação e idempotência.
- [ ] Macros encadeadas com rollback possível, permissões e preview de ações.
- [ ] Modo Trabalho, Modo Desenvolvimento, Modo Jogo, Modo Manutenção.
- [ ] Abrir projetos favoritos (Orbit, Life RPG, Pocket Hero, Obsidian).

### v0.6 — Mobile premium
- [ ] Widgets, atalhos na tela inicial, tiles de configurações rápidas, integração Wear OS.
- [ ] Busca universal, templates de ações, notificações úteis e silenciosas.
- [ ] Wake-on-LAN com relay na rede sempre ligado, **somente após validar BIOS/NIC/roteador**.

### v1.0 — Produto maduro
- [ ] Observabilidade e recuperação de erros, backups/exportação local, instalador assinado.
- [ ] Atualização do Bridge com assinatura e rollback, testes de segurança/performance.
- [ ] Galeria segura de ações, documentação de onboarding e acessibilidade.

## 8. Projetos GitHub: decisões de reaproveitamento

| Repositório | Link | Papel | Decisão | Cuidado |
|---|---|---|---|---|
| Hermes-Relay | https://github.com/Codename-11/hermes-relay | Android Hermes + CLI e plugin remoto | CANDIDATO A FORK ANDROID | MIT; auditar APIs, manutenção e build |
| DroidDeck | https://github.com/ggfto/DroidDeck | Bridge .NET 8, controle Windows, telemetria, macros | BASE DE REFERÊNCIA/FORK SELETIVO DO BRIDGE | Apache-2.0; separar backend do Flutter |
| LibreHardwareMonitor | https://github.com/LibreHardwareMonitor/LibreHardwareMonitor | Biblioteca .NET de sensores de hardware | INTEGRAR BIBLIOTECA SE COMPATÍVEL | MPL-2.0; verificar avisos/arquivos modificados |
| Hermes Agent oficial | https://github.com/NousResearch/hermes-agent | Orquestração de agentes e skills | INTEGRAR, NÃO FORKAR | API/gateway e permissões por versão |
| Hermes Mobile / Hy4ri | https://github.com/Hy4ri/hermes-mobile | Alternativa Compose e painel administrativo Hermes | PLANO B ANDROID | Apache-2.0 |
| HASS.Agent | https://github.com/hass-agent/HASS.Agent | Sensores, eventos e ações Windows | REFERÊNCIA DE IMPLEMENTAÇÃO | MIT |
| LocalSend | https://github.com/localsend/localsend | Compartilhamento de arquivos local | REFERÊNCIA/INTEGRAÇÃO FUTURA | Apache-2.0 |
| OpenCode Remote | https://github.com/vchhikara/opencode-remote | Android nativo, bridge, aprovações e sessões de agente | REFERÊNCIA DE UX/SESSÕES | MIT |
| PC Remote | https://github.com/Abhishek-karma/pc-remote | Controle Android-Windows com WSS e descoberta | REFERÊNCIA DE COMUNICAÇÃO | Confirmar licença antes de copiar |
| Hermes Android / adebnar | https://github.com/adebnar/hermes-android | Administração de Hermes em Android | REFERÊNCIA, NÃO COPIAR SEM AVALIAR | GPL-3.0 |
| Hermes Android / VrtxOmega | https://github.com/VrtxOmega/hermes-mobile-android | Cliente Compose com atenção a permissões | REFERÊNCIA DE SEGURANÇA | MIT |
| Hermes Android / rusty4444 | https://github.com/rusty4444/hermes-android | Cliente móvel alternativo, sessões Hermes | REFERÊNCIA | Confirmar licença |
| OliveTin | https://github.com/OliveTin/OliveTin | Comandos predefinidos e histórico operacional | INSPIRAÇÃO, NÃO COPIAR CÓDIGO | AGPL-3.0 |
| Macro Deck | https://github.com/Macro-Deck-App/Macro-Deck | Builder de macros e perfis de botões | INSPIRAÇÃO PÓS-MVP | Conferir licenças por componente |
| Deskmate | https://github.com/JakubWawrzola/deskmate | Sensores e ações Windows com Home Assistant | REFERÊNCIA DE TELEMETRIA | Conferir licença |
| Home Assistant Android | https://github.com/home-assistant/android | Widgets, notificações e experiência Android | INSPIRAÇÃO PÓS-MVP | Conferir obrigações de licença |
| KDE Connect | https://github.com/KDE/kdeconnect-kde | Comandos remotos e integração entre dispositivos | REFERÊNCIA | Conferir licença dos módulos |
| Wear OS Remote | https://github.com/nnyj/wearos-remote | Wake-on-LAN e comandos pelo relógio | INSPIRAÇÃO PÓS-MVP | Conferir licença |
| RustDesk | https://github.com/rustdesk/rustdesk | Controle de desktop remoto ao vivo | INTEGRAÇÃO EXTERNA FUTURA | AGPL-3.0 |
| n8n | https://github.com/n8n-io/n8n | Execução de workflows | INTEGRAÇÃO PÓS-MVP | Conferir licença e API |
| Antigravity CLI skill Hermes | https://github.com/NousResearch/hermes-agent/blob/main/optional-skills/autonomous-ai-agents/antigravity-cli/SKILL.md | Delegação ao CLI agy via Hermes | VALIDAR PÓS-MVP | Exige agy instalado e autenticado |

> **Aviso jurídico:** licenças e APIs podem mudar; confirmar o commit e o arquivo LICENSE antes de copiar qualquer código. GPL/AGPL exigem avaliação especial. Referenciar código não autoriza automaticamente mistura de módulos.

## 9. Próxima ação exata para o Codex

1. Executar **somente G0**, sem criar UI nova nem Bridge novo.
2. Entregar `ADR-001`, `ADR-002`, inventário de licenças, matriz funcional e evidência de build dos candidatos.
3. Propor backlog refinado de G1-G6 com esforço, bloqueios e alternativas simples.
4. Solicitar aprovação humana do fork/base escolhido **antes** de alterar repositórios terceiros.

**Critério geral:** manter cada etapa utilizável e independente da próxima. O Hermes agrega inteligência; nunca é requisito para controlar o computador.
