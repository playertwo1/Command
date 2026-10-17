# Command — roadmap do MVP v0.1

**Estado: APPROVED / PLANNED.** Aprovado pelo proprietário em 2026-10-12. As fases F0–F9 estão planejadas e ainda não executadas. Este documento é a fonte oficial do roadmap em `ROADMAP.md`; o planejamento anterior está preservado em `docs/history/ROADMAP-2026-10-10-original.md` e o texto exatamente aprovado em `docs/plans/2026-10-12-mvp-inicial.md`.

**Revisão 2026-10-13:** esclarecimentos que não mudam escopo, fases nem metas (fluxos numerados, rede/relógio/firewall, contrato inicial, riscos e pós-MVP). Lista completa na seção 9; aguardam ciência do proprietário.

**Objetivo:** entregar um APK Android e um Bridge Windows para consultar e operar um PC pessoal com segurança, resultados reais e independência do Hermes.

**Arquitetura:** Android → API autenticada do Bridge → operações Windows → resultado correlacionado → atividade. Bridge executa na sessão do usuário; autenticação, catálogo, métricas, captura e transferências são independentes de IA.

**Stack de partida do manual:** Kotlin, Jetpack Compose, Material 3 e Room; C#/.NET no Windows. Base nova ou reaproveitamento seletivo dependem da F0. Versões e dependências serão fixadas na decisão técnica, sem assumir compatibilidade atual dos candidatos.

**Fontes:** `COMMAND_Manual_MVP.docx` (transcrição em `docs/MANUAL_MVP.md`), `PROJECT.md`, roadmap original e `DESIGN.md`. Telas em `references/stitch/` orientam a aparência; o conteúdo implementado é limitado ao escopo abaixo.

**Execução por IA:** ler `AGENTS.md`, `STATE.md`, este roadmap e a fase ativa. Executar tarefas em ordem, registrar evidências e atualizar estado. Usar o fluxo de execução adotado pelo proprietário; nenhuma fase autoriza commit, push, publicação ou uso de dados pessoais automaticamente.

## 1. Resultado que caracteriza o MVP

- Um celular Galaxy S25 Ultra pareado com um PC Windows pessoal; selecionar e operar um PC por vez.
- Parear com autorização física no PC, reconectar e revogar o aparelho.
- Mostrar online/offline, última resposta, CPU, RAM, disco e uptime reais.
- Abrir Obsidian e um projeto no editor configurado no PC; encerrar um app de teste permitido após confirmação.
- Capturar uma screenshot manual, visualizar, salvar e compartilhar.
- Enviar um arquivo de teste do Android ao PC e baixá-lo de volta usando duas pastas autorizadas, com SHA-256.
- Consultar histórico de ações com resultado final ou erro legível; operação aceita não aparece como concluída.
- Executar os cinco fluxos do manual com Hermes ausente ou desligado.

### Os cinco fluxos do piloto

IDs usados em testes, evidências e na contagem do F9. Correspondem às histórias da seção 6 do manual.

| ID | Fluxo | Fase | Sucesso só quando |
|---|---|---|---|
| FL-1 | Abrir Obsidian | F4 | Bridge confirma processo iniciado e Atividade mostra `succeeded` |
| FL-2 | Abrir projeto Orbit no editor configurado (D-004) | F4 | Editor abre o projeto cadastrado; Android enviou só o ID |
| FL-3 | Screenshot manual | F5 | Imagem visualizada e salva/compartilhada; Windows bloqueado gera erro legível |
| FL-4 | Enviar e baixar arquivo de teste | F6 | SHA-256 igual na ida e na volta |
| FL-5 | Encerrar app de teste permitido | F4 | Confirmação aceita e instância exata encerrada; processo crítico nunca listado |

**Ficam após o MVP:** chat/voz/delegação Hermes, temperatura/GPU, multi-PC, macros/modos, serviços Windows, backup remoto, n8n, widgets/Watch, Wake-on-LAN, controle de mouse/teclado, streaming, retomada de transferências e análise de prints por IA. A aba Hermes pode aparecer com “Não configurado”; não conterá controles fictícios ou chat simulado.

## 2. Parâmetros aprovados

Valores aprovados com o plano; não são exigências do manual e podem ser revistos por decisão registrada em `docs/DECISIONS.md`.

