# Change notes

## 1.2.1 — Multiplayer equip/open fixes

- Fixed the custom equip action's global class registration so Build 42 multiplayer servers can reconstruct it.
- Preserved vanilla's `maxTimeInit` constructor argument so the server receives the original equip duration, not the already-adjusted client duration.
- Kept belt-draw visuals client-side and preserved the right-hand weapon model through both detach and completion when using the PalmPilot in the left hand.
- Matched the opening action's aiming behavior to vanilla equipping. Running can still interrupt opening.
- Replaced the misleading main-inventory error with an interruption message, prevented duplicate dialogs, and added item/hand details to cancellation logs.
- Retained the existing client UI optimizations, loot settings, device data format, and server-side equip authority.

Verification: 19 automated regression checks pass using installed vanilla Lua actions and mocked player/network APIs. This is not a live multiplayer certification; retest with a non-admin client and instant actions disabled before publishing.

Updating requires the server and all clients to load the new files. `modversion` is a release label; changing it alone does not fix or prove file synchronization.
