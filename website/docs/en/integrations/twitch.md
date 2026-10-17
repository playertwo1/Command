# Twitch

Actions for your Twitch channel (Helix API), with an app you register in the Twitch console. Sign-in is
by code: DroidDeck shows a code and you confirm it at `twitch.tv/activate`.

## Setup

1. Go to [dev.twitch.tv/console/apps](https://dev.twitch.tv/console/apps) and register an application.
2. Under **OAuth Redirect URLs**, use `http://localhost` (not used by code sign-in).
3. Under **Client Type**, choose **Public**. Save and copy the **Client ID**.
4. In DroidDeck, **Settings → Integrations → Twitch**: paste the Client ID and tap **Sign in with
   Twitch**. The activation page opens in the PC's browser; check the code and authorise.

## What you can do

| Operation | Details |
|---|---|
| Create marker | Optional description. Only works while live. |
| Create clip | From the live stream's current moment. |
| Run ad | 30 s to 3 min (affiliate or partner account). |
| Send chat message | As your user. |
| Start poll | Question, 2 to 5 choices (one per line) and duration (affiliate or partner). |
| Change title | The stream's new title. |
| Live/viewers only | Lit while live, with the viewer count. |

Live state and viewers update every 30 seconds.
