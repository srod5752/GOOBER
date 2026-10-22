# GOOBER OS — Step 2 Networking

Step 2 adds the Rednet control plane. A controller advertises itself, terminal and audio computers find it, clients register and send heartbeats, and the controller shares an online/offline device list. This release does not yet send facility commands or play music.

## Publish this version

Upload the changed files from this project to the root of the `main` branch in the GOOBER GitHub repository, keeping the directory paths:

- `manifest.json`
- `install.lua`
- `app/main.lua`
- `app/net/protocol.lua`
- `app/net/transport.lua`
- `app/net/service.lua`
- `README.md`
- `docs/step-1.md`
- `docs/step-2.md`

Keep the existing Step 1 files in the repository too. The manifest lists every program file the installer downloads. Confirm the GitHub page for `manifest.json` shows version `0.2.0-network` before installing this step.

## Install/update in game

On each CC:Tweaked computer, use the CraftOS command prompt:

```text
wget run https://raw.githubusercontent.com/srod5752/GOOBER/main/install.lua
```

If the installer detects GOOBER already installed, answer `y` to continue. It updates program files and preserves `/goober/data/config.json`.

For a new installation, choose role `1` on one computer (controller) and role `2` on the other (terminal). If the computer already has a config file, its old role is intentionally preserved. To change it, open the file from the CraftOS prompt with:

```text
edit /goober/data/config.json
```

Set `"role"` to `"controller"` on the controller computer and `"terminal"` on a terminal computer, then save. The first controller discovered by a terminal is remembered in its config. Use one controller on the same Rednet network while testing.

Each computer needs a modem attached. The computers must be in modem range, and server settings must permit CC:T networking.

## In-game checks

1. Reboot both computers after installation. The controller should show `Status: controller`; the terminal should move from searching/connecting to `Status: connected`.
2. On the controller, confirm its own row and the terminal row appear under connected/recent devices. The terminal should show a controller ID and a shared device count.
3. Detach or disable the terminal's modem. After the stale timeout (30 seconds), the controller should mark the terminal offline. The terminal should report an offline/timeout state.
4. Reattach the modem. The terminal should reconnect and register again; the controller should show it online.
5. Reboot the terminal and confirm it reuses its saved controller ID and reconnects.

The network status page is the Step 2 deliverable. Music, announcements, lockdown, activity history, and in-app settings come in later steps.
