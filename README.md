# GOOBER OS

GOOBER (General Operations & Onboard Base Environment Response) is a CC:Tweaked facility interface. The repository is being built in phases. The current release installs a boot screen and establishes Rednet controller discovery, registration, heartbeats, and device status.

## Current status

- Step 1: installer, startup entry point, persistent device configuration, and capability detection.
- Step 2: Rednet discovery, controller registration, heartbeat/offline detection, and shared device status.
- Step 3 and later: user applications, shared music, announcements, lockdown, history, and updater.

Read [docs/step-1.md](docs/step-1.md) for publishing and installation. Read [docs/step-2.md](docs/step-2.md) for network setup and in-game checks. The installer asks for the raw-content repository root; no owner or repository is hardcoded.
