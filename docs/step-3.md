# GOOBER OS — Step 3 Interface

Step 3 adds the startup sequence, responsive facility dashboard, application launcher, network diagnostics, and local device settings. The interface uses solid color panels, visual status bars, and filled controls rather than text-drawn borders. The dashboard uses live controller or terminal state; a disconnected terminal labels its last device snapshot as cached. Music, announcements, and lockdown are shown as unavailable until their implementation phases.

## Publish and update

Upload these changed files to the repository root/main branch, preserving folders:

- `manifest.json`
- `install.lua`
- `app/main.lua`
- `app/net/service.lua`
- `app/ui/display.lua`
- `app/ui/components.lua`
- `app/ui/app.lua`
- `README.md`
- `docs/step-3.md`

Keep all existing Step 1 and Step 2 files. Verify the GitHub `manifest.json` version is `0.3.0-interface`. On every computer, run the usual `wget run` installer command and use the repository's raw-content root. Answer `y` to repair/update; persistent data is preserved.

## In-game checks

1. Reboot. Confirm the GOOBER boot screen appears briefly, then opens the facility dashboard without requiring a command.
2. Click or touch **HOME**, **APPS**, **NETWORK**, and **SETTINGS**. On a narrow screen, the navigation uses the short labels H/A/N/S. On a monitor, touch a button and confirm the expected page opens.
3. On the dashboard, compare network state, online device count, modem/speaker/monitor counts, and device rows with the actual computers and attached peripherals. A terminal that loses its controller should label its retained device list as cached.
4. Open **APPS**. Overview, Network, and Settings should open. Music, Announcements, and Lockdown should be visibly marked as later phases, not behave like working applications.
5. In **SETTINGS**, cycle the monitor scale, volume default, and loop default; verify the shown values change and survive a reboot. Edit the device name; verify the name updates in GOOBER and the device label, and appears at the controller after registration.
6. Change the role only if needed. The screen should say a reboot is required. After reboot, confirm the selected role takes effect and the device reconnects appropriately.
7. Test responsiveness on a regular computer screen and an attached monitor. Resizing or attaching/detaching a monitor should return to a usable page without a crash.

Settings for music volume and loop are defaults only in this phase; playback itself arrives in Step 4. The application cards do not claim that later-phase features are active.
