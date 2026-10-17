# Buttons & actions

Each button runs one **action**. Pick the action type in the properties panel; the fields below it
change according to the type.

!!! info "Hotkey, Launch app and HTTP request are created on the PC"
    For security, buttons that send keys, open programs or make HTTP requests (including multi-actions
    with those steps) can only be created or changed in the [configurator](../getting-started/configurator.md)
    on the PC. The phone runs them normally.

| Action type | Runs on | Summary |
|---|---|---|
| [Hotkey](#hotkey) | PC | Sends a key combination to the focused window. |
| [Launch app](#launch-app) | PC | Opens a program, file, folder or URL. |
| [Media](#media) | PC | Play/pause, next, previous, stop. |
| [Mixer](#mixer) | PC | Mute apps; mute or change the volume of audio devices. |
| [Open profile](#open-profile-and-back) | Phone | Opens another profile as a folder. |
| [Back](#open-profile-and-back) | Phone | Returns from a folder. |
| [Multi-action](#multi-action) | PC | Runs several steps in sequence, with delays. |
| [Discord](../integrations/discord.md) | PC | Voice controls and soundboard. |
| [OBS](../integrations/obs.md) | PC | Scenes, recording, streaming and more. |
| [Soundboard](../integrations/soundboard.md) | PC | Plays a sound. |
| [Tuya](../integrations/tuya.md) | PC | Controls smart-home devices. |
| [Home Assistant](../integrations/homeassistant.md) | PC | Lights, plugs, scenes, scripts and sensors. |
| [Spotify](../integrations/spotify.md) | PC | Player, like, shuffle, playlists and the cover on the button. |
| [Twitch](../integrations/twitch.md) | PC | Marker, clip, ad, chat, poll and title. |
| [YouTube](../integrations/youtube.md) | PC | Live chat and viewers. |
| [Timer, pomodoro & counter](#timer) | PC | A live clock on the button. |
| [Windows](#windows) | PC | Switches the default audio device, locks, sleeps or turns the screen off. |
| [HTTP request](#http) | PC | Calls a webhook or any API. |
| [Steam game](#steam) | PC | Opens an installed game, with its cover on the button. |

Each button can also have a [long-press and a double-tap](#gestures) action, be a
[two-state button](#two-states) and [show information](monitors.md) (clock, weather, what's
playing...).

## Hotkey

Sends keys to **the window that has focus** on the PC.

**Keys** uses the Windows *SendKeys* syntax, plus `#` for the Windows key:

| Symbol | Key | Example |
|---|---|---|
| `^` | Ctrl | `^c` → Ctrl+C |
| `+` | Shift | `^+s` → Ctrl+Shift+S |
| `%` | Alt | `%{F4}` → Alt+F4 |
| `#` | Windows | `#d` → show desktop, `#+s` → screenshot tool |
| `( )` | Hold modifiers for a group | `+(abc)` → ABC |
| `~` | Enter | `^a~` |
| `{NAME}` | Special key | `{ENTER}`, `{TAB}`, `{ESC}`, `{SPACE}`, `{F1}`…`{F24}`, `{UP}`, `{DOWN}`, `{LEFT}`, `{RIGHT}`, `{HOME}`, `{END}`, `{PGUP}`, `{PGDN}`, `{INS}`, `{DEL}`, `{BS}`, `{PRTSC}`, `{NUMPAD0}`…`{NUMPAD9}`, `{VOLUME_UP}`, `{VOLUME_DOWN}`, `{VOLUME_MUTE}`, `{MEDIA_PLAY_PAUSE}`, `{MEDIA_NEXT}`, `{MEDIA_PREV}` |
| `{NAME n}` | Repeat | `{TAB 3}` |
| `{x}` | The character itself | `{+}`, `{^}`, `{%}`, `{#}`, `{~}`, `{(}`, `{{}` |

Any other character is typed as is. With Ctrl, Alt or Windows, letters ignore case: `^C` is Ctrl+C;
use `+` for Shift.

Keys are sent with their hardware scan codes and held for a moment, so most games that read the
keyboard directly also receive them.

!!! warning "Limitations"
    - Windows blocks input to apps running **as administrator** unless DroidDeck also runs as administrator.
    - Games with anti-cheat may ignore simulated keys.
    - Some combinations are reserved by Windows and can't be simulated, such as Ctrl+Alt+Del and Win+L.

## Launch app

**Path** accepts anything you could open from *Run* (++win+r++): an `.exe`
(`C:\Windows\System32\notepad.exe`), a document, a folder or a URL (`https://…`, `steam://…`).

## Media

Controls the media session Windows is showing in its media overlay — Spotify, browsers, players.

**Command:** `Play/Pause` (default), `Next`, `Previous`, `Stop`. A play/pause button switches its
icon live between ▶ and ⏸.

## Mixer

| Operation | App target | Device target |
|---|---|---|
| Toggle mute / Mute / Unmute | ✓ | ✓ |
| Set volume (0–100) | — | ✓ |
| Volume up / down (step) | — | ✓ |

- **App target**: the process name **without** `.exe`, e.g. `Spotify` or `chrome`. It affects every
  audio stream of that app. Per-app volume is available on the phone's **Audio** tab.
- **Device target**: **Default** follows Windows' current default device (choose **output** or
  **input**, i.e. speakers or microphone), or pick a specific device. Turning the volume up also
  unmutes the device.

Set an **active colour** to light the button up while the target is muted.

## Open profile and back

**Open profile** shows another profile on top of the current one, like a folder. Folders can be
nested. **Back** closes the current folder; the title-bar arrow does the same. Both actions run on
the phone only.

## Multi-action

Runs several steps one after the other. Each step has a **delay** (ms) that is waited **before** it
runs. The editor offers three step kinds:

- **Hotkey** — keys, as above;
- **Open app** — path, as above;
- **Mute app** — toggles mute of a process.

Example — "Start meeting": open the meeting app, wait 3000 ms, send `^+m`.

### Record from the keyboard { #record }

In the PC configurator, **Record from keyboard** records what you type on the PC's keyboard and turns
it into hotkey steps: go to the program, type the sequence and click **Stop**.

- Keys typed in a row become a single step (`hi{ENTER}`); a pause longer than half a second starts a
  new step, with the delay rounded to 100 ms.
- Recording stops on its own after 60 seconds.
- Because it reads the whole keyboard, it only works in the configurator open on the PC itself; the
  phone doesn't have this button. Review the steps before saving: everything typed goes in, passwords
  included.

## Timer, pomodoro & counter { #timer }

The button shows the time live. The clock runs on the PC, so every phone sees the same time and the
end of a countdown is caught even with the phone's screen off.

| Type | Tap | At the end |
|---|---|---|
| **Timer (countdown)** | Start / pause. After it ends, a tap resets it. | Sound on the PC, vibration on the phone, and the button lights up in its active colour. |
| **Stopwatch** | Start / pause. | — |
| **Pomodoro (focus and break)** | Start / pause. Focus and break alternate on their own and the button counts cycles. | Alert at every phase change. |
| **Counter** | Adds the **step**. | — |

**On tap** changes what a tap does: **Reset**, **Skip to the next phase (pomodoro)**,
**Add (counter)** / **Subtract (counter)**. With **Controlled timer**
a button acts on another button's timer, for example a "reset" button next to the clock. Counters
survive a PC restart.

## Windows { #windows }

| Action | What it does |
|---|---|
| **Change the default audio device** | Sets Windows' default output (or input). With **Toggle with (optional)** set, each tap switches between the two, e.g. headphones ↔ speakers. The button lights up while the chosen device is the default. |
| **Lock the computer** | Same as ++win+l++. |
| **Sleep** | Puts the PC to sleep. |
| **Turn off the display** | Turns the monitors off; moving the mouse turns them back on. |

## HTTP request { #http }

Calls a URL from the PC: n8n, Home Assistant or IFTTT webhooks, or any API. Pick the **method**, the
**URL**, the **headers** (one per line, `Name: value`) and, for POST/PUT/PATCH, the **body** and its
format (JSON, form or text). The request has 10 seconds to answer; the result goes to DroidDeck's log.

## Steam game { #steam }

Lists the games installed in the PC's Steam (every library). Picking one gives the button the game's
name and cover; tapping it launches the game through Steam. The cover comes from Steam's cache: if a
game shows no image, open your Steam library once so it downloads the covers.

## Long press and double tap { #gestures }

Besides the normal tap, a button can have one action for **holding** and another for **double
tapping** (the editor's *Toque longo e toque duplo* section). They take the same action types as the
tap.

- Example: a timer that starts on tap and resets on long press; an OBS scene on tap and recording on
  double tap.
- Only buttons with a double-tap action wait a moment (~0.3 s) before running the single tap, to tell
  them apart. Every other button reacts right away.
- On a button with a long-press action, holding runs it; to edit that button on the phone, use
  [edit mode](profiles.md#edit-mode).

## Two states { #two-states }

In the editor's **Two states** section:

- **Toggle on each tap** turns the button on with one tap and off with the next, for actions with no
  state of their own (a hotkey that toggles something in a game, for example). The state lives on the
  PC: every phone shows the same one and it survives a restart.
- **Action when on** (optional) runs on the tap that turns the button off. Example: one tap starts
  recording with a hotkey and the next sends the stop hotkey. Without it, the same action runs every
  time.
- **Label when active** and **Icon when active** change the look while the button is active — through
  the toggle or through the action's own state (Discord mute, OBS recording, a light on...). The
  **active colour** sits with the button's colours.

## Button state

Some buttons reflect live state:

| Action | State shown |
|---|---|
| Media play/pause | ▶ / ⏸ icon |
| Mixer (app mute) | Volume icon and active colour while muted |
| Discord | Active colour while you are muted/deafened |
| OBS | Lit for the current scene, or while recording/streaming/virtual cam/replay buffer is on |
| Tuya | On/off, brightness level and the lamp's real colour |
| Timer | Time left or elapsed, pomodoro phase and active colour at the end |
| Windows (audio) | Active colour while the device is the default |
| Home Assistant | Lit while the entity is on (with the light's brightness and colour), or the sensor value |
| Spotify | Play/pause, liked, shuffle and repeat; the cover on "show what's playing" |
| Twitch / YouTube | Live and viewers, on "status only" |
| Two states | Active colour, label and icon while on |