| Tema | Proposta inicial |
|---|---|
| Rede | Concluir primeiro na LAN; HTTPS com identidade do Bridge confirmada no pareamento. Certificado do Bridge fixado no Android pelo fingerprint recebido no QR (pinning). Tailscale é um teste adicional quando disponível; cada request continua autenticada. |
| Descoberta e firewall | QR de pareamento contém endereço, porta, fingerprint e token; sem mDNS no MVP. IP alterado exige editar endereço ou parear de novo, sem confiar em novo certificado silenciosamente. Regra de firewall limitada ao perfil Privado, criada com consentimento explícito do usuário e documentada em `docs/INSTALL.md`. |
| Relógio | Expirações (pareamento, mutação, screenshot) medidas pelo relógio do Bridge na recepção; o horário do Android é só informativo. Timestamps em UTC. |
| API | HTTP versionado `/api/v1`; consultas e acompanhamento de jobs por polling. Não adicionar WebSocket/SignalR sem necessidade demonstrada. |
| Pareamento | Token de uso único válido por 5 minutos; identidade/certificado do Bridge confirmados no PC. Credencial Android protegida pelo Keystore e credencial Windows pelo mecanismo do sistema. |
| Métricas | Atualizar a cada 5 segundos somente com a tela em primeiro plano; após 15 segundos sem resposta, indicar desconexão. Preservar o horário da última resposta e indicar valores antigos como antigos. |
| Apps | Configuração local no PC; executável e argumentos fixados no catálogo. Android envia IDs, nunca executáveis, scripts ou caminhos arbitrários. |
| Arquivos | Duas raízes separadas configuradas no PC: entrada de uploads e saída de downloads. Limite de 100 MiB por arquivo, um job por vez, sem sobrescrever arquivo existente. |
| Screenshots | Uma captura por pedido; temporário no Bridge expira após 10 minutos. Android mantém prévia em cache; só conserva no destino escolhido ao salvar/compartilhar. |
| Retenção | Histórico técnico local por 7 dias, botão para limpar; excluir tokens, imagens, argumentos sensíveis e caminhos pessoais dos registros. Temporários de transferências encerradas/falhas expiram em até 24 horas. |
| Idempotência | Identidade de execução = aparelho + chave de idempotência; registro persistente por 24 horas. Repetição devolve o mesmo job; payload diferente com a mesma chave é rejeitado. Pedido novo de mutação expira em 5 minutos; replay vencido não executa mesmo após limpeza do registro. |
| Falha/reinício | Nunca reenviar mutação automaticamente. Bridge reiniciado marca jobs interrompidos como indeterminados quando não consegue comprovar o efeito. Não repete execução para “recuperar” um job. |
| IA | Independência é obrigatória. Integração Hermes é uma entrega posterior, não requisito para liberar v0.1. |

## 3. Fases e ordem

Estados: `PLANNED` → `READY` → `IN_PROGRESS` → `REVIEW` → `DONE` (ou `BLOCKED`); atualizar a coluna junto com `STATE.md`. Verificação de todas as fases: **NOT_RUN**. Os aceites humanos específicos permanecem nos gates indicados.

| Fase | Entrega verificável | Depende de | Original | Estado |
|---|---|---|---|---|
| F0 | Bases, ferramentas e limites de reaproveitamento escolhidos | Aprovação deste plano | G0 | READY |
| F1 | Android/Bridge compiláveis e contrato v1 definido | F0 + aceite da base | G1 | PLANNED |
| F2 | Bridge inicia, pareia, autentica e revoga | F1 | G2 | PLANNED |
| F3 | APK pareado mostra métricas reais do PC | F2 | G3 | PLANNED |
| F4 | Apps/projetos autorizados + execução e histórico reais | F3 | G4: ações | PLANNED |
| F5 | Screenshot manual com visualização/salvar/compartilhar | F4 | G4: tela | DONE |
| F6 | Upload/download restritos e íntegros | F5 | G4: arquivos | PLANNED |
| F7 | Falhas, segurança e UX revisadas de ponta a ponta | F6 | Fechamento G3/G4 | PLANNED |
| F8 | APK/Bridge instaláveis e independência da IA comprovada | F7 | Independência G5 + preparação G6 | PLANNED |
| F9 | Piloto de 7 dias, métricas e decisão de MVP | F8 | G6 | PLANNED |

