# YouTube

Sends messages to your live stream's chat and shows whether the channel is live and how many people
are watching, through the YouTube Data API, with an OAuth client you create in Google Cloud.

## Setup

1. In [console.cloud.google.com](https://console.cloud.google.com), create a project and enable the
   **YouTube Data API v3**.
2. Under **OAuth consent screen**, choose **External** and add your e-mail as a **test user** (the app
   stays in testing; no need to publish).
3. Under **Credentials → Create credentials → OAuth client ID**, choose **Desktop app**.
4. Copy the **Client ID** and **Client Secret** to **Settings → Integrations → YouTube** and tap
   **Sign in with Google**. Sign-in opens in the PC's browser.

In a desktop app the Client Secret isn't truly secret (Google knows this); DroidDeck still stores it
encrypted on the PC.

## What you can do

| Operation | Details |
|---|---|
| Send chat message | Goes to the chat of the active live broadcast. |
| Live/viewers only | Lit while live, with the viewer count. |

The broadcast is checked once a minute, because the API's daily quota is small.
