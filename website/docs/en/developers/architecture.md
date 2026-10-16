# Architecture

DroidDeck is a monorepo with two halves that evolve together:

```
DroidDeck/
  DroidDeck/     C# backend (.NET 8): WinForms tray + ASP.NET Core + SignalR. Serves the API and the web app.
  app/           Flutter app: the phone runtime and the web configurator (same code).
  tests/         Backend tests.
  scripts/       Utilities (deploying the web build to wwwroot).
  website/       This documentation and the project's landing page.
```

## Backend (`DroidDeck/`)

- **Host**: `Program.cs` starts ASP.NET Core on `0.0.0.0:4787` and the WinForms tray
  (`frmPrincipal.cs`), unless `--headless` is passed. Services are registered by area in
  `ServiceRegistration.cs` (`AddDeckCore`, `AddActionProviders`, `AddIntegrations`).
- **Auth**: `Auth/` — API-key authentication handler (header, bearer or `access_token` query),
  constant-time comparison. The key is generated in `%LocalAppData%\DroidDeck\apikey`.
- **Actions**: `Actions/` — `IActionProvider` and the schema; `Actions/Providers/` has the built-in
  types (hotkey, media, mixer, multi, timer, Windows, HTTP, Steam…).
- **Integrations**: `Integrations/<Name>/` — one folder per integration with its service, its action
  provider and, where it has one, its controller and reconnect service (`Discord`, `Obs`, `Tuya`,
  `Soundboard`, `HomeAssistant`, `Spotify`, `Twitch`, `YouTube`). They all implement `IIntegration`
  (listed at `GET /api/integrations`); the account-based ones derive from `AccountIntegration`
  (encrypted settings, OAuth, one settings screen in the app).
- **Controllers**: `Controllers/` — REST endpoints for the deck, audio, media, library, info and macro.
- **Hub**: `Hubs/DeckHub.cs` — SignalR hub at `/deckHub`; pushes state to clients.
- **Services**: `Services/` — the deck itself: `ActionExecutorService` (dispatch by type),
  `ActionPolicy` (privileged actions), `StreamDeckConfigService` (profiles), `ButtonToggleService`
  (two-state buttons), `InfoService` (info buttons), `TimerService`, `ForegroundWatcher`,
  `BackupService`, `SystemMonitorService`, and the audio/media services.
- **Localization**: `Lib/Localization*.cs` — `L.T("…")` answers in English when the request asks for it.
- **Discovery**: `Lib/DiscoveryServer.cs` — UDP 7573 responder.
- **Static web**: the Flutter web build is served from `wwwroot/`.

## App (`app/`)

One Flutter codebase, two roles:

- **In the browser** (served by the PC) it opens the **configurator**: profiles, drag-and-drop grid,
  property panel.
- **On the phone** it is the **runtime**: the button grid (sized to the screen), the Audio tab, and
  settings for pairing and integrations.

Key places:

Key places:

- `lib/core/droiddeck_client/` — API models (`DeckButton`, profiles…).
- `lib/core/i18n/` — `tr("…")` and the English dictionaries (`en/*.dart`).
- `lib/src/stream_deck/buttons/` — how each action type draws its button (`renderers.dart` maps type
  → renderer; `button_look.dart` has the shared tile, two-state look and icons).
- `lib/src/stream_deck/widgets/` — grid, info buttons and the button editor (`editor/` holds its
  sections).
- `lib/src/stream_deck/actions/` — action picker, schema form and custom action editors.
- `lib/src/services/signalr_service.dart` — hub connection with endless reconnection.
- `lib/src/connection/` — connection keys and the list of paired PCs.
- `lib/src/config/` — settings pages (pairing, appearance, integrations).

## Contract

The app and the backend share:

- **REST** under `/api/...` — see [API](../reference/api.md);
- **SignalR** at `/deckHub` — server-to-client events;
- **UDP discovery** on port 7573;
- **Pairing URI** `droiddeck://pair?ip=&port=&key=`.

## Adding a new action type

Each action type is an **`IActionProvider`** (`DroidDeck/Actions/`). It executes the action and
describes its fields in an `ActionSchema`; the app's editor builds the form from
`GET /api/actions/schema`, so a simple type needs no Flutter code at all:

1. Implement `IActionProvider` in `DroidDeck/Actions/Providers/` (`Type`, `Describe()`, `ExecuteAsync()`).
   Fields are text, multiline, number, toggle or select; a select can load its options from an endpoint
   (`OptionsSource`, with `{field}` placeholders) and any field can depend on another (`When`).
2. Register it in `ServiceRegistration.AddActionProviders` (`services.AddSingleton<IActionProvider, MyProvider>()`).
3. If it has live state, implement `IStatefulActionProvider` (`StateEvent`, `GetState()`): `DeckHub`
   sends it on connect and the app listens to it.
4. Only if needed: a renderer in `app/lib/src/stream_deck/buttons/` (live state on the button), a custom
   editor in `app/lib/src/stream_deck/actions/editors/` (`Editor = "name"`), or a settings page.
5. If it runs code or reaches the network from the PC, add it to `ActionPolicy`'s privileged types.