Não iniciar a fase seguinte com critério obrigatório pendente. Segurança é implementada junto de cada capacidade e revisada novamente em F7.

## 4. Tarefas por fase

### F0 — escolha de bases e preparação técnica

**Entrada:** manual, referências Stitch e esqueleto atual. **Saída:** duas ADRs e inventário verificável.

- [ ] F0-01 — inventariar PC/Android de teste, Git, SDK Android, JDK e .NET; registrar versões e ausências em `research/ENVIRONMENT.md`. Não instalar dependências nem acessar aparelho sem a autorização aplicável.
- [ ] F0-02 — inspecionar Hermes-Relay, Hy4ri/hermes-mobile, DroidDeck e LibreHardwareMonitor em `research/upstream/`; fixar URL/SHA/data e verificar LICENSE, dependências e scripts antes de executar. Registrar em `research/UPSTREAM.md`.
- [ ] F0-03 — tentar builds isolados dos candidatos Android e Bridge pertinentes à decisão. Guardar comandos reais, ambiente, resultados e limitações em `docs/evidence/F0/`; falha não autoriza copiar código não auditado.
- [ ] F0-04 — entregar `docs/adr/ADR-001-base-android.md` e `ADR-002-bridge.md`, comparando fork/reuso com base nova quanto a manutenção, licença, segurança, custo de adaptação e independência do Hermes. Entregar `research/API_MATRIX.md` com implementado/verificado/ausente por candidato.

**Conclusão:** cada candidato tem evidência ou motivo de rejeição; ADRs recomendam uma opção implementável; proprietário aprova a base antes de F1. Se nenhum candidato servir, propor Compose e Bridge próprios nas ADRs. Um upstream rejeitado não bloqueia permanentemente o projeto.

### F1 — fundação compilável e contratos

**Entrada:** ADRs aprovadas. **Saída:** projetos de desenvolvimento compiláveis, sem ações remotas implementadas.

- [ ] F1-01 — materializar a base aprovada em `apps/android/` e `apps/windows-bridge/`; fixar SDKs/dependências, wrappers e comandos reais. Mapear arquivos/responsabilidades e criar `AGENTS.md` de cada componente. Alinhar a regra de segredo com pareamento: token temporário pode ser mostrado apenas no fluxo autorizado no PC; credenciais persistentes nunca são exibidas.
- [ ] F1-02 — definir `contracts/openapi-v1.yaml` e schemas dos tipos `DeviceState`, `MetricSample`, `ActionRequest`, `ActionResult`, `TransferJob`, pareamento e `Error` (código estável + mensagem legível); `HermesHealth` fica fora do v1. Ponto de partida das rotas, sob `/api/v1`: `health`, `pairing`, `devices/self`, `metrics`, `apps`, `actions`, `jobs/{request_id}`, `screenshots`, `transfers`, `history`; definir unidades, campos opcionais, timestamps UTC e exemplos fictícios. Implementação valida o contrato em ambos os lados.
- [ ] F1-03 — escrever `SECURITY.md` com modelo de ameaças (outro dispositivo na LAN, celular perdido/roubado desbloqueado, replay, arquivo malicioso, Bridge exposto por engano) e: transporte, pareamento, revogação, armazenamento de chaves, confirmação, replay/idempotência, auditoria, limites e retenção. Limites da seção 2 entram como configuração validada. Decidir se ações destrutivas exigem desbloqueio biométrico no Android (D-005).
- [ ] F1-04 — configurar verificação local e CI para Android, .NET e contratos. Adicionar fixtures fictícias e checks de compatibilidade. Atualizar comandos em README/AGENTS; criação/execução de CI remoto segue autorização de publicação.

**Conclusão:** builds locais reproduzíveis e validação de contratos passam em ambiente limpo; CI preparada e resultado remoto registrado como NOT_RUN se ainda não houver remoto autorizado.

### F2 — Bridge e pareamento seguro

**Entrada:** contratos e política de segurança. **Saída:** aparelho autorizado consulta a identidade do PC.

