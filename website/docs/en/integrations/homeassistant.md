# Home Assistant

DroidDeck connects to [Home Assistant](https://www.home-assistant.io) through its WebSocket API with an
access token: buttons show the real state and update right away, even when something changes in Home
Assistant itself.

## Setup

1. In Home Assistant, open your **profile** (bottom left) → **Security** tab.
2. Under **Long-lived access tokens**, create a token (for example `DroidDeck`) and copy it — it is
   shown only once.
3. In DroidDeck, open **Settings → Integrations → Home Assistant** (in the configurator,
   **Integrations** in the sidebar), fill in the **Address** (`http://homeassistant.local:8123` or the
   IP) and the token, and tap **Connect**.

The token is stored encrypted on the PC. The PC must be able to reach Home Assistant on the network.

## What you can do

| Operation | Entities | Button |
|---|---|---|
| Toggle | light, switch, fan, cover, lock, media player, automation... | Lit while on; lights show their brightness |
| Turn on / Turn off | the same | same |
| Brightness (+/-) | lights | Step from -100 to 100 % |
| Activate scene | `scene.*` | — |
| Run script | `script.*` | — |
| Show state only | sensors, climate, people, `input_number`... | The value with its unit (`23.5 °C`) |
| Call a service | any | `domain.service` and JSON data |

- The entity list comes from Home Assistant, filtered by operation; you can also type an id that isn't
  listed.
- RGB lights paint the button with their real colour.
- If the connection drops, the PC reconnects on its own (backing off to once a minute).
