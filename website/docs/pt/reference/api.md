# API

O servidor do DroidDeck expõe uma API REST e um hub SignalR na porta `4787`. O app do celular e o
configurador usam os dois, e você pode usá-los para criar seus próprios clientes ou automações.

## Autenticação

Todo endpoint exige a chave de API, exceto `GET /api/ping` e `GET /api/pairing/local-key`.
Envie a chave de uma destas formas:

- header `X-API-KEY: <key>`
- header `Authorization: Bearer <key>`
- query string `?access_token=<key>` (usada no WebSocket do SignalR)

`GET /api/pairing/local-key` só retorna `{key}` para requisições do próprio PC (loopback) e recusa
requisições cross-site do navegador. O CORS só permite origens em loopback e em faixas de rede privada.

Falhas de integração retornam `502` com `{error}`.

## Ações privilegiadas

**Atalho de teclado**, **abrir app** e **ativar janela** executam código no PC, e a **requisição HTTP**
sai com o acesso de rede do PC, então ficam protegidas até de quem tem a chave. Requisições que não vêm do próprio PC (loopback) não podem:

- executá-las pelo `execute` — use o `press` com um botão salvo no PC;
- criar um botão com uma dessas ações, ou mudar os parâmetros dela, pelo `POST profiles`. Mover,
  renomear, mudar a cor e apagar esses botões continua liberado.

Uma multi-ação conta como privilegiada se qualquer passo dela for. Requisições recusadas retornam
`403` com `{error}`.

## Exemplos

```bash
# Is the server up?
curl http://192.168.0.10:4787/api/ping

# Toggle Discord mute
curl -X POST http://192.168.0.10:4787/api/StreamDeck/execute \
  -H "X-API-KEY: $KEY" -H "Content-Type: application/json" \
  -d '{"type":"discord","parameters":{"operation":"toggleMute"}}'

# Mute Spotify
curl -X POST http://192.168.0.10:4787/api/StreamDeck/execute \
  -H "X-API-KEY: $KEY" -H "Content-Type: application/json" \
  -d '{"type":"mixer","parameters":{"operation":"mute","processName":"Spotify"}}'
```

## Deck — `/api/StreamDeck`

| Método | Rota | Descrição |
|---|---|---|
| GET | `profiles` | Lista os perfis. |
| GET | `profiles/{id}` | Retorna um perfil. |
| POST | `profiles` | Cria ou atualiza um perfil. Dispara `ReceiveDeckUpdate`. |
| DELETE | `profiles/{id}` | Apaga um perfil. Dispara `ReceiveDeckUpdate`. |
| POST | `press` | Aperta um botão salvo (`{profileId, buttonId, gesture}`; `gesture` é `tap` (padrão), `longPress` ou `doubleTap`): o servidor executa a ação gravada no perfil para esse gesto. É o que o celular usa. |
| POST | `execute` | Executa uma ação avulsa (`{type, parameters}`). De fora do PC, ações privilegiadas retornam `403`. |
| GET / POST | `layout` | Lê / define o tamanho da grade (`{rows, columns}`). |

### Payload da ação

```json
{ "type": "hotkey", "parameters": { "keys": "^+m" } }
```

Todos os valores de parâmetros são strings.

| `type` | Parâmetros |
|---|---|
| `hotkey` | `keys` |
| `launch_app` | `path`, `arguments`? |
| `activatewindow` | `windowName` (título exato da janela) |
| `media` | `command`: `playpause`·`play`·`pause`·`next`·`previous`·`stop`; `sessionId`? |
| `mixer` | `operation`: `toggleMute`·`mute`·`unmute`·`setVolume`·`volumeUp`·`volumeDown`; `processName` **ou** `deviceId` (`default` ou o id de um endpoint); `deviceKind`: `output`·`input`; `volume` (0–100); `step` (1–50) |
| `multi` | `steps`: string com um array JSON `[{"type","parameters","delayMs"}]` |
| `discord` | `operation`: `toggleMute`·`mute`·`unmute`·`toggleDeafen`·`joinChannel` (`channelId`)·`disconnect`·`inputVolumeUp/Down`·`outputVolumeUp/Down` (`delta`)·`setInputVolume`·`setOutputVolume` (`value`)·`toggleVoiceMode`·`setVoiceMode` (`mode`: `VOICE_ACTIVITY`·`PUSH_TO_TALK`)·`userMute` (`userId`)·`userVolume` (`userId`, `value` 0–200) |
| `obs` | `operation`: `setScene` (`scene`)·`toggleRecord`·`startRecord`·`stopRecord`·`toggleStream`·`toggleVirtualCam`·`toggleReplayBuffer`·`saveReplay`·`toggleInputMute` (`inputName`) |
| `soundboard` | `operation`: `play`·`stop`; `source`: `myinstants` (`id`, `url`, `title`) ou `discord` (`soundId`, `guildId`) |
| `tuya` | `deviceId`, `code`, `operation`: `toggle`·`set`; `value`, `valueType` |
| `homeassistant` | `operation`: `toggle`·`turn_on`·`turn_off`·`brightness` (`step`)·`scene`·`script`·`display`·`service` (`service` = `domínio.serviço`, `data` em JSON); `entityId` |
| `spotify` | `operation`: `playPause`·`next`·`previous`·`like`·`shuffle`·`repeat`·`volume` (`step`)·`playlist` (`uri`, `shuffleOn`)·`nowPlaying` |
| `twitch` | `operation`: `marker` (`description`)·`clip`·`ad` (`length`)·`chat` (`message`)·`poll` (`question`, `choices` uma por linha, `duration`)·`title` (`title`)·`status` |
| `youtube` | `operation`: `chat` (`message`)·`status` |