- [ ] F2-01 — iniciar Bridge na sessão interativa sem administrador; bind em endereço explicitamente configurado; HTTPS, identidade estável do PC e armazenamento protegido. Exibir no PC estado/versão e comandos de iniciar/parar. Sem regra de firewall, a conexão falha com instrução clara em vez de abrir portas automaticamente.
- [ ] F2-02 — implementar pareamento por QR/token de uso único, validade de 5 minutos, autorização local e confirmação da identidade do Bridge. Criar, rotacionar e revogar uma credencial por aparelho; após rotação confirmada, a antiga deixa de funcionar.
- [ ] F2-03 — autenticar todas as rotas sensíveis, definir permissões por capacidade, limites de requests/payload e auditoria sanitizada. Pareamento recebe limitador próprio contra tentativas repetidas.
- [ ] F2-04 — verificar token expirado/reutilizado, credencial ausente/inválida/revogada, rotação concluída/interrompida, certificado alterado, persistência após reinício, aparelho não pareado e revogação feita só pelo PC (celular perdido). Saúde pública, caso exista, não retorna telemetria, nomes ou catálogo.

**Conclusão:** pareamento válido funciona; demais casos são rejeitados; revogação invalida requests seguintes; segredo não aparece em log, evidência ou configuração versionada.

### F3 — primeira entrega utilizável: APK e telemetria

**Entrada:** Bridge autenticado. **Saída:** Galaxy S25 Ultra exibe estado real do PC.

- [ ] F3-01 — implementar CPU/RAM/disco/uptime no Bridge, com `sample_at`, unidades e motivo de indisponibilidade. CPU usa uma janela de medição real; não preencher valores ausentes com zero.
- [ ] F3-02 — criar tema Compose a partir de `DESIGN.md` e referências de Início/Computadores/pareamento. Implementar `BridgeClient`, pareamento, armazenamento Keystore e conexão a um PC. Confirmar tokens visuais divergentes antes de codificá-los.
- [ ] F3-03 — implementar detalhes do PC e atualização em primeiro plano; mostrar loading, não pareado, credencial revogada, offline, erro e retry. Manter `last_seen` como última resposta confirmada, não como prova de que a máquina está desligada.
- [ ] F3-04 — demonstrar no aparelho CPU/RAM/disco/uptime sob mudança de carga; comparar fonte/coleta e horário; interromper Bridge/rede e conferir dados antigos identificados. Registrar capturas reais, inclusive fonte ampliada.

**Conclusão:** APK pareia e consulta PC real; métricas coerentes; sem rede indica desconexão em até 15 segundos; retomar a tela permite recuperar a consulta. Temperatura/GPU permanecem fora do núcleo obrigatório.

### F4 — catálogo, ações e histórico

**Entrada:** conexão real Android–Bridge. **Saída:** abrir Obsidian/projeto e encerrar app permitido com resultado real.

- [x] F4-01 — cadastrar localmente apps e projeto de teste com IDs, executável e argumentos fixos. Listar somente itens autorizados. Abrir Obsidian e Orbit no editor escolhido, sem caminhos recebidos do celular e sem modificar os arquivos dos projetos.
- [x] F4-02 — criar executor de ações e armazenamento persistente dos jobs/chaves. Estados: `accepted`, `running`, `succeeded`, `failed`, `cancelled`, `unknown`. Android mantém adicionalmente o estado local `sending`; ACK não encerra operação. Consultas de job/histórico ficam limitadas ao aparelho autorizado; requests de mutação têm expiração, sem repetir um pedido antigo depois da limpeza das chaves.
- [x] F4-03 — encerrar somente uma instância permitida, identificada por processo e momento de criação; revalidar alvo e permissão antes do efeito. Exibir nome/instância na confirmação. Se encerramento normal não funcionar, informar falha; não elevar nem forçar término automaticamente.
- [x] F4-04 — implementar Atividade e persistência Room / Local: ID, tipo de ação, dispositivo, horários, estado e erro. Permitir consultar novamente um job, limpar dados e repetir somente com confirmação quando puder haver efeito duplicado.
- [x] F4-05 — verificar app inexistente/permissão negada, alvo já encerrado/PID reutilizado, retirada da allowlist, toque duplo, chave repetida com payload diferente, replay vencido, acesso a job de outro aparelho e resposta perdida após execução. Resultado indeterminado não é convertido em sucesso nem provoca reexecução.

**Conclusão:** duas aberturas e encerramento permitido passam três vezes; confirmação cancelada não executa; toque repetido não duplica efeito; resultado final chega à Atividade e sobrevive à reabertura do Android.

### F5 — screenshot manual

