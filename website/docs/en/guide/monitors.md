# Monitors & info

A button can show live information. In the editor, open **Show on button** and pick an
**Information**. Tapping still runs the button's action, if it has one (a CPU button can open Task
Manager, for example).

## PC monitors

| Information | Shows |
|---|---|
| **CPU usage** | Total processor usage, as a gauge. |
| **Memory usage** | RAM usage, with "used/total GB". |
| **GPU usage** | 3D engine usage of the GPU, as a gauge. |
| **Network** | Download ↓ and upload ↑ speed across all active network adapters (K = KB/s, M = MB/s). |

Gauges change colour with load: **green** up to 60 %, **orange** above 60 %, **red** above 85 %.

- Values update **every second** while a phone is connected. The PC stops collecting them when no
  phone is connected.
- GPU usage comes from Windows performance counters and needs a reasonably recent graphics driver.
  It shows 0 % when unavailable.

## Information

| Information | Shows | Options |
|---|---|---|
| **Clock** | The phone's time and date. | 24-hour, seconds, date. |
| **Weather** | Temperature and a weather icon, from [Open-Meteo](https://open-meteo.com) (no account). Updates every 15 min. | City; Fahrenheit. |
| **Now playing** | Cover, track and artist of what's playing in Windows (Spotify, browser, players). | — |
| **Command output (PC)** | What a `cmd` command prints. | Command, template, interval. |
| **URL value (PC)** | An address's response, or one field of its JSON. | URL, JSON field, template, interval. |

- **Template**: `{value}` is replaced by the value. E.g. `Day {value}`, `{value} ★`.
- **Interval**: how often, in seconds, the PC fetches it again (minimum 5, default 60).
- **JSON field**: a path with dots and indexes, like `current.temp` or `items[0].name`. Empty = the
  whole response.
- The command has up to 10 seconds to finish. Examples: `powershell -c "(Get-Date).DayOfYear"`,
  `echo %TIME:~0,5%`.
- When something fails, the button shows a yellow warning with the reason (city not found, missing
  field, HTTP 404...).

!!! info "Command and URL are created on the PC"
    Like hotkeys, buttons that run a command or read a URL on the PC can only be created or changed in
    the [configurator](../getting-started/configurator.md).