`open_profile` e `back` existem só no celular.

## Áudio — `/api/v1/Mixer`, `/api/v1/Media`

| Método | Rota | Descrição |
|---|---|---|
| GET | `Mixer/out`, `Mixer/in` | Dispositivos de saída / entrada com suas sessões de app. |
| GET | `Mixer/out/{id}`, `Mixer/in/{id}` | Um dispositivo. |
| PUT | `Mixer/out/{id}`, `Mixer/in/{id}` | `{session, volume?, mute?}` — `session` é o id de um processo, ou `-1` para o dispositivo inteiro. |
| GET | `Media/sessions` | Sessões de mídia, com miniaturas. |
| GET | `Media/sessions/{id}` | Uma sessão. |
| POST | `Media/sessions/{id}/command` | `{command}`. |

Um perfil é `{id, name, rows, columns, isDefault, buttons, autoSwitchApps}`; um botão tem `action`,
`longPressAction` e `doubleTapAction` (cada um `{type, parameters}` ou `null`). A regra das ações
privilegiadas vale para os três.

Botões de dois estados acrescentam `toggle` (bool), `activeAction` (roda no toque que desliga),
`activeLabel`, `activeIconName` e `activeIconBase64`. Botões de informação usam `dynamicType`
(`cpu_monitor`, `memory_monitor`, `gpu_monitor`, `network_monitor`, `clock`, `weather`, `now_playing`,
`command`, `url`) com `dynamicParameters` (`city`, `units`, `command`, `url`, `path`, `format`,
`interval`…); `command` e `url` seguem a regra das ações privilegiadas.

## Biblioteca — backup, Steam, apps

| Método | Caminho | Descrição |
|---|---|---|
| GET | `/api/backup` | Baixa todos os perfis num `.droiddeck` (zip). |
| POST | `/api/backup` | Restaura um `.droiddeck` (corpo = o arquivo). Perfis com o mesmo id são substituídos. De fora do PC, recusa com `403` se for criar botões privilegiados. |
| GET | `/api/steam/games` | Jogos instalados na Steam (`{value: appId, label: nome}`). |
| GET | `/api/steam/icon/{appId}` | `{iconBase64}`: PNG quadrado recortado da capa do jogo. |
| GET | `/api/system/apps` | Programas com janela visível (para a troca automática de perfil). |
| GET | `/api/system/info` | `{name, version}` — o nome do PC no Windows, usado para identificar os PCs pareados. |
| GET | `/api/info` | Valores atuais dos botões de informação, o que está tocando e os botões de dois estados ligados. |
| GET / POST | `/api/macro`, `/api/macro/start`, `/api/macro/stop` | Gravação de macro pelo teclado. Só do próprio PC (senão `403`); `stop` devolve `{steps}` no formato da multiação. |

## Tipos de ação — `/api/actions`

| Método | Caminho | Descrição |
|---|---|---|
| GET | `schema` | Todos os tipos de ação, com título, ícone, categoria e campos. O editor monta o formulário a partir disto. |
| GET | `state/{type}` | Estado ao vivo atual de um tipo (o mesmo conteúdo do evento SignalR dele). |
| GET | `timer/targets` | Botões de timer que outro botão pode controlar. |
| GET | `windows/audio-devices?kind=output\|input` | Dispositivos de áudio ativos (`{value, label}`). |