**Entrada:** executor/histórico e conexão autenticada. **Saída:** captura manual visualizada, salva ou compartilhada.

- [x] F5-01 — implementar `screenshot.capture` sob pedido explícito, capturando inicialmente o monitor principal na sessão interativa. Rejeitar sessão bloqueada, secure desktop/UAC e logout com códigos distintos e legíveis.
- [x] F5-02 — entregar imagem somente ao aparelho autorizado que solicitou o job; temporário protegido e expiração de 10 minutos. Registrar metadados do job sem imagem nos logs.
- [x] F5-03 — criar visualização com zoom, nova captura manual, salvar no destino escolhido e compartilhar por mecanismo Android. Nenhum refresh periódico nem envio automático para IA.
- [x] F5-04 — verificar captura com conteúdo fictício, acesso por outro aparelho, item expirado, Windows bloqueado, erro de captura e perda de rede. Limpar temporários no startup e após vencimento.

**Conclusão:** capturar/visualizar/salvar/compartilhar passa três vezes; imagem vencida/indevida não é entregue; condição Windows protegida retorna erro sem bypass.

### F6 — transferência restrita de arquivos

**Entrada:** jobs, autenticação e histórico. **Saída:** arquivo vai ao PC e retorna íntegro.

- [x] F6-01 — configurar duas raízes no PC, uma de entrada e outra de saída. Contrato usa ID de raiz/item e nome simples validado; nenhum caminho Windows arbitrário é aceito. Política de nomes/extensões fica explícita e rejeita arquivos executáveis/scripts no piloto.
- [x] F6-02 — upload com seleção Android, limite de 100 MiB, progresso/cancelamento e escrita temporária; conferir bytes e SHA-256 antes de promover ao destino. Colisão de nome retorna erro e não sobrescreve.
- [x] F6-03 — listar e baixar somente itens da raiz de saída autorizada. Transferir o arquivo de teste à saída por ação local no PC; baixar pelo Android e verificar integridade antes de confirmar sucesso.
- [x] F6-04 — normalizar caminhos e rejeitar traversal, caminhos absolutos/UNC, separadores embutidos, nomes reservados/ADS e symlinks/junctions/reparse points que permitam escapar. Revalidar no acesso efetivo, não apenas na listagem.
- [x] F6-05 — verificar arquivo acima do limite, corrupção/checksum inválido, interrupção/cancelamento, permissão negada, pouco espaço, colisão e troca de item entre listar e baixar. Incompleto nunca aparece como arquivo final; tentativa nova é explícita, sem retomada automática.

**Conclusão:** ida/volta passa três vezes com SHA-256 igual; uma interrupção não gera arquivo final corrompido; nenhuma leitura/escrita alcança caminho fora das raízes.

### F7 — integração, falhas e fidelidade visual

**Entrada:** cinco fluxos implementados. **Saída:** revisão independente e correções obrigatórias concluídas.

- [ ] F7-01 — alinhar Início, Computadores, detalhe, Apps, Ações, Atividade, pareamento e configurações às referências. Mostrar só catálogo disponível; remover da implementação controles de macros/serviços/backup não entregues. Ajustar fontes, contraste, toque, teclado e orientação.
- [ ] F7-02 — verificar perda/troca de rede, suspensão, Windows bloqueado/logout, Bridge encerrado/reiniciado, app Android encerrado e credencial revogada durante operação. Nenhum retry automático de mutação; estado desconhecido tem instrução de recuperação.
- [ ] F7-03 — verificar todos os controles de segurança de F2/F4/F5/F6 e políticas de retenção, expiração, logs e limpeza. Usar somente fixtures fictícias e registrar falhas com reprodução.
- [ ] F7-04 — realizar revisão independente de segurança, contratos e escopo; corrigir achados críticos/altos. Mostrar telas implementadas no aparelho ao proprietário para aceite visual; registrar diferenças em DESIGN.

**Conclusão:** todos os critérios das fases anteriores continuam válidos; nenhuma falha crítica/alta aberta; ações favoritas em até três toques depois de escolher PC, sem contar confirmação de segurança e seleção de arquivo; aceite visual registrado.

### F8 — instalação repetível e prova sem Hermes

**Entrada:** integração revisada. **Saída:** pacote pessoal instalável com instruções reais.

