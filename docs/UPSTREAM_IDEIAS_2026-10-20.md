# Ideias aproveitáveis do upstream — 2026-10-20

**Histórico da proposta original (Claude → Codex):** o levantamento inicial usou notas de release e apenas o diff `b4647a6`. A revisão posterior leu diffs direcionados e notas adicionais; seus vereditos estão na seção 4 e foram incorporados ao `ROADMAP_V1.5.md`. As tabelas originais abaixo permanecem como fonte dos links.

Base do fork: DroidDeck v1.9.1 (`5cd2ddc`).

> **Revisão incorporada ao roadmap em 2026-10-20, a pedido do proprietário:** as seções 1–3 preservam a proposta original. A seção 4 substitui seus vereditos e responde às perguntas; implementação segue exclusivamente a fase ativa de `ROADMAP_V1.5.md`. A afirmação original sobre diffs não lidos descreve o levantamento anterior.

## 1. DroidDeck (fork upstream)

Releases: [v1.10.0](https://github.com/ggfto/DroidDeck/releases/tag/v1.10.0) · [v1.11.0](https://github.com/ggfto/DroidDeck/releases/tag/v1.11.0) · [diff v1.9.1…v1.11.0](https://github.com/ggfto/DroidDeck/compare/v1.9.1...v1.11.0)

### Aproveitar
| Ideia | Commit | Onde entra |
|---|---|---|
| Estados de conexão honestos e erros que dizem o que fazer | [b4647a6](https://github.com/ggfto/DroidDeck/commit/b4647a6260b427f679c4d782b10241daef56b0c2) | U0.1 — **portado** (M1) |
| Controle deslizante de volume, botões grandes, ícone GIF | [4c6ec61](https://github.com/ggfto/DroidDeck/commit/4c6ec61c7738a2bc63a00d28e429596d6a74e751) | U0.2 |
| Slider para luzes, OBS, Discord, monitor e música | [12736f6](https://github.com/ggfto/DroidDeck/commit/12736f68f2179a8d92614ca0a302f6287ea9d40b) | U0.2 |
| Conexão por cabo USB, sem Wi-Fi | [4cd92f6](https://github.com/ggfto/DroidDeck/commit/4cd92f6a8c2566576adcb0280bed8f8a43de7baf) | U0.3 / D0.3 |
| Configurador: trocar de botão atualiza o painel | [47d15ff](https://github.com/ggfto/DroidDeck/commit/47d15ff2df3f5c4a175ab3c8dc0f91a55eb408ef) | U0.4 |
| Grade do deck adaptada ao tamanho do aparelho | [88f528c](https://github.com/ggfto/DroidDeck/commit/88f528c622097b8f58195c0793b61d31c1612d40) | U0.4 |
| Medidores CPU/GPU circulares; dica no deck vazio | [0e1e1f2](https://github.com/ggfto/DroidDeck/commit/0e1e1f2d0f460e5dda235ba62f1b564a996a2b7a) | U0.4 |
| Timer/contador em botão pequeno; atalhos de backup | [270a5a1](https://github.com/ggfto/DroidDeck/commit/270a5a1e71bf68e55ceeb0396d0587670fb8d402) | U0.4 |
| Primeiro uso, edições seguras, conexão legível | [d4d5375](https://github.com/ggfto/DroidDeck/commit/d4d53759572ea6062fa84516befaebfe8210dc1a) | avaliar (choque com DESIGN.md/Amethyst) |
| Tray e janela de pareamento no idioma do Windows | [949e731](https://github.com/ggfto/DroidDeck/commit/949e731b44091de83b5f894a1f4391288b31a7f9) | avaliar |
| Clima no idioma do Windows | [9608517](https://github.com/ggfto/DroidDeck/commit/96085178443c7d29acea2dba3f57433fde05292c) | avaliar |

### Avaliar (v1.5 ou v2.0)
| Ideia | Commit | Observação |
|---|---|---|
| Contador de notificações do Windows | [2ee77b1](https://github.com/ggfto/DroidDeck/commit/2ee77b10550c54e075142f0ba0e359ecbc691d84) | privacidade de tela de bloqueio (v0.6) |
| Uso de IA: limites/tokens Claude e Codex | [80ddefd](https://github.com/ggfto/DroidDeck/commit/80ddefd3db26eeae0bdd6918ae84a0be230dc62b) | conferir onde lê credenciais |
| Condições por passo em multi-ação | [f94f5f7](https://github.com/ggfto/DroidDeck/commit/f94f5f7bf8d433499e7b2e12e81d7d09068545e2) | útil para rotinas (M1.4) |
| Importar perfis do Elgato Stream Deck | [6db2252](https://github.com/ggfto/DroidDeck/commit/6db2252f13566205f4d2fa5cc5c8774f146cc091) | v2.0 |
| App e PC em espanhol | [70f09f0](https://github.com/ggfto/DroidDeck/commit/70f09f02faa728caec216463adc976602e14c335) | v2.0 |
| Integrações Voicemeeter, Key Light, Hue, Govee, MQTT, Streamer.bot, VTube Studio | [31c099a](https://github.com/ggfto/DroidDeck/commit/31c099ac516f46b7971da9e0c54bd6102d648edd) · telas [8689282](https://github.com/ggfto/DroidDeck/commit/8689282cacc78ad4f91fd0c3d87cfc8296e4bbe5) | v2.0 |

### Não aproveitar
| Ideia | Commit | Motivo |
|---|---|---|
| Ação "script PowerShell/Python/.bat com argumentos" | [470fe1e](https://github.com/ggfto/DroidDeck/commit/470fe1e670e3441dbea4c7ba42db3109bfb152d1) | viola Regra 3 (execução arbitrária) |
| Gatilhos que apertam botão sozinhos | [4079f67](https://github.com/ggfto/DroidDeck/commit/4079f67fd4e90ba2fd0bbbcf394dd811cb382e0e) | ação sem confirmação; reavaliar v2.0 |
| Deck no navegador para iPhone/iPad | [e75169e](https://github.com/ggfto/DroidDeck/commit/e75169e31c73791a552ef32727014c421e221ec8) | superfície nova exposta na LAN |
| Perfil por link/QR público | [b443b20](https://github.com/ggfto/DroidDeck/commit/b443b2046e3f5720da8ffb2887528473c56f560d) | depende do site deles |
| Logo/ícones/site do DroidDeck | [0388f42](https://github.com/ggfto/DroidDeck/commit/0388f42172c9a40c63dd4e48ec409f2d5c729b0a) · [dd4d758](https://github.com/ggfto/DroidDeck/commit/dd4d758844a3038536bb13b78764162bbb16aa76) | marca própria (Command) |

## 2. Perguntas para o Codex
1. U0 deve ser cherry-pick por commit ou porte manual (o fork divergiu — `b4647a6` não aplicava)?
2. USB (`4cd92f6`) usa `adb reverse`? Exige ADB no PC do usuário — vale na v1.5?

## 4. Revisão consolidada 2026-10-20

**Método verificado:** fetch do upstream DroidDeck, notas oficiais das releases e diffs direcionados; `git apply --check` individual sem aplicação. Quatro dos 24 patches passaram: `270a5a1`, `9608517`, `70f09f0`, `31c099a`. Os demais falharam na árvore existente. Isso não é um cherry-pick de três vias nem prova de build/execução. Não houve auditoria integral de todos os arquivos das releases.

**Planejamento:** P = localizado, M = vários componentes, G = integração/protocolo amplo. Veredito refere-se ao recorte descrito, não à adoção integral do commit. Para rejeitados, tamanho representa a integração descartada. As URLs/SHAs completos dos commits estão nas tabelas originais; proveniência e licenças por componente em `../research/UPSTREAM.md`.

| Item | Veredito | Cherry-pick ou porte | Tamanho | Fase | Motivo |
|---|---|---|---|---|---|
| Erros/conexão `b4647a6` | APROVEITAR | Porte já registrado | P | U0.1/M1 | Sanitizar erros; aceite visual ainda pendente (R4). |
| Volume/botões/GIF `4c6ec61` | APROVEITAR | Porte | M | U0.2a | Mixer tipado; limitar mídia e preservar alvo (R3/R6). |
| Sliders ampliados `12736f6` | AVALIAR | Porte por provider | G | U0.2b/v2 | Substituir parâmetros/destinos genéricos por contratos autorizados (R3). |
| USB `4cd92f6` | AVALIAR | Porte obrigatório | G | U0.3/D0 | Consentimento, identidade, revogação e ferramentas verificadas (R4/R6). |
| Configurador `47d15ff` | APROVEITAR | Porte | P | U0.4a | Isolar formulário por botão; patch não aplica diretamente. |
| Grade `88f528c` | APROVEITAR | Porte | M | U0.4b | Preservar layout e legibilidade por aparelho. |
| Medidores/deck vazio `0e1e1f2` | APROVEITAR | Porte | P | U0.4b | Corrigir geometria sem inventar telemetria. |
| Timer/backup `270a5a1` | APROVEITAR | Compatível; adaptar | P | U0.4c | Texto upstream de 10 px com redução exige ajuste ao DESIGN. |
| Onboarding `d4d5375` | APROVEITAR | Porte parcial | M | U0.4d | Extrair orientação/edição segura; preservar Amethyst e escopo. |
| Idioma tray/pareamento `949e731` | APROVEITAR | Porte | P | U0.4d | Traduzir sem alterar segurança do código temporário (R4). |
| Clima `9608517` | APROVEITAR | Candidato a cherry-pick | P | U0.4d | Ajuste localizado ao idioma da consulta existente. |
| Notificações Windows `2ee77b1` | AVALIAR | Porte | M | U0.5a | Permissão explícita, contagem e privacidade na tela bloqueada (R4). |
| Uso IA `80ddefd` | AVALIAR | Porte restrito | G | U0.5b | Lê OAuth Claude e históricos locais; autorização e minimização necessárias (R4). |
| Condições `f94f5f7` | AVALIAR | Porte obrigatório | M | U0.5c/M1.4 opcional | Condições desconhecidas/horário inválido não podem liberar ação (R3). |
| Elgato `6db2252` | AVALIAR | Porte | G | v2 | Converter caminhos/atalhos em IDs; limitar ZIP/imagens e importação (R3/R6). |
| Espanhol `70f09f0` | AVALIAR | Candidato; completar | M | v2 | Patch compatível não cobre textos próprios Command. |
| Integrações `31c099a`/`8689282` | AVALIAR | Porte por provider | G | v2 | Só primeiro patch compatível; auditar credenciais/ações MQTT e externas (R3/R4). |
| Scripts `470fe1e` | REJEITAR | Não aplicar | M | Fora | Execução arbitrária continua proibida mesmo com confirmação (R3). |
| Gatilhos `4079f67` | REJEITAR | Não aplicar como está | G | Fora de v1.5 | Execução direta não garante confirmações/políticas do Command (R3). |
| Web/iOS `e75169e` | REJEITAR | Não aplicar nesta versão | G | Novo escopo futuro | Novo cliente/fluxo de autenticação; LAN não é proibição por si (R4). |
| Perfil público `b443b20` | REJEITAR | Não aplicar como está | M | Fora de v1.5 | Site externo e parâmetros de ações potencialmente privados (R3/R4/R6). |
| Branding `0388f42`/`dd4d758` | REJEITAR | Não aplicar assets | P | Marca própria I0 | Logo/ícones não são implementação do instalador Command. |

### Respostas e decisões de planejamento

1. **Porte seletivo como padrão.** Clima é o candidato simples a cherry-pick; os outros patches compatíveis ainda exigem ajustes de produto/política. Não aplicar lote nem considerar checagem textual como teste funcional.
2. **USB usa adb reverse e exige ADB/depuração autorizada.** Manter opcional na v1.5, condicionado a U0.3. Corrigir ativação automática, estado LAN estático único, confiança loopback quando falha identificação, serial em log, limpeza do reverse e download sem versão/hash fixos. Benefício de latência é hipótese não medida.

### Instalador e limites da revisão

Prioridade do proprietário: instalação direta no PC. I0 detalha `Command-Setup.exe` com Velopack já existente, identidade própria, updater Command, migração preservando dados, checksums e homologação em máquina limpa. `.github/workflows/release.yml` e `DroidDeck/Lib/AppUpdater.cs` ainda usam identidade/origem DroidDeck; precisam ser corrigidos em I0, não nesta revisão.

Fontes são as releases/commits vinculados acima, consultados em 2026-10-20. Fatos de origem não comprovam execução no Command. Tamanhos e sequência são estimativas de planejamento; testes/build/dispositivo nesta revisão: `NOT_RUN`. Nada foi instalado, publicado ou copiado de terceiros nesta atualização documental.
