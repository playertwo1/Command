# Installation

DroidDeck has two parts: the **Windows app** (server) and the **Android app** (your deck). Both are
attached to every [GitHub release](https://github.com/ggfto/DroidDeck/releases/latest).

## Windows

1. Download **`DroidDeck-Setup.exe`** from the latest release.
2. Run it. It installs for the current user (no administrator needed) and adds desktop and Start
   menu shortcuts.
3. On first run, DroidDeck turns on **Iniciar com o Windows** (start with Windows) and offers to open
   the [firewall](#firewall) for your local network.

The installed DroidDeck **updates itself**: it checks the GitHub releases, downloads new versions in
the background and applies them the next time it starts. To update right away, use **Procurar
atualização** in the tray menu. To uninstall, use Windows *Settings → Apps*.

??? note "Rather not install?"
    The release also has **`DroidDeck-win-x64.zip`**. Extract it to a permanent folder and run
    `DroidDeck.exe`. That copy doesn't update itself: the tray item **Baixar versão mais recente…**
    opens the release page.

The app has no window. It lives in the **system tray**; a notification confirms it is running at
`http://localhost:4787/`. The build is self-contained, so you don't need to install .NET.

!!! warning "Windows SmartScreen"
    The executable is not code-signed yet, so Windows may show *"Windows protected your PC"*.
    Click **More info → Run anyway**.

### Tray menu

Right-click the tray icon:

| Item | What it does |
|---|---|
| **Abrir no navegador** | Opens the configurator at `http://localhost:4787/` (double-clicking the icon does the same). |
| **Parear dispositivo (QR)…** | Shows the pairing QR code for the phone. |
| **Iniciar com o Windows** | Starts DroidDeck when you sign in to Windows. |
| **Liberar no firewall (rede local)** | Adds the [firewall](#firewall) rules. Checked when they already exist. |
| **Procurar atualização** | Checks for a new version; once one is downloaded it becomes **Reiniciar para atualizar** (restart to update). |
| **Sair** | Quits DroidDeck. |

### Firewall

The phone connects to the PC on **TCP 4787**, and automatic server discovery uses **UDP 7573**.
The easiest way is the tray item **Liberar no firewall (rede local)** (the installer offers it on
first run). Windows asks for administrator permission, and the rules only accept devices on your
local subnet, even if the Wi-Fi is marked as a Public network.

To add the same rules by hand, use an elevated PowerShell:

```powershell
New-NetFirewallRule -DisplayName "DroidDeck (TCP 4787)" -Direction Inbound -Protocol TCP -LocalPort 4787 -RemoteAddress LocalSubnet -Action Allow
New-NetFirewallRule -DisplayName "DroidDeck discovery (UDP 7573)" -Direction Inbound -Protocol UDP -LocalPort 7573 -RemoteAddress LocalSubnet -Action Allow
```

## Android

1. On the phone, download **`DroidDeck.apk`** from the latest release.
2. Open it and allow installing from unknown sources when Android asks.
3. Open **DroidDeck** and continue with [Pairing](pairing.md).

Android 7.0 or later is required. The app needs the camera only to scan pairing QR codes.