## Integrações

| Prefixo | Endpoints |
|---|---|
| `/api/discord` | `POST config` `{clientId, clientSecret}` · `POST connect` · `GET state` · `GET guilds` · `GET channels/{guildId}` · `GET voice-channel` · `POST mute` · `POST deafen` · `GET soundboard-sounds` · `POST play-soundboard` |
| `/api/obs` | `POST config` `{host, port, password}` · `POST connect` · `GET state` · `GET scenes` · `GET audio-inputs` · `GET sources` · `GET scene-items?scene=` · `GET filters?source=` |
| `/api/Soundboard` | `GET search?q=` · `GET trending` · `POST play` · `POST stop` · `GET state` · `GET devices` · `GET/POST config` |
| `/api/tuya` | `POST pair/start` `{userCode}` · `POST pair/poll` (410 quando o QR expirou) · `GET state` · `POST connect` · `POST devices/refresh` · `POST command` `{deviceId, code, value}` |
| `/api/integrations/{nome}` | `homeassistant`, `spotify`, `twitch`, `youtube`. `GET` estado `{connected, configured, account, message, loginPending, userCode, verificationUri, redirectUri, fields}` · `POST` os campos da configuração (conecta ou abre o login no navegador do PC) · `DELETE` esquece a conta · `GET options/{lista}` (`entities?operation=`, `playlists`) · `GET callback` (retorno do OAuth, sem chave da API) |

As respostas seguem o `Accept-Language` do pedido: com `en`, tipos de ação, rótulos dos campos e
mensagens de erro vêm em inglês.

## Hub SignalR — `/deckHub`

Conecte com `?access_token=<key>`. O hub só envia eventos; os comandos passam pelo REST.

| Evento | Payload |
|---|---|
| `ReceiveSystemStats` | `{cpuUsage, ramUsage, ramTotal, ramAvailable, netUpKBps, netDownKBps, gpuUsage}` — a cada segundo |
| `ReceiveMediaStatus` | `{playing}` |
| `ReceiveMediaState` | `{sessionId, command, playing}` |
| `ReceiveVolumeChange` | `{deviceId, type, data}` |
| `ReceiveMuteState` | `{processName, muted}` |
| `ReceiveDeckUpdate` | `{profileId}` |
| `ReceiveLayoutUpdate` | `{rows, columns}` |
| `ReceiveDiscordState` | Conexão, mudo/ensurdecido, canal, volumes, modo de voz, participantes |
| `ReceiveObsState` | Conexão, cena atual, gravação/transmissão/câmera virtual/replay, cenas, entradas de áudio |
| `ReceiveTuyaState` | Conexão, push, dispositivos com status e funções |
| `ReceiveTuyaDeviceState` | `{deviceId, status}` — só os valores alterados |
| `ReceiveTimerState` | `{buttonId: {mode, running, finished, elapsedMs, durationMs, count, phase, cycles}}` — a cada mudança |
| `ReceiveWindowsState` | `{defaultOutput, defaultInput}` — ids dos dispositivos de áudio padrão |
| `ReceiveAutoProfile` | `{profileId, app}` — perfil do app em foco; `profileId` nulo quando o app não tem perfil |
| `ReceivePlaybackState` | `{playing, title}` — soundboard |
| `ReceiveButtonToggles` | `{buttonId: true}` — botões de dois estados ligados |
| `ReceiveInfoState` | `{buttonId: {text, sub, code, isDay, error}}` — botões de clima, comando e URL |
| `ReceiveNowPlaying` | `{title, artist, playing, thumbnailBase64}` |
| `ReceiveHomeAssistantState` | `{connected, entities: {id: {state, name, unit, brightness, color}}}` — entidades usadas nos botões |
| `ReceiveSpotifyState` | `{connected, account, playing, track, artist, liked, shuffle, repeat, volume, device, coverBase64}` |
| `ReceiveTwitchState`, `ReceiveYouTubeState` | `{connected, account, live, viewers, title}` |

Ao conectar, o novo cliente recebe o estado atual do Discord, do layout, do OBS e da Tuya.

## Descoberta — UDP 7573

Envie o texto ASCII `DroidDeckDiscoveryRequest` em broadcast para a porta 7573. O servidor responde
com `{"ip": "...", "name": "<machine name>"}`. A descoberta nunca retorna a chave de API.

## URI de pareamento

`droiddeck://pair?ip=<ip>&port=4787&key=<key>`
