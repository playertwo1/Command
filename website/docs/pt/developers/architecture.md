# Arquitetura

O DroidDeck é um monorepo com duas metades que evoluem juntas:

```
DroidDeck/
  DroidDeck/     C# backend (.NET 8): WinForms tray + ASP.NET Core + SignalR. Serves the API and the web app.
  app/           Flutter app: the phone runtime and the web configurator (same code).
  tests/         Backend tests.
  scripts/       Utilities (deploying the web build to wwwroot).
  website/       This documentation and the project's landing page.
```

## Backend (`DroidDeck/`)

- **Host**: `Program.cs` sobe o ASP.NET Core em `0.0.0.0:4787` e o ícone da bandeja
  (`frmPrincipal.cs`), a menos que receba `--headless`. Os serviços são registrados por área em
  `ServiceRegistration.cs` (`AddDeckCore`, `AddActionProviders`, `AddIntegrations`).
- **Auth**: `Auth/` — autenticação por chave de API (header, bearer ou `access_token` na query),
  com comparação em tempo constante. A chave é gerada em `%LocalAppData%\DroidDeck\apikey`.
- **Ações**: `Actions/` — `IActionProvider` e o schema; `Actions/Providers/` tem os tipos embutidos
  (atalho, mídia, mixer, multiação, timer, Windows, HTTP, Steam…).
- **Integrações**: `Integrations/<Nome>/` — uma pasta por integração, com o serviço, o provedor de ação
  e, quando tem, o controlador e o serviço de reconexão (`Discord`, `Obs`, `Tuya`, `Soundboard`,
  `HomeAssistant`, `Spotify`, `Twitch`, `YouTube`). Todas implementam `IIntegration` (listadas em
  `GET /api/integrations`); as que usam conta herdam de `AccountIntegration` (configuração cifrada,
  OAuth e uma tela de configuração única no app).
- **Controladores**: `Controllers/` — endpoints REST do deck, áudio, mídia, biblioteca, informação e macro.
- **Hub**: `Hubs/DeckHub.cs` — hub SignalR em `/deckHub`; envia o estado aos clientes.
- **Serviços**: `Services/` — o deck em si: `ActionExecutorService` (despacho por tipo),
  `ActionPolicy` (ações privilegiadas), `StreamDeckConfigService` (perfis), `ButtonToggleService`
  (dois estados), `InfoService` (botões de informação), `TimerService`, `ForegroundWatcher`,
  `BackupService`, `SystemMonitorService` e os serviços de áudio e mídia.
- **Idioma**: `Lib/Localization*.cs` — `L.T("…")` responde em inglês quando o pedido pede.
- **Descoberta**: `Lib/DiscoveryServer.cs` — responde no UDP 7573.
- **Web estático**: o build web do Flutter é servido de `wwwroot/`.

## App (`app/`)

Uma única base de código Flutter, com dois papéis:

- **No navegador** (servido pelo PC), abre o **configurador**: perfis, grade com arrastar e soltar,
  painel de propriedades.
- **No celular**, é o **runtime**: a grade de botões (dimensionada para a tela), a aba Áudio e as
  configurações de pareamento e integrações.

Pontos principais:

Lugares principais:

- `lib/core/droiddeck_client/` — modelos da API (`DeckButton`, perfis…).
- `lib/core/i18n/` — `tr("…")` e os dicionários de inglês (`en/*.dart`).
- `lib/src/stream_deck/buttons/` — como cada tipo de ação desenha o botão (`renderers.dart` liga o tipo
  ao desenhista; `button_look.dart` tem o botão comum, o visual de dois estados e os ícones).
- `lib/src/stream_deck/widgets/` — grade, botões de informação e o editor do botão (`editor/` tem as
  seções dele).
- `lib/src/stream_deck/actions/` — seletor de ação, formulário do schema e editores próprios.
- `lib/src/services/signalr_service.dart` — conexão com o hub, com reconexão sem fim.
- `lib/src/connection/` — chaves de conexão e a lista de PCs pareados.
- `lib/src/config/` — telas de configuração (pareamento, aparência, integrações).

## Contrato

O app e o backend compartilham:

- **REST** em `/api/...` — veja [API](../reference/api.md);
- **SignalR** em `/deckHub` — eventos do servidor para o cliente;
- **Descoberta UDP** na porta 7573;
- **URI de pareamento** `droiddeck://pair?ip=&port=&key=`.

## Adicionando um novo tipo de ação

Cada tipo de ação é um **`IActionProvider`** (`DroidDeck/Actions/`). Ele executa a ação e descreve
seus campos num `ActionSchema`; o editor do app monta o formulário a partir de
`GET /api/actions/schema`, então um tipo simples não precisa de nenhum código em Flutter:

1. Implemente `IActionProvider` em `DroidDeck/Actions/Providers/` (`Type`, `Describe()`, `ExecuteAsync()`).
   Os campos são texto, texto longo, número, liga/desliga ou seleção; uma seleção pode carregar as
   opções de um endpoint (`OptionsSource`, com `{campo}` substituído) e qualquer campo pode depender
   de outro (`When`).
2. Registre em `ServiceRegistration.AddActionProviders` (`services.AddSingleton<IActionProvider, MeuProvider>()`).
3. Se tiver estado ao vivo, implemente `IStatefulActionProvider` (`StateEvent`, `GetState()`): o
   `DeckHub` envia ao conectar e o app passa a ouvir.
4. Só se precisar: um desenhista em `app/lib/src/stream_deck/buttons/` (estado ao vivo no botão), uma
   tela própria em `app/lib/src/stream_deck/actions/editors/` (`Editor = "nome"`) ou uma página de configuração.
5. Se executar código ou acessar a rede a partir do PC, inclua o tipo entre os privilegiados do `ActionPolicy`.
