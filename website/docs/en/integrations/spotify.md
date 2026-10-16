# Spotify

Controls your Spotify account through the Web API, with an app you create in Spotify's developer
dashboard (free). **Controlling playback requires Spotify Premium.**

## Setup

1. Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) and create an app
   (**Create app**). Any name and description.
2. Under **Redirect URIs**, add exactly the address shown on DroidDeck's screen:
   `http://127.0.0.1:4787/api/integrations/spotify/callback`.
3. Tick **Web API**, save and copy the **Client ID**.
4. In DroidDeck, **Settings → Integrations → Spotify**: paste the Client ID and tap **Sign in with
   Spotify**. Sign-in opens in the PC's browser (even if you tapped on the phone); authorise and you're
   done.

There's no secret to keep: DroidDeck uses the PKCE flow. The token is stored encrypted on the PC.

## What you can do

| Operation | Button |
|---|---|
| Play/pause | ▶ / ⏸ |
| Next / Previous | — |
| Like/unlike the track | ♥ lit when the track is liked |
| Shuffle | Lit when on |
| Repeat (off → playlist → track) | Lit when on; "repeat one" icon on track |
| Volume (+/-) | Shows the current volume |
| Play a playlist | Your playlists in a list; option to start shuffled |
| Show what's playing | Cover, track and artist (tapping plays/pauses) |

- The state is checked every 3 seconds while a phone is connected and the deck has a Spotify button.
- Commands go to the active Spotify device (PC, phone, speaker...). With nothing playing, Spotify
  answers that there's no active device: press play in it once.