- [ ] F8-01 — produzir APK de teste e pacote Bridge com versão/hash; documentar instalação/início/parada/pareamento/revogação/desinstalação em `docs/INSTALL.md`. Definir e proteger chaves de assinatura de teste; instalador público/atualização automática ficam após MVP.
- [ ] F8-02 — instalar a partir dos pacotes, reiniciar PC/Android e repetir conexão e cinco fluxos. Bridge inicia na sessão do usuário; startup automático somente com opção explícita. Documentar limitações em `docs/TROUBLESHOOTING.md`.
- [ ] F8-03 — executar todos os fluxos com Hermes ausente ou desligado; comprovar que nenhum comando direto usa autenticação, runtime ou endpoint Hermes. Tela Hermes apenas informa estado não configurado.
- [ ] F8-04 — validar LAN. Se Tailscale já estiver disponível e autorizado, testar rede externa com autenticação/pinning preservados. Se não estiver, registrar NOT_RUN e limitar a declaração de suporte à LAN.

**Conclusão:** instalação reproduzível no ambiente piloto; cinco fluxos operacionais sem Hermes; limites de rede documentados e pacote pronto para o uso pessoal em F9.

### F9 — piloto e aceite final

**Entrada:** pacote F8 instalado. **Saída:** decisão registrada em `docs/MVP_APPROVAL.md`.

- [ ] F9-01 — usar durante sete dias corridos e registrar pelo menos 30 execuções, no mínimo seis por cada um dos cinco fluxos do manual. Contar falhas, retrabalho, duração e erro; tentativas de QA não substituem uso do piloto. Registro mínimo por execução em `docs/evidence/F9/`: data/hora UTC, fluxo (FL-n), rede, `request_id`, estado final, código de erro e observação sem dados pessoais.
- [ ] F9-02 — considerar sucesso somente efeito correto com resultado confirmado. Com exatamente 30 execuções, exigir pelo menos 29 sucessos (≥95%). Resultado desconhecido conta como falha; manter histórico de todas as tentativas.
- [ ] F9-03 — consolidar evidências F0–F8, lista de problemas e verificação de zero execução não autorizada, corrupção/perda e duplicação destrutiva. Falha crítica impede aprovação; depois de corrigida, repetir verificação relevante e reiniciar o piloto de sete dias.
- [ ] F9-04 — entregar relatório com resultado `PASS / FAIL / ESCALATE`, rede efetivamente validada, artefatos e limitações; proprietário registra `APPROVED / CHANGES_REQUIRED`.

**Conclusão:** metas cumpridas, nenhuma falha crítica aberta e aprovação humana registrada. Só então planejar temperatura, chat Hermes e evolução.

## 5. Contratos comuns e responsabilidades

| Local | Responsabilidade |
|---|---|
| `apps/android/` | UI, BridgeClient, credenciais Keystore, Room, seleção/salvar/compartilhar arquivos e cache de imagens |
| `apps/windows-bridge/` | Autenticação, pareamento, métricas, catálogo, executor/jobs, captura, sandbox de arquivos e armazenamento protegido |
| `contracts/` | API v1, DTOs, estados, unidades, erros e exemplos fictícios |
| `tests/` | Cenários de contrato/integração/segurança entre componentes; testes específicos também junto de cada componente |
| `research/` | Inventário técnico e resultados dos candidatos; fontes clonadas fora do build do Command |
| `docs/adr/` | Decisões aprovadas e razões |
| `docs/evidence/F0/` … `F9/` | Comandos, versões, resultados sanitizados e referências às capturas de implementação |

F1 fixa rotas, DTOs e limites no contrato. Operações de app, captura e transferência consomem identidade autenticada e produzem jobs consultáveis por `request_id`; falhas usam códigos definidos no contrato. `succeeded` exige comprovação específica da operação. Nenhum módulo pode redefinir estados, unidades ou semântica de retry sozinho.

## 6. Regra de conclusão e retomada por qualquer IA

