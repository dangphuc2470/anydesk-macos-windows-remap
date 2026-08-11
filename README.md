# anydesk-macos-windows-remap

> **A lightweight, ultra-secure macOS background daemon that seamlessly translates Windows keyboard shortcuts when remotely controlling macOS via AnyDesk.**

[![macOS](https://img.shields.io/badge/Platform-macOS%2011%2B-blue?logo=apple)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/Language-Swift-orange?logo=swift)](https://developer.apple.com/swift/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Security](https://img.shields.io/badge/Security-100%25%20Local%20%7C%20No%20Logging-brightgreen)](README.md#security--privacy)

---

## The Problem

When using a **Windows PC** to remotely control a **macOS** machine through **AnyDesk**:
1. **Shortcuts Do Not Match:** Pressing `Ctrl + C`, `Ctrl + V`, `Ctrl + Z`, `Ctrl + S`, `Ctrl + A` sends `Control` instead of macOS `Command` (`⌘`), forcing you to use the `Windows` key (`Win + C`) to copy.
2. **Karabiner-Elements is Bypassed:** Karabiner works at the hardware HID Driver level. AnyDesk injects synthetic keystrokes directly into macOS WindowServer via `CGEventPost`, completely bypassing Karabiner rules.
3. **AutoHotkey Fails on Windows:** AnyDesk on Windows runs as an elevated service/admin process, ignoring standard user-space AutoHotkey hooks due to Windows UIPI security.

---

## The Solution

**`anydesk-macos-windows-remap`** runs as a native, lightweight Swift daemon using macOS CoreGraphics **`CGEventTap`**:
* **Smart PID Detection:** Intercepts keystrokes originating **strictly from AnyDesk processes**. Physical Mac keyboards remain untouched.
* **Zero Latency:** Modifier swaps (`Ctrl` <-> `Cmd`) and shortcut conversions happen in-memory inside the macOS WindowServer event stream.
* **100% Secure:** No network access, no disk logging, and no external dependencies.

---

## Features & Shortcut Mappings

When controlling macOS from Windows via AnyDesk:

| Windows Shortcut (Pressed on Windows) | macOS Action Produced | Function |
|---|---|---|
| `Ctrl + C` | `Cmd + C` | Copy |
| `Ctrl + V` | `Cmd + V` | Paste |
| `Ctrl + Z` | `Cmd + Z` | Undo |
| `Ctrl + A` | `Cmd + A` | Select All |
| `Ctrl + S` | `Cmd + S` | Save |
| `Ctrl + F` | `Cmd + F` | Find |
| `Ctrl + Backspace` | `Option + Backspace` | Delete word backward |
| `Ctrl + Delete` | `Option + Delete` | Delete word forward |
| `Alt + Backspace` | `Cmd + Backspace` | Delete line to start |
| `Win + Shift + S` | `Cmd + Shift + 4` | Interactive Screenshot to Clipboard |
| `Win + Shift + L` / `Ctrl + Alt + L` / `Win + L` | `Ctrl + Cmd + Q` | Lock macOS Screen (Bypasses Windows Host Lock) |
| `Win + D` | `F11` | Show Desktop |
| `Win + Tab` | `Ctrl + Up Arrow` | Mission Control |
| `Ctrl + Left/Right` | `Option + Left/Right` | Jump cursor word by word |
| `Ctrl + Shift + Left/Right` | `Option + Shift + Left/Right` | Select word by word |
| `Alt + Shift + Left/Right` | `Cmd + Shift + Left/Right` | Select line by line |
| `Ctrl + J` | `Option + Cmd + L` | Open Browser Downloads |
| `Ctrl + H` | `Option + Cmd + F` / `Cmd + Y` | Editor Replace / Browser History |

---

## Quick Start & Installation

### 1. Clone & Install
```bash
git clone https://github.com/dangphuc2470/anydesk-macos-windows-remap.git
cd anydesk-macos-windows-remap
chmod +x install.sh uninstall.sh restart.sh
./install.sh
```

### 2. Grant Accessibility Permissions
Because macOS protects input event streams, grant Accessibility permission once:
1. Open **System Settings** -> **Privacy & Security** -> **Accessibility**.
2. Click **`+`** (or toggle on) and add:
   ```text
   ~/.config/anydesk-remap/anydesk_remap
   ```
3. Toggle the switch to **ON**.

The daemon will run automatically in the background on every login.

---

## Service Management

### Restart the Daemon
To restart or reload the daemon after modifying code or updating permissions:
```bash
./restart.sh
```
Or via `launchctl`:
```bash
launchctl unload ~/Library/LaunchAgents/com.dangphuc2470.anydesk-remap.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.dangphuc2470.anydesk-remap.plist
```
*(Because `KeepAlive` is enabled, running `killall anydesk_remap` will also immediately restart the daemon with the new binary).*

### Check Status & View Logs
* Check if the process is running:
  ```bash
  ps aux | grep anydesk_remap
  ```
* View live output logs:
  ```bash
  tail -f ~/.config/anydesk-remap/logs/daemon.log
  ```
* View error logs:
  ```bash
  tail -f ~/.config/anydesk-remap/logs/daemon.error.log
  ```

---

## Security & Privacy

* **Zero Network Activity:** Does not import network libraries or make socket connections.
* **No Disk Persistence of Keystrokes:** Keystroke modifiers are altered purely in volatile memory.
* **Isolated Scope:** Keystrokes from non-AnyDesk apps or physical local keyboards are immediately passed through unaltered.
* **Open Source & Auditable:** All logic is contained in a single readable Swift file ([`main.swift`](main.swift)).

---

## Uninstallation

To completely remove the daemon and LaunchAgent:
```bash
./uninstall.sh
```

---

## Author

* [@dangphuc2470](https://github.com/dangphuc2470)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
