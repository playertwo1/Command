# COMMAND — Manual do MVP (transcrição)

> Transcrição em Markdown de [`COMMAND_Manual_MVP.docx`](../COMMAND_Manual_MVP.docx) (v1.0, 10/10/2026) para leitura por agentes e diffs. O `.docx` é a fonte original e prevalece em caso de divergência; não edite esta transcrição para mudar escopo — mudanças vão para `ROADMAP.md`/`docs/DECISIONS.md`. Gerada em 2026-10-13.

**Projeto pessoal · versão 1.0 · Manual do MVP e plano de evolução**

Controle direto e seguro de computadores Windows pelo Android, sem serviço externo de IA.

10 de outubro de 2026 · Planejamento · Base de implementação para Codex

| Decisão | Posicionamento |
|---|---|
| Produto | Um APK Android + um Bridge Windows. |
| Stack | Kotlin / Jetpack Compose / Material 3 (AMOLED); Bridge C#/.NET; Room para histórico local. |
| Primeiro teste | Galaxy S25 Ultra e um PC Windows pessoal; notebooks depois. |
| MVP | Conexão segura, telemetria, apps, screenshot, arquivos, histórico e prova de independência operacional. |
| Ordem | Avaliar forks → contratos/segurança → Bridge → Android → ações → piloto de 7 dias. |

## 1. O problema que o Command resolve

Hoje, controlar seu ecossistema exige alternar entre terminal, mensageiros, n8n, navegador e interfaces de projeto. O Command simplifica o acesso, mas não deve esconder o estado real de uma ação nem depender de IA.

## 2. Princípios de produto

- Controle direto: consultar RAM, CPU, processos, screenshots ou arquivos sem serviço externo.
- Segurança por padrão: ações cadastradas, autorização por dispositivo e auditoria; sem shell genérico.
- Mobile primeiro: três toques ou menos para ações favoritas, estados claros e tema preto AMOLED.
- Confiabilidade visível: distinguir enviado, aceito, executando, concluído e falhou.

## 3. Arquitetura de referência

| Camada | Função | Não faz |
|---|---|---|
| Command Android | Navegação Compose, autenticação, comandos, histórico, screenshot e transferências | Não executa scripts Windows nem armazena segredos do PC em texto |
| Command Bridge (.NET) | API privada, catálogo de ações, sensores, processos, captura e pasta autorizada | Não aceita terminal irrestrito |
| Transporte | LAN e, opcionalmente, Tailscale privado + autenticação da API | Não dispensa validação e controle de acesso |

Fluxo: Android → Bridge → Windows → resultado assinado/correlacionado → histórico.

## 4. Como aproveitar o open source sem criar uma colcha de retalhos

Primeiro rodamos as bases candidatas separadamente. A escolha do fork principal só acontece após build reproduzível, teste de APIs, checagem de licença e análise de manutenção. Evite juntar vários repositórios diretamente ou vincular o runtime do PC a um cliente CLI externo.

| Papel | Candidato | Decisão inicial |
|---|---|---|
| Bridge Windows | DroidDeck | Auditar backend .NET 8, REST/SignalR e reutilizar seletivamente se seguro. |
| Sensores | LibreHardwareMonitor | Biblioteca para temperaturas quando drivers/sensores suportarem. |
| Ações de Windows | HASS.Agent | Referência; não adicionar dependência de Home Assistant ao MVP. |
| Arquivos | LocalSend | Referência do UX/protocolo; MVP pode usar transferência própria restrita. |

## 5. Escopo do MVP — o que o usuário realmente verá

| Tela | Dados principais | Ação dominante |
|---|---|---|
| Início | PC favorito, estado, ação recente | Abrir ação favorita |
| Computadores | Dispositivos registrados e last seen | Selecionar PC |
| Detalhe do PC | CPU, RAM, disco, uptime, apps, print e arquivos | Acionar função direta |
| Ações | Catálogo autorizado no Bridge | Abrir/fechar app ou transferir |
| Atividade | Histórico com resultado, erro e horário | Inspecionar / repetir quando seguro |

