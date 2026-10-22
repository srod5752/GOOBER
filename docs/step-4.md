# Step 4: Music

This phase uses the supplied music API (`https://ipod-2to6magyna-uc.a.run.app/`, API version 2.1) for search and DFPWM stream retrieval. Search returns JSON track/result objects; stream requests use the result `id` and return binary DFPWM audio. HTTP must be enabled in CC:Tweaked. API availability and source compatibility are not guaranteed.

The controller owns the shared queue and playback state. It fetches the current stream once, then broadcasts encoded DFPWM chunks over Rednet to connected audio nodes. Audio nodes decode the chunks and play them through attached speakers. Terminals send queue/control requests through the controller. A node joining mid-track waits for the next track; there is no seek or late-join offset. Rednet packet loss, congestion, and speaker buffer timing can cause gaps or desynchronization; this is best-effort streaming, not synchronized audio playback.

Search results can be saved as playlists under `/goober/data/playlists.json`; these persist across reboots. Active playback does not resume after reboot. Supported controls are play, pause, skip, stop, volume, and loop modes (off, queue, song). Search and track support depend on the external service.

## Install

Publish every path in `manifest.json`, including `app/music.lua`, then confirm the manifest version is `0.4.0-music`. Run the existing installer on the controller, terminals, and audio nodes. Keep the same raw-content root and answer `y` when updating an existing installation. Assign the controller role to one computer and audio role to speaker computers; user-facing computers use terminal role.

## In-game checks

1. Search for a track on a terminal and save the returned results as a playlist. Reboot and confirm the playlist is still available.
2. Queue and play a result. Confirm the controller sends the shared state and connected audio nodes play through their speakers.
3. Try pause, resume, skip, stop, volume, and each loop mode. Confirm the music screen reflects the state.
4. Disconnect an audio node during playback. Other nodes should continue; the disconnected node will not receive missed chunks and waits for a later track/state update.
5. Disable HTTP and test a search or start. GOOBER should show a useful error rather than crash.
