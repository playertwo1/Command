## [1.9.1](https://github.com/ggfto/DroidDeck/compare/v1.9.0...v1.9.1) (2026-10-16)


### Bug Fixes

* **log:** divide o log em 5 MB, so avisos das requisicoes do ASP.NET e apaga o log antigo gigante ([3dfd543](https://github.com/ggfto/DroidDeck/commit/3dfd543b347cf188ade4740f438fb908bcdcf260))
* **midia:** erro de thread errada recria o gerenciador de midia em vez de repetir a cada consulta ([742104e](https://github.com/ggfto/DroidDeck/commit/742104ec8850db8279e140b4dcc93257862cc499))

# [1.9.0](https://github.com/ggfto/DroidDeck/compare/v1.8.0...v1.9.0) (2026-10-16)


### Bug Fixes

* **obs:** pausar a gravacao nao mostra mais o botao como parado ([04586ee](https://github.com/ggfto/DroidDeck/commit/04586ee453df9501577c26e6101a0321ef10eeee))


### Features

* app e PC em ingles (segue o idioma do celular, com escolha em Aparencia) ([8001310](https://github.com/ggfto/DroidDeck/commit/8001310820fc97d9f9924cd1361411137598708d))
* **app:** base de idiomas (tr, escolha do idioma, Accept-Language) ([05144e5](https://github.com/ggfto/DroidDeck/commit/05144e5c4ef789dd00109226c977371e0601643f))
* **app:** varios PCs pareados, com troca pela barra do deck e deck guardado por PC ([7c0f5a5](https://github.com/ggfto/DroidDeck/commit/7c0f5a590b4aa3e1d26bfbea6354a1a45e07537c))
* botoes de dois estados (liga/desliga no PC, rotulo e icone do ativo) e botoes de informacao (relogio, clima, tocando agora, comando, URL) ([8a4a763](https://github.com/ggfto/DroidDeck/commit/8a4a7631ddf64fd2a49d181f65b1b650de2bf117))
* gravar macro pelo teclado do PC na multi-acao (so no configurador local) ([1b8f5ab](https://github.com/ggfto/DroidDeck/commit/1b8f5abd34c98ed25fa225b07d60c2c439ee1eb8))
* integracoes com Home Assistant, Spotify, Twitch e YouTube, com tela de conta comum e lista de integracoes ([e72b225](https://github.com/ggfto/DroidDeck/commit/e72b225b0537be3026c880db18c0e9d87758b9c1))

# [1.8.0](https://github.com/ggfto/DroidDeck/compare/v1.7.0...v1.8.0) (2026-10-16)


### Bug Fixes

* **app:** versiona a pasta backup/ do app, que o .gitignore do Visual Studio ignorava ([d3b9d96](https://github.com/ggfto/DroidDeck/commit/d3b9d9643aee6e3e5e68f8f3a63f31cd3955c588))
* **deck:** salvar um perfil nao muda mais a ordem dos perfis ([87c7346](https://github.com/ggfto/DroidDeck/commit/87c7346b4b0149c4bf2a2d8d86aafc6bc5211be2))
* **timer:** zerar um contador volta a contagem para 0 ([37650e5](https://github.com/ggfto/DroidDeck/commit/37650e560c8cbd106a3990bd37f219c25e8b0fb2))


### Features

* **app:** vibracao ao tocar nos botoes do deck ([1d39da4](https://github.com/ggfto/DroidDeck/commit/1d39da47d2e060ec76c645e4fff09843c0c6a41b))
* perfil pelo app em foco, backup, toque longo/duplo, deck offline e jogos da Steam ([18e736d](https://github.com/ggfto/DroidDeck/commit/18e736d772725b1ab015c3b24e7ee6fe9d84a605))
* timer/pomodoro/contador, requisicao HTTP, acoes do Windows e mais acoes do OBS ([143d5d8](https://github.com/ggfto/DroidDeck/commit/143d5d810c9759fa413bc1bd1bd2f5761cbd07ba))
* **windows:** instalador com atualizacao automatica e liberacao do firewall ([29cab1c](https://github.com/ggfto/DroidDeck/commit/29cab1cff73a493482d53ac9766d163e3c434be8))

# [1.7.0](https://github.com/ggfto/DroidDeck/compare/v1.6.0...v1.7.0) (2026-10-15)


### Bug Fixes

* **app:** tela do Discord mostra que as credenciais estao salvas no PC ([60690a5](https://github.com/ggfto/DroidDeck/commit/60690a516f424bd73b9fd6d1d9d86808df733178))
* **discord:** autorizacao revogada para de ser repetida em silencio ([b1e3777](https://github.com/ggfto/DroidDeck/commit/b1e3777f1fc193d75df09396e97d0b8d727911a1))
* **discord:** falha persistente de conexao aparece no log ([0e2189f](https://github.com/ggfto/DroidDeck/commit/0e2189f73ed8c3240b478880e31d90abf5b16507))


### Features

* **app:** temas, cor de destaque, estilos de botao e modo so deck ([85d2785](https://github.com/ggfto/DroidDeck/commit/85d278570b867ad8d955e486a06d312ae9829696))

# [1.6.0](https://github.com/ggfto/DroidDeck/compare/v1.5.0...v1.6.0) (2026-10-01)


### Bug Fixes

* **app:** remove o OneSignal ([e8a650f](https://github.com/ggfto/DroidDeck/commit/e8a650f7b91b8fd6a21c9ffbf24e5db3a5750e7b))
* **discovery:** responde com o IP da interface que alcanca o celular ([f523ed4](https://github.com/ggfto/DroidDeck/commit/f523ed40ebbc8eb802e9ec4114ab0546c4f09e98))
* **security:** acoes que executam codigo so sao criadas no PC ([c3214e0](https://github.com/ggfto/DroidDeck/commit/c3214e097acc68e5997d891a9dada6b13d8062ec))
* **security:** cifra os segredos em disco com DPAPI ([9b7c44f](https://github.com/ggfto/DroidDeck/commit/9b7c44fc99f73ff73f4cd8158e9b66d6ea113eed))
* **soundboard:** cache com nome estavel, download limitado e teto de tamanho ([74dab64](https://github.com/ggfto/DroidDeck/commit/74dab64c983ff80ec0978dd19257478ed83bbc88))
* **tuya:** reconecta apos falha no boot e grava o tuya.json de forma atomica ([924cd8f](https://github.com/ggfto/DroidDeck/commit/924cd8fd989fb120acae32b86da077260bbefea5))


### Features

* **app:** tela de boas-vindas que leva ao DroidDeck para Windows ([99c7688](https://github.com/ggfto/DroidDeck/commit/99c76889686fb7fa11e934d54a1240eeb4f43beb))
* **hotkey:** envia teclas com SendInput e aceita a tecla Windows (#) ([15ba488](https://github.com/ggfto/DroidDeck/commit/15ba488c360b214b51583d9f2129399b1bdbe188))

# [1.5.0](https://github.com/ggfto/DroidDeck/compare/v1.4.0...v1.5.0) (2026-08-19)


### Bug Fixes

* **app:** reconecta o SignalR quando a conexao inicial falha ([1b1e812](https://github.com/ggfto/DroidDeck/commit/1b1e812673db4cb76fc61276f4bb755674ce454b))
* **media:** comando do usuario para de ser descartado em silencio ([36ea4d1](https://github.com/ggfto/DroidDeck/commit/36ea4d1d58fc51919561cc46f77bcf8f81c27c99))


### Features

* **mixer:** botoes de volume de dispositivo do Windows ([c0a3f7e](https://github.com/ggfto/DroidDeck/commit/c0a3f7eb34a8cb650973053d1f6f7e18e66052dd))

# [1.4.0](https://github.com/ggfto/DroidDeck/compare/v1.3.1...v1.4.0) (2026-08-18)


### Bug Fixes

* **mixer:** usa o enumerador injetado e preenche nome/icone nos dois caminhos ([ca977dc](https://github.com/ggfto/DroidDeck/commit/ca977dc3fc8073ab5e03b152ada6bbd3014dd707))
* **tests:** destrava a suite, que nao compilava ([12d5b73](https://github.com/ggfto/DroidDeck/commit/12d5b73ce2903cdf66816790047cc7d045517018))


### Features

* **tuya:** botao reflete nivel e cor reais do aparelho ([3841b63](https://github.com/ggfto/DroidDeck/commit/3841b63ae2147d962cbf94484e8594ae946d8ef9))
* **tuya:** controla dispositivos Tuya/Smart Life pelo deck ([3574e5a](https://github.com/ggfto/DroidDeck/commit/3574e5a1944fb496b4b182aa1be510ed83cfc18a))

## [1.3.1](https://github.com/ggfto/DroidDeck/compare/v1.3.0...v1.3.1) (2026-08-04)


### Bug Fixes

* **media:** serializa o acesso WinRT e adiciona timeout e disjuntor ([1f43be4](https://github.com/ggfto/DroidDeck/commit/1f43be43d3dea31073a2cfbc3d7023decc398d74))
* **mixer:** libera os objetos COM do NAudio a cada enumeracao ([72bd159](https://github.com/ggfto/DroidDeck/commit/72bd159e074cc72256ff6f67d315d6ab0feb0fad))
* **rpc:** descarta o CancellationTokenSource de leitura a cada reconexao ([506423e](https://github.com/ggfto/DroidDeck/commit/506423eb0811d479c64ac3cad4833d8729185085))
* **soundboard:** descarta o MMDevice do playback e da listagem de saidas ([8247ca5](https://github.com/ggfto/DroidDeck/commit/8247ca5d130a9caf6923a2d05f8185d31e4258d3))
* **ui:** descarta o bitmap do QR de pareamento ([030020c](https://github.com/ggfto/DroidDeck/commit/030020c904f82532f0fe14b5a7a454203ebf4493))

# [1.3.0](https://github.com/ggfto/DroidDeck/compare/v1.2.1...v1.3.0) (2026-07-21)


### Features

* **soundboard:** adiciona soundboard (MyInstants + soundboard nativa do Discord) ([dee42e5](https://github.com/ggfto/DroidDeck/commit/dee42e531ca219930df8e57ccceee59ef3b8e43c))

## [1.2.1](https://github.com/ggfto/DroidDeck/compare/v1.2.0...v1.2.1) (2026-07-07)


### Bug Fixes

* **app:** nao limpa o campo Secret ao salvar credenciais do Discord ([25a14d3](https://github.com/ggfto/DroidDeck/commit/25a14d33b5cd4bdfbac25a2fd824d69fcde9519c))
* **app:** tela de erro 401/403 oferece 'Refazer pareamento' (nao prende o usuario) ([d950ca6](https://github.com/ggfto/DroidDeck/commit/d950ca68d9df1de9450fa121913a94853b75531e))
* **discord:** reconexao automatica continua (watchdog) + serializa ConnectAsync ([f59ed2e](https://github.com/ggfto/DroidDeck/commit/f59ed2e5a776d19a36ac907d515315d260e33ad0))
* **discord:** renova o token OAuth2 via refresh_token (sem reautorizar toda semana) ([73c26fa](https://github.com/ggfto/DroidDeck/commit/73c26fada2d3bd77472b40c2608df4f80fec2757))
* **discord:** timeout do handshake 5s->10s (READY chegava tarde e falhava) ([492745a](https://github.com/ggfto/DroidDeck/commit/492745ac786ed34637cb4aa2e67d5a3f50f60f3a))
* **discord:** trata opcode do frame IPC (responde PONG, trata CLOSE) ([26a7c51](https://github.com/ggfto/DroidDeck/commit/26a7c5113fe99a559741e0017eeab061de10cee3))
* **ram:** libera ico/bitmap GDI, handles de Process e MMDeviceEnumerator no audio ([5512a2c](https://github.com/ggfto/DroidDeck/commit/5512a2cdb1ac082cb33db14da9523fcbdef40912))
* **robustez:** app - reconexao SignalR indefinida, leak de assinatura, mounted, discovery ([62900ab](https://github.com/ggfto/DroidDeck/commit/62900abdbff6294f9f1a5959bd0a6dbfc3cb4ed4))
* **robustez:** backend - discovery resiliente, mixer sem 500, OBS hello, limpeza ([38501ae](https://github.com/ggfto/DroidDeck/commit/38501ae4aad228392510e879581b41b7cb57f6d0))
* **security:** nao vaza a API key em log nem no dialogo de debug do app ([f5ca4ee](https://github.com/ggfto/DroidDeck/commit/f5ca4ee5b7340863aa65354f5fd45484af900802))
* **security:** restringe CORS a loopback/LAN e blinda /api/pairing/local-key contra fetch cross-site ([fce4172](https://github.com/ggfto/DroidDeck/commit/fce41725d6dc3d5051a63bded68850cc8384947a))
* **security:** valida profile.Id contra path traversal ([f98ce35](https://github.com/ggfto/DroidDeck/commit/f98ce354f1b86d95f1a1de04276eae95ad852e91))


### Performance Improvements

* **ram:** cacheia nomes de instancia da GPU e libera counters no shutdown ([d7b612e](https://github.com/ggfto/DroidDeck/commit/d7b612eb09b923539049b1aaa7273314a16093f9))
* **ram:** so faz poll/broadcast com clientes conectados e mede midia a cada 3s ([24f4c67](https://github.com/ggfto/DroidDeck/commit/24f4c67b2cf6c1062d62027165ed91f829bdaeea))

# [1.2.0](https://github.com/ggfto/DroidDeck/compare/v1.1.0...v1.2.0) (2026-06-05)


### Bug Fixes

* **media:** nao cachear o session manager WinRT (RPC_E_WRONG_THREAD) ([4ea7945](https://github.com/ggfto/DroidDeck/commit/4ea79456164e2fe0049576342e64cd7a7c3682be))


### Features

* **media:** controle de midia no deck (play/pause, proxima, anterior, parar) ([2289b33](https://github.com/ggfto/DroidDeck/commit/2289b33fdab57b30050ba0c57324e74ca659d567))
* **media:** play/pause do deck reflete o estado (poller de midia ao vivo) ([3430093](https://github.com/ggfto/DroidDeck/commit/3430093e19550d3c935077220fb15012b216cbef))
* **obs:** controle do OBS via obs-websocket (cenas, gravação, stream) ([88ef320](https://github.com/ggfto/DroidDeck/commit/88ef3202eb963622c096464ff6adb30f5fdb0130))

# [1.1.0](https://github.com/ggfto/DroidDeck/compare/v1.0.0...v1.1.0) (2026-06-03)


### Bug Fixes

* **backend:** em dev servir wwwroot do diretorio atual, nao a copia velha de bin/ ([fa5533f](https://github.com/ggfto/DroidDeck/commit/fa5533f15dcfcdbd6cd239dacef2391c6997b4fd))
* **web:** desliga service worker (sem cache velho no navegador) + titulo DroidDeck ([8a7dc6c](https://github.com/ggfto/DroidDeck/commit/8a7dc6cef5345710e4e8290000b9c16cff9ae0e0))


### Features

* **audio:** junta saidas e entradas numa tela so (split deitado, empilhado em pe) ([76fca67](https://github.com/ggfto/DroidDeck/commit/76fca677e8f2da428a7be60822247713d31f0f35))
* **audio:** modo em pe vira scroll continuo (em vez de split 50/50) ([ddf4f15](https://github.com/ggfto/DroidDeck/commit/ddf4f15cbe0f71b42ff7fca293bed36ce728b63b))
* **discord:** config no web mais visivel (icone no topo) + largura desktop ([de20e73](https://github.com/ggfto/DroidDeck/commit/de20e731ab52c9327d96bb6101dd882f6dbab642))
* **discord:** tela de configuracao no app/web + aviso quando nao configurado ([06b03a5](https://github.com/ggfto/DroidDeck/commit/06b03a565c04e64dd3c2c7735b46965af4ce30a8))