## 6. Cinco histórias de uso para o primeiro piloto

1. Abrir Obsidian: no celular, seleciono o desktop e toco em Obsidian. O Windows abre; recebo confirmação real e histórico.
2. Abrir o Orbit: escolho uma ação pré-cadastrada no PC que aponta à pasta/projeto correto, sem o Android enviar caminhos arbitrários.
3. Solicitar print: autorizo a captura naquele instante, visualizo a imagem, salvo ou compartilho. Se Windows estiver bloqueado, recebo erro legível.
4. Enviar e receber arquivo: seleciono arquivo de teste, transfiro para pasta autorizada e baixo novamente com verificação SHA-256.
5. Encerrar app de teste: escolho processo permitido, confirmo encerramento e vejo o estado real; processos críticos nunca aparecem como opção.

## 7. Requisitos técnicos mínimos

- Contrato API versionado: /health, /devices/self, /metrics, /apps, /actions, /screenshots, /transfers e /history (rotas propostas, não API upstream comprovada).
- Pareamento no PC com QR/token temporário; identidade única do Android; revogação e rotação simples.
- Ações por action_id + argumentos tipados e validados. `open_app` e `close_app` apenas em lista de aplicações autorizadas no Windows.
- Coleta de CPU/RAM/disco/uptime real. Temperatura CPU/GPU somente se sensor suportado e com fallback Indisponível.
- Screenshot sob demanda em sessão interativa; proibir captura silenciosa recorrente e não contornar tela bloqueada/UAC.
- Upload/download por pasta sandbox: validação de caminho normalizado, junction/symlink, tamanho e integridade, sem acesso à pasta inteira do usuário.
- Receber ACK da tarefa é diferente de sucesso final. Ter status e código de erro, idempotency-key e timestamps.
- Keystore Android, TLS/túnel privado, limitação de taxa e logs sem credenciais, nomes de arquivos sensíveis ou imagem integral.

## 8. Contratos de dados sugeridos

| Entidade | Campos essenciais |
|---|---|
| DeviceState | device_id, name, online, last_seen, bridge_version, capabilities |
| MetricSample | sample_at, cpu_pct, ram_used, ram_total, disks, gpu_pct?, temperatures? |
| ActionRequest | request_id, action_id, device_id, typed_args, user_confirmation, idempotency_key |
| ActionResult | request_id, state, started_at, finished_at, error_code?, message? |
| TransferJob | job_id, direction, local_name, bytes, sha256, state, expires_at |

As rotas e entidades acima são propostas do Command, não promessas de compatibilidade com a API do DroidDeck.

## 9. Segurança, privacidade e limites

- Não expor o Bridge em endereço público ou fazer port forwarding sem proteção. Tailscale é uma opção de transporte privado, mas cada request ainda deve ser autenticada.
- Operações destrutivas requerem confirmação. Apps autorizados são cadastrados localmente e podem ser revogados no PC.
- Não instalar serviço Windows com privilégio elevado sem necessidade. Abrir programas/capturar tela requer sessão interativa; o serviço em segundo plano tem restrições.
- Conservar histórico técnico mínimo; política de retenção e botão para limpar dados locais. Mensagens, arquivos e imagens pessoais não vão para logs.
- Chaves do Bridge devem ter expiração/rotação e revogação por dispositivo. Testar rede desconhecida, repetição e conexão interrompida.
- Caso o aparelho contenha dados de clientes, não usar dados reais nos testes; utilizar exclusivamente arquivos, prints e perfis fictícios.

## 10. Ordem de trabalho e checkpoints

| Gate | Entrega | Evidência obrigatória |
|---|---|---|
| G0 | Auditar forks e licenças, reproduzir builds | ADRs com SHA + vídeos/capturas de builds |
| G1 | Criar monorepo, contratos e CI | Build Android/.NET e testes de contrato |
| G2 | Bridge autenticado, pareamento e allowlist | Teste de intrusão básico e revogação |
| G3 | UI Compose e telemetria | Capturas das telas com estados normais/offline |
| G4 | Ações, screenshot e transferências | Testes e logs de 5 casos de uso |
| G6 | Piloto de 7 dias + decisão go/no-go | MVP_APPROVAL.md e métricas de uso |

