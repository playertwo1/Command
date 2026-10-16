# Architecture

DroidDeck is a monorepo with two halves that evolve together:

```
DroidDeck/
  RaspDeck/      C# backend (.NET 8): WinForms tray + ASP.NET Core + SignalR. Serves the API and the web app.
  app/           Flutter app: the phone runtime and the web configurator (same code).
  tests/         Backend tests.
  scripts/       Utilities (deploying the web build to wwwroot).
  website/       This documentation and the project's landing page.
```

## Backend (`RaspDeck/`)

- **Host**: `Program.cs` starts ASP.NET Core on `0.0.0.0:4787` and the WinForms tray
  (`frmPrincipal.cs`), unless `--headless` is passed.
- **Auth**: `Auth/` — API-key authentication handler (header, bearer or `access_token` query),
  constant-time comparison. The key is generated in `%LocalAppData%\DroidDeck\apikey`.
- **Controllers**: `Controllers/` — REST endpoints per area (StreamDeck, Mixer, Media, Discord, OBS,
  Soundboard, Tuya).
- **Hub**: `Hubs/DeckHub.cs` — SignalR hub at `/deckHub`; pushes state to clients.
- **Services**: `Services/`
    - `ActionExecutorService` — dispatches a button action by `type` to the right service.
    - `StreamDeckConfigService` — profile and layout persistence.
    - `SystemMonitorService` — CPU/GPU/RAM/network sampling, broadcast every second.
    - `MixerService`, `AudioControlService`, `MediaControlService` — NAudio Core Audio and WinRT media sessions.
    - `DiscordRpcService`, `ObsService`, `SoundboardService`, `TuyaService` — integrations, each with
      an `*AutoConnect` hosted service that reconnects in the background.
- **Discovery**: `Lib/DiscoveryServer.cs` — UDP 7573 responder.
- **Static web**: the Flutter web build is served from `wwwroot/`.

## App (`app/`)

One Flutter codebase, two roles:

- **In the browser** (served by the PC) it opens the **configurator**: profiles, drag-and-drop grid,
  property panel.
- **On the phone** it is the **runtime**: the button grid (sized to the screen), the Audio tab, and
  settings for pairing and integrations.

Key places:

- `lib/core/droiddeck_client/` — API models (`DeckButton`, profiles…).
- `lib/src/stream_deck/` — grid, buttons and the property panel editor.
- `lib/src/services/signalr_service.dart` — hub connection with endless reconnection.
- `lib/src/config/` — settings pages (pairing, Discord, OBS, Tuya, soundboard).

## Contract

The app and the backend share:

- **REST** under `/api/...` — see [API](../reference/api.md);
- **SignalR** at `/deckHub` — server-to-client events;
- **UDP discovery** on port 7573;
- **Pairing URI** `droiddeck://pair?ip=&port=&key=`.

## Adding a new action type

Each action type is an **`IActionProvider`** (`RaspDeck/Actions/`). It executes the action and
describes its fields in an `ActionSchema`; the app's editor builds the form from
`GET /api/actions/schema`, so a simple type needs no Flutter code at all:

1. Implement `IActionProvider` in `RaspDeck/Actions/Providers/` (`Type`, `Describe()`, `ExecuteAsync()`).
   Fields are text, multiline, number, toggle or select; a select can load its options from an endpoint
   (`OptionsSource`, with `{field}` placeholders) and any field can depend on another (`When`).
2. Register it in `Program.cs` (`services.AddSingleton<IActionProvider, MyProvider>()`).
3. If it has live state, implement `IStatefulActionProvider` (`StateEvent`, `GetState()`): `DeckHub`
   sends it on connect and the app listens to it.
4. Only if needed: a custom renderer in `deck_grid_button.dart` (live state on the button), a custom
   editor in `app/lib/src/stream_deck/actions/editors/` (`Editor = "name"`), or a settings page.
5. If it runs code or reaches the network from the PC, add it to `ActionPolicy`'s privileged types.
