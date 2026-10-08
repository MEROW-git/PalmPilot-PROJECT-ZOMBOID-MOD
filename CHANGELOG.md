# Change notes

## Unreleased

- Multiplayer Chess rotates the board for the Black player, keeping Black's pieces at the bottom while clicks and move highlights still use the correct squares.
- Live Chess now shows Disconnected when players separate or a PalmPilot becomes unavailable, with a direct option to start a new multiplayer match. Continue is labeled for the saved solo game only.
- Chess now opens a Continue solo game / New solo game / New multiplayer game menu. Nearby players can accept a live two-player match within Beam's three-tile, same-floor range; the server validates turns and legal moves. Solo saves remain separate from live matches.
- Chess captures now leave the target piece visible until the computer's move animation lands. En passant highlights the pawn's captured square and briefly names the move.
- Chess now displays captured White pieces to the left of the board and captured Black pieces to the right. Captures are saved with each PalmPilot's game; older saves reconstruct available captures from the position.
- Added an original Chess app against a computer opponent, with per-device saved positions and standard move rules. The ChessGenius Palm OS binary is not bundled.
- Chess now uses twelve sprites cut from the supplied piece art, highlights the selected piece and legal moves, and shows a delayed, animated computer move.
- Active Chess play reduces Boredom and Unhappiness using Snake's rates; multiplayer applies the effect on the server through a bounded heartbeat.
- Active Snake play now slowly reduces Boredom and Unhappiness on Build 42.20+.
- Relief uses elapsed game time, is capped after long update gaps, and stops when play pauses or ends.
- Multiplayer Snake relief is now applied by the server and synced back to the player after checking the held, powered device.
- Added a PalmPilot Spawn Rate sandbox setting for container loot and office-worker carriers. Its default preserves existing behavior; custom rates compensate for high Other Loot.
- Existing device fields migrate safely; Chess adds a saved position, and multiplayer uses bounded game mood heartbeats.

## 1.2.1 — Multiplayer equip/open fixes

- Fixed the custom equip action's global class registration so Build 42 multiplayer servers can reconstruct it.
- Preserved vanilla's `maxTimeInit` constructor argument so the server receives the original equip duration, not the already-adjusted client duration.
- Kept belt-draw visuals client-side and preserved the right-hand weapon model through both detach and completion when using the PalmPilot in the left hand.
- Matched the opening action's aiming behavior to vanilla equipping. Running can still interrupt opening.
- Replaced the misleading main-inventory error with an interruption message, prevented duplicate dialogs, and added item/hand details to cancellation logs.
- Retained the existing client UI optimizations, loot settings, device data format, and server-side equip authority.

Verification: 19 automated regression checks pass using installed vanilla Lua actions and mocked player/network APIs. This is not a live multiplayer certification; retest with a non-admin client and instant actions disabled before publishing.

Updating requires the server and all clients to load the new files. `modversion` is a release label; changing it alone does not fix or prove file synchronization.