Papéis recomendados: Codex executa e registra; auditor revisa; proprietário aprova G0 (base/fork) e G6 (MVP). Sem merge automático na main. Cada gate termina em PASS, FAIL ou ESCALATE.

## 11. Testes de aceitação e decisão de MVP

- Executar pelo menos 30 comandos diretos distribuídos ao longo de 7 dias, sem recorrer a terminal para os cinco fluxos.
- Meta recomendada: ≥95% de sucesso real; nenhum comando executado sem autorização; nenhuma transferência corrompida.
- Ações comuns em até três toques após escolher o computador, sem incluir confirmação de segurança.
- Testar rede local e Tailscale (quando disponível), perda de Wi-Fi, reconexão, Windows bloqueado, notebook suspenso, Bridge reiniciado.
- Testar repetição acidental de cliques, revogação de credenciais, arquivo acima do limite, path traversal e falha de checksum.
- Demonstrar que PC/telemetria/apps/print/arquivos continuam operacionais sem serviços externos.
- Registro final: PASS (aprovar evolução), FAIL (corrigir) ou ESCALATE (decisão humana sobre limitação importante).

## 12. Plano de instalação e primeira execução (sem comandos perigosos)

1. No Windows pessoal, separar um usuário/pasta de teste e confirmar se .NET SDK/Runtime, Android Studio/JDK e Git estão disponíveis; registrar versões.
2. Clonar candidatos em diretório de pesquisa, fixar commit e auditar conteúdo antes de executar scripts ou instaladores. Nunca rodar pipe-to-shell sem revisão.
3. Compilar DroidDeck Windows isoladamente; anotar comandos de build reais do README vigente e problemas.
4. Instalar somente o Bridge selecionado em sessão do usuário, habilitando a API na LAN privada e pareamento local autorizado.
5. Instalar APK de teste no Galaxy S25 Ultra, parear, revogar/renovar token e confirmar que somente o dispositivo permitido acessa o Bridge.
6. Testar as cinco ações com dados fictícios; confirmar logs/resultados e comportamento offline.
7. Após funcionar na rede local, configurar Tailscale nos aparelhos e repetir o teste de conexão sem expor portas públicas.

## 13. Ideias para depois do MVP aprovado

| Onda | Valor | Itens |
|---|---|---|
| v0.2 — Saúde | Visibilidade e alertas | Temperaturas, histórico de carga, alertas CPU/RAM, bateria, múltiplos PCs, serviços. |
| v0.3 — Tela/arquivos | Controle mais rico | Filas retomáveis, compartilhar Android → PC, recorte/anotação de prints, integração externa RustDesk. |
| v0.5 — Macros | Produtividade | Modo Trabalho/Jogo/Desenvolvimento, n8n, catálogo de ações, sequências com rollback. |
| v0.6 — Mobilidade | Acesso imediato | Widgets, tiles, Galaxy Watch, notificações, Wake-on-LAN com host sempre ligado. |
| v1.0 — Produto | Robustez | Assinatura do Bridge, atualização segura, backups, permissões granulares, testes de longo prazo. |

## 14. Riscos e decisões ainda em aberto

- Bridge: reutilizar backend DroidDeck versus criar Bridge pequeno em .NET — API e permissões não devem ser copiadas sem auditoria.
- Temperaturas de GPU/CPU: modelos e drivers podem limitar sensores. Não tratar ausencia de leitura como falha geral do aplicativo.
- Telas protegidas/Windows bloqueado: screenshot não deve tentar ultrapassar barreiras do sistema.
- Transferências remotas grandes: escolher protocolo e limite no MVP; retomada fica após piloto.
- Licenças copyleft: manter OliveTin/RustDesk apenas como referências/integração externa até análise jurídica adequada.

## 15. Catálogo de repositórios e links

