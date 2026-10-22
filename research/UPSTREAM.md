# Proveniência upstream — Command

**Registro:** 2026-10-20. Referências consultadas para planejamento; não significa auditoria integral, autorização para copiar qualquer arquivo ou licença única para todo o repositório.

## DroidDeck

- URL: https://github.com/ggfto/DroidDeck
- Base histórica do fork: `5cd2ddc632a2df69562b7a220e89455f1498de58` (v1.9.1).
- Release de referência: https://github.com/ggfto/DroidDeck/releases/tag/v1.11.0
- SHA v1.11.0: `2f3fc1614c7418dcfec6fd8ef56191bc488fb1b3`.
- Licenças verificadas no snapshot v1.11.0: `LICENSE` Apache-2.0; `app/LICENSE` GPL-3.0. Conferir avisos adicionais e licença no commit exato de cada arquivo antes do porte.
- Os 24 commits selecionados têm URL e SHA completo nas tabelas 1–3 de [UPSTREAM_IDEIAS_2026-10-20.md](../docs/UPSTREAM_IDEIAS_2026-10-20.md). Vereditos revisados e alcance da leitura estão na seção 4; não duplicar a lista de commits aqui.
- U0.4a (2026-10-21): porte manual seletivo do commit [`47d15ff2df3f5c4a175ab3c8dc0f91a55eb408ef`](https://github.com/ggfto/DroidDeck/commit/47d15ff2df3f5c4a175ab3c8dc0f91a55eb408ef); `app/LICENSE` no commit exato e no fork confirma GPL-3.0. A alteração adaptada é a chave de estado do painel do configurador; não houve cherry-pick.
- `git apply --check` individual na árvore com alterações existentes: compatíveis `270a5a1`, `9608517`, `70f09f0`, `31c099a`; demais 20 incompatíveis. Não houve aplicação, cherry-pick real, build ou teste durante essa revisão.
- Arquivos focalizados na revisão: UsbBridge/ActionPolicy/usb_route; SliderController; Conditions/MultiProvider; InfoService; AiUsageService; ScriptProvider; TriggerService; StreamDeckImport; ProfileShare; desktop_layout e timer_deck_button. Outros itens foram avaliados pelas notas oficiais e escopo do patch; não declarar revisão linha a linha de todos os arquivos.

## Hermes-Relay

- URL: https://github.com/Codename-11/hermes-relay
- Clone local consultado: `research/upstream/hermes-relay`, limpo em `62de6b51289d933a3f8d68841652b044130aa72f` (`server-v1.13.0`).
- Licença verificada no clone: MIT, Copyright 2026 Axiom Labs. Revalidar licença/avisos no snapshot novo durante A0.1.
- Método: notas oficiais e resolução de tags pela API GitHub em 2026-10-20; leitura focalizada de `plugin/dashboard/plugin_api.py` no clone para guards WS. Não houve checkout/instalação do snapshot novo.

| Release | SHA resolvido |
|---|---|
| [android-v1.15.0](https://github.com/Codename-11/hermes-relay/releases/tag/android-v1.15.0) | `f4b366389ba8081136e81ca1b76deb31ef844cce` |
| [android-v1.16.0](https://github.com/Codename-11/hermes-relay/releases/tag/android-v1.16.0) | `a5f671c06cca661d93e80fbcdd787a105c7d42b6` |
| [android-v1.17.0](https://github.com/Codename-11/hermes-relay/releases/tag/android-v1.17.0) | `52f3f7565811828824d42bc9b432296271a2f9c3` |
| [android-v1.18.0](https://github.com/Codename-11/hermes-relay/releases/tag/android-v1.18.0) | `6eee6b9b458d2c692ee6ee3b14bd7df3a0474ecf` |
| [android-v1.18.1](https://github.com/Codename-11/hermes-relay/releases/tag/android-v1.18.1) | `ca941b6ac999f74fff72e3363eb852cf5cbecb12` |
| [android-v1.19.0](https://github.com/Codename-11/hermes-relay/releases/tag/android-v1.19.0) | `da782a8d74eb6631ea2f097b3cc69c6452ec33de` |
| [server-v1.11.0](https://github.com/Codename-11/hermes-relay/releases/tag/server-v1.11.0) | `2ec7b7aac9dcd8294d4122848a88b190600d1539` |
| [server-v1.11.3](https://github.com/Codename-11/hermes-relay/releases/tag/server-v1.11.3) | `52f3f7565811828824d42bc9b432296271a2f9c3` |
| [server-v1.12.0](https://github.com/Codename-11/hermes-relay/releases/tag/server-v1.12.0) | `6eee6b9b458d2c692ee6ee3b14bd7df3a0474ecf` |
| [server-v1.13.0](https://github.com/Codename-11/hermes-relay/releases/tag/server-v1.13.0) | `62de6b51289d933a3f8d68841652b044130aa72f` |
| [server-v1.13.1](https://github.com/Codename-11/hermes-relay/releases/tag/server-v1.13.1) | `da782a8d74eb6631ea2f097b3cc69c6452ec33de` |

## Gate antes de copiar, instalar ou distribuir

- [ ] Registrar item U0/A0/I0, arquivos de origem/destino, SHA exato, licença e avisos aplicáveis. Manter referências e atribuições no porte.
- [ ] Identificar contratos de execução, autenticação/logs e arquivos afetados (R3/R4/R6); registrar adaptação e dependências.
- [ ] Para instalação: versão, origem, hash, suporte Windows e leitura do script/pacote. SHA de commit não é checksum do instalador. Não executar script remoto de branch móvel diretamente.
- [ ] Produzir evidência própria de build/teste/UI/dispositivo na implementação. Resultados upstream não são PASS do Command.
- [ ] Antes da distribuição, cumprir obrigações por componente, inclusive código-fonte correspondente quando aplicável; auditar identidade e origem de atualização do Command.

**Pendência:** versão e SHA do Hermes Agent, capacidade de esforço e necessidade real de plugin para notificações serão definidos em A0. Este registro não resolve essas hipóteses.
