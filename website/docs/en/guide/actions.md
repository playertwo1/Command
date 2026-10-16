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
| [Timer, pomodoro & counter](#timer) | PC | A live clock on the button. |
| [Windows](#windows) | PC | Switches the default audio device, locks, sleeps or turns the screen off. |
| [HTTP request](#http) | PC | Calls a webhook or any API. |

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
  audio stream of that app. Per-app volume is available on the phone's **Áudio** tab.
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

## Timer, pomodoro & counter { #timer }

The button shows the time live. The clock runs on the PC, so every phone sees the same time and the
end of a countdown is caught even with the phone's screen off.

| Type | Tap | At the end |
|---|---|---|
| **Timer** (countdown) | Start / pause. After it ends, a tap resets it. | Sound on the PC, vibration on the phone, and the button lights up in its active colour. |
| **Cronômetro** (stopwatch) | Start / pause. | — |
| **Pomodoro** | Start / pause. Focus and break alternate on their own and the button counts cycles. | Alert at every phase change. |
| **Contador** (counter) | Adds the **step**. | — |

**Ao tocar** (on tap) changes what a tap does: **Zerar** (reset), **Pular para a próxima fase**
(skip phase, pomodoro), **Somar** / **Subtrair** (add / subtract, counter). With **Timer controlado**
a button acts on another button's timer, for example a "reset" button next to the clock. Counters
survive a PC restart.

## Windows { #windows }

| Action | What it does |
|---|---|
| **Trocar o dispositivo de áudio padrão** (switch default audio device) | Sets Windows' default output (or input). With **Alternar com** (toggle with) set, each tap switches between the two, e.g. headphones ↔ speakers. The button lights up while the chosen device is the default. |
| **Travar o computador** (lock) | Same as ++win+l++. |
| **Suspender** (sleep) | Puts the PC to sleep. |
| **Desligar a tela** (screen off) | Turns the monitors off; moving the mouse turns them back on. |

## HTTP request { #http }

Calls a URL from the PC: n8n, Home Assistant or IFTTT webhooks, or any API. Pick the **method**, the
**URL**, the **headers** (one per line, `Name: value`) and, for POST/PUT/PATCH, the **body** and its
format (JSON, form or text). The request has 10 seconds to answer; the result goes to DroidDeck's log.

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