Links verificados como páginas de repositório em 10/10/2026. Os campos “uso” são recomendações, não afirmação de que todos os componentes sejam interoperáveis. Antes de copiar código, conferir LICENSE e dependências no commit fixado.

| # | Repositório | Uso | Estratégia | Observação |
|---|---|---|---|---|
| 02 | [DroidDeck](https://github.com/ggfto/DroidDeck) | Bridge .NET 8, controle Windows, telemetria, macros. | BASE DE REFERÊNCIA/FORK SELETIVO DO BRIDGE. | Apache-2.0; separar backend do Flutter. |
| 03 | [LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor) | Biblioteca .NET de sensores de hardware. | INTEGRAR BIBLIOTECA SE COMPATÍVEL. | MPL-2.0; verificar avisos/arquivos modificados. |
| 06 | [HASS.Agent](https://github.com/hass-agent/HASS.Agent) | Sensores, eventos e ações Windows. | REFERÊNCIA DE IMPLEMENTAÇÃO. | MIT. |
| 07 | [LocalSend](https://github.com/localsend/localsend) | Compartilhamento de arquivos local. | REFERÊNCIA/INTEGRAÇÃO FUTURA. | Apache-2.0. |
| 08 | [OpenCode Remote](https://github.com/vchhikara/opencode-remote) | Android nativo, bridge, aprovações e sessões de agente. | REFERÊNCIA DE UX/SESSÕES. | MIT. |
| 09 | [PC Remote](https://github.com/Abhishek-karma/pc-remote) | Controle Android-Windows com WSS e descoberta. | REFERÊNCIA DE COMUNICAÇÃO. | Confirmar licença antes de copiar. |
| 13 | [OliveTin](https://github.com/OliveTin/OliveTin) | Comandos predefinidos e histórico operacional. | INSPIRAÇÃO, NÃO COPIAR CÓDIGO. | AGPL-3.0. |
| 14 | [Macro Deck](https://github.com/Macro-Deck-App/Macro-Deck) | Builder de macros e perfis de botões. | INSPIRAÇÃO PÓS-MVP. | Conferir licenças por componente. |
| 15 | [Deskmate](https://github.com/JakubWawrzola/deskmate) | Sensores e ações Windows com Home Assistant. | REFERÊNCIA DE TELEMETRIA. | Conferir licença. |
| 16 | [Home Assistant Android](https://github.com/home-assistant/android) | Widgets, notificações e experiência Android. | INSPIRAÇÃO PÓS-MVP. | Conferir obrigações de licença. |
| 17 | [KDE Connect](https://github.com/KDE/kdeconnect-kde) | Comandos remotos e integração entre dispositivos. | REFERÊNCIA. | Conferir licença dos módulos. |
| 18 | [Wear OS Remote](https://github.com/nnyj/wearos-remote) | Wake-on-LAN e comandos pelo relógio. | INSPIRAÇÃO PÓS-MVP. | Conferir licença. |
| 19 | [RustDesk](https://github.com/rustdesk/rustdesk) | Controle de desktop remoto ao vivo. | INTEGRAÇÃO EXTERNA FUTURA. | AGPL-3.0. |
| 20 | [n8n](https://github.com/n8n-io/n8n) | Execução de workflows. | INTEGRAÇÃO PÓS-MVP. | Conferir licença e API. |

## 16. Prompt de início para o Codex

“Projeto Command: siga ROADMAP.md e execute apenas o Gate G0. Analise DroidDeck e LibreHardwareMonitor. Registre licença, commit SHA e build reprodutível. Gere ADR-001 para Android, ADR-002 para Windows Bridge e uma matriz de APIs/segurança. Não crie interface nem módulos próprios antes da aprovação humana. Não faça merge na main, não rode scripts remotos sem auditoria e não acesse dados pessoais. Entregue PASS/FAIL/ESCALATE, evidências e a proposta do G1.”

Documento de planejamento: não representa código implementado nem testes executados. Contratos e metas devem ser aprovados durante o G0.