1. Ler STATE e identificar a primeira fase autorizada com tarefas pendentes.
2. Conferir pré-condições e fontes do contrato; escrever a spec curta/arquivo de plano necessário usando `docs/templates/` antes de implementar comportamento novo.
3. Fazer tarefas em ordem. Cenários de verificação da fase fazem parte da entrega, inclusive dispositivo real quando indicado.
4. Registrar por tarefa: arquivos alterados, comandos reais, resultado, evidência e pendência. Não inventar comandos de build antes da escolha da base.
5. Ao terminar: atualizar STATE com uma próxima ação; registrar revisão técnica separada do aceite humano. `NOT_RUN` ou dado simulado não fecham requisito real.
6. Se bloqueado: registrar causa e alternativa concreta. Nunca reduzir escopo, desativar segurança ou marcar checkbox concluído para avançar.

**Pontos de aprovação humana:** este plano; bases no fim de F0; interface real no fim de F7; decisão final F9. Intervenções no PC, aparelho, rede ou publicação respeitam as autorizações da sessão.

## 7. Riscos e mitigação

| Risco | Efeito | Mitigação | Onde |
|---|---|---|---|
| Nenhum upstream compila ou serve | Atraso na base | Base própria via ADR; upstream rejeitado não bloqueia | F0 |
| Licença incompatível (GPL/AGPL) | Contaminação de código | Só referência; copiar apenas com licença, SHA e avisos registrados | F0, F1 |
| Celular perdido/roubado | Controle indevido do PC | Revogação pelo PC, credencial por aparelho, confirmação em ação destrutiva (D-005) | F2, F7 |
| IP do PC muda (DHCP) | App não conecta | Editar endereço/reparear; reserva DHCP documentada; mDNS pós-MVP | F2, F8 |
| Captura bloqueada (sessão bloqueada, UAC, DRM) | Screenshot falha | Erro legível e distinto; nunca contornar | F5 |
| Antivírus/SmartScreen bloqueia Bridge não assinado | Instalação falha | Documentar em TROUBLESHOOTING; assinatura pública pós-MVP | F8 |
| Bridge reinicia no meio de mutação | Efeito incerto | Estado `unknown`, sem reexecução automática | F4, F7 |
| Tailscale indisponível | Suporte só LAN | Registrar NOT_RUN e declarar suporte apenas à LAN | F8 |

## 8. Depois do MVP

Ordem sugerida pelo manual (seção 13 de `docs/MANUAL_MVP.md`): v0.2 saúde e alertas (temperaturas, multi-PC) → v0.3 tela/arquivos → v0.4 Hermes → v0.5 macros → v0.6 mobilidade (widgets, Watch, Wake-on-LAN) → v1.0 robustez. Nada disso é planejado antes da aprovação F9; cada onda recebe roadmap próprio.

## 9. Diferenças em relação ao roadmap inicial

- G4 foi dividido em ações, screenshot e arquivos para tornar erros e entregas rastreáveis.
- A primeira entrega utilizável chega em F3, com pareamento e métricas reais, antes de construir todas as operações.
- Integração Hermes P1 fica depois do aceite do MVP; a prova de independência continua obrigatória em F8.
- Candidato que falha no G0 pode ser rejeitado, com base própria escolhida mediante ADR/aprovação; não exigir eternamente build de um upstream descartado.
- Valores de limite/expiração/retenção e regra de 29/30 sucessos foram explicitados para eliminar interpretações divergentes entre IAs.
- São usados os caminhos já adotados no esqueleto (`STATE.md`, `docs/adr/`, `docs/DECISIONS.md`); não criar documentos paralelos de estado.

**Revisão 2026-10-13 (esclarecimentos, sem mudança de escopo ou metas):**
- Fluxos numerados FL-1…FL-5 e coluna de estado por fase.
- Pinning do certificado via QR, descoberta sem mDNS, regra de firewall consentida e relógio do Bridge como referência das expirações.
- Rotas iniciais do contrato v1, tipo `Error`, `HermesHealth` fora do v1 e modelo de ameaças no `SECURITY.md`.
- Revogação pelo PC (celular perdido) em F2-04 e registro mínimo do piloto em F9-01.
- Novas seções de riscos (7) e pós-MVP (8); pendências D-004 (Orbit) e D-005 (biometria) em `docs/DECISIONS.md`.

## 10. Aprovação

**Plano: APPROVED.** A aprovação do proprietário em 2026-10-12 autoriza iniciar F0. A execução das fases seguintes permanece condicionada à decisão de base e aos critérios deste roadmap. A aprovação não seleciona antecipadamente um fork nem autoriza publicação.

Registro: **APROVADO pelo proprietário em 2026-10-12.**
