# GOOBER OS — Step 1 Foundation

This repository currently contains the startup/install foundation. It is not yet the distributed operating system: controller networking and applications are planned for Step 2 onward.

## Repository publishing

The installer asks for a raw-content root in this form:

```text
https://raw.githubusercontent.com/OWNER/REPOSITORY/BRANCH
```

Publish `install.lua`, `manifest.json`, `startup.lua`, and the listed `app/` files at that branch root. The installer downloads the manifest and then only the paths listed by it. It stages and syntax-checks Lua files before replacing the active application. The repository URL is not embedded in this project.

Once a repository exists, the in-game bootstrap command is:

```text
wget run https://raw.githubusercontent.com/OWNER/REPOSITORY/BRANCH/install.lua
```

Replace all three placeholders with the actual repository owner, name, and branch. The installer then asks for the matching raw-content root.

## Data and recovery

- Application files: `/goober/app`
- Persistent device configuration: `/goober/data/config.json`
- Repository source settings: `/goober/data/repository.json`
- Staged downloads: `/goober/staging`
- Pre-install copies: `/goober/backups`
- Automatic startup: `/startup.lua`

The installer does not replace an existing installation until all manifest files have downloaded successfully. It asks before proceeding when it finds existing program or startup files, backs those files up, and preserves `/goober/data`. The backup is a local recovery copy, not a complete transactional updater; the dedicated staged updater and rollback flow are Step 7.

The manifest and downloaded files come from the same configured HTTPS repository. This detects empty downloads and Lua syntax errors, but it is not an independently signed release or cryptographic authenticity check.

## Step 1 scope

This version saves a device name and primary role (`controller`, `terminal`, or `audio`), detects local display/peripheral/API capabilities, and starts automatically. Shared controller discovery, heartbeats, remote status, and user applications are not implemented yet. A terminal should therefore not be treated as connected to the facility until Step 2 is complete.
