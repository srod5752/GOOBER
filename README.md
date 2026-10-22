# GOOBER OS

GOOBER (General Operations & Onboard Base Environment Response) is a CC:Tweaked facility interface. The repository is being built in phases. The current release installs a boot screen and establishes Rednet controller discovery, registration, heartbeats, and device status.

## Current status

- Step 1: installer, startup entry point, persistent device configuration, and capability detection.
- Step 2: Rednet discovery, controller registration, heartbeat/offline detection, and shared device status.
- Step 3: boot sequence, responsive dashboard, application launcher, network diagnostics, and device settings.
- Step 4: music search, saved result playlists, shared queue controls, and controller-fetched DFPWM streaming to audio nodes.
- Step 5 and later: announcements, lockdown, history, and updater.

Read [docs/step-1.md](docs/step-1.md) for publishing and installation. Read [docs/step-2.md](docs/step-2.md) for network setup, [docs/step-3.md](docs/step-3.md) for interface checks, and [docs/step-4.md](docs/step-4.md) for music setup and limits. The installer asks for the raw-content repository root; no owner or repository is hardcoded.
