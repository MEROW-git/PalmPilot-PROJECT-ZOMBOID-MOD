# Regression checks

## Chess checks

Run from the repository root:

```powershell
npx.cmd --yes --package fengari-node-cli fengari tests/chess.lua
npx.cmd --yes --package fengari-node-cli fengari tests/chess_multiplayer_sync.lua
npx.cmd --yes --package fengari-node-cli fengari tests/chess_live_multiplayer.lua
npx.cmd --yes --package fengari-node-cli fengari tests/chess_live_client.lua
```

This checks opening move counts through three plies, castling, en passant,
forward-blocked and diagonal pawn captures, promotion, checkmate,
saved-position round trips, a legal computer move,
sprite rendering, selection highlights, captured piece placement and persistence,
delayed computer animation (including a visible capture target), active
single-player mood relief, client heartbeats, and the Chess screen's
move/save/reload flow, title-bar status, and control bounds. It covers capture
tracking for both colors, en passant in both directions, new game reset, and
older save migration.
The second command checks that the real client sync command sends Chess data
through the server save handler, that the server preserves the position and
captured pieces, and that its rate limit and device identity check work.
The live-match checks cover target distance, an equipped device in the second
hand, invitations, both colors, turn order, illegal moves, capture sync,
range exit, client offer handling, and keeping the solo save separate.
In game, open Chess, select a piece, make a move, watch the computer think and
move, then close and reopen the same PalmPilot to confirm the position is
preserved. Test with a multiplayer client as well. With nonzero Boredom and
Unhappiness, compare stats before and after active play; the multiplayer
server should apply the change. Check that relief stops after inactivity,
leaving Chess, or closing the device.
For a live two-player check, host a game with two ordinary players. Equip a
powered PalmPilot on each, enable Beam, stand within three tiles on the same
floor, and open Chess > Multiplayer. Confirm both boards update after White
and Black move, then step out of range and check that both matches end. Also
try declining an invitation and switching floors. Restart both clients and
the server after installing the same mod files.

## Spawn setting checks

Run from the repository root with Lua 5.3 or Fengari:

```powershell
npx.cmd --yes --package fengari-node-cli fengari tests/palm_spawn_settings.lua
```

This loads the actual loot and zombie-carrier code with mocked Build 42 APIs.
It checks the original default, each new setting, high and low Other Loot,
the None gate, and reloads without duplicate loot entries. Check the sandbox
menu and newly generated loot in a live game before publishing.

## Snake mood checks

Run from the repository root with Lua 5.3 or Fengari:

```powershell
npx.cmd --yes --package fengari-node-cli fengari tests/snake_mood.lua
npx.cmd --yes --package fengari-node-cli fengari tests/snake_mood_multiplayer.lua
```

This loads the actual Snake screen and checks active play, game-time pause,
pause/resume, stat minimums, collision, and a long-update cap with mocked
Build 42 character stats. It does not replace a live single-player and
multiplayer check before publishing. The multiplayer harness also loads the
real server command handler and checks device ownership, equipped hand,
battery, session reset, elapsed-time cap, switching between Snake and Chess,
and stat sync with mocked game APIs.

For release verification, start with nonzero Boredom and Unhappiness, play
Snake for at least one in-game hour in single-player and as an ordinary
multiplayer client, then compare both stats before and after. Pause, close the
device, and reconnect to check that relief stops and the multiplayer change
persists. Restart the server and client with matching mod files first.

## Equip/open regression checks

From the repository root, run with Lua 5.3 or Fengari:

```powershell
npx.cmd --yes --package fengari-node-cli fengari tests/palm_equip_open.lua "E:/SteamLibrary/steamapps/common/ProjectZomboid"
```

Supply your installed Build 42 game directory. The harness loads its vanilla `ISBaseObject`, `ISBaseTimedAction`, and `ISEquipWeaponAction` plus the mod's actual equip, open, context-menu, and utility code. Player/inventory APIs and network transport are mocked.

The constructor round-trip mirrors the installed game's `NetTimedAction.set()` / `parse()`: serialize instance fields by constructor parameter names, then resolve the server class by its `Type`. It catches missing global registration and accidentally transmitting adjusted `maxTime` instead of `maxTimeInit`.

## Live multiplayer release check

Use matching mod files on a restarted server and client. Join as an ordinary player with debug instant actions disabled; an admin-only test is insufficient.

1. Open from main inventory with empty hands: device uses the primary hand.
2. Hold a hammer in the primary hand, then open: device uses the secondary hand and the hammer remains equipped.
3. Repeat from a belt slot; check both the draw animation and final hand models. Close and reopen.
4. Open from a carried bag and from a nearby container; the transfer must finish before equip/open.
5. Test a two-handed weapon, an already-held PalmPilot, and an existing saved device after reconnecting.
6. Interrupt by running or cancelling the queue. No duplicated dialog, duplicate item, or automatic retry should occur; a fresh open request should still work.
7. If opening fails, collect the client's `console.txt` and matching server log around the same attempt. Search for `[PalmPilots]`, `PalmPilotsEquipAction`, and `NetTimedAction`. Include the game build, mod version, and enabled mods. Redact passwords and other account details before sharing.

The automated harness does not simulate packet loss, server loading order, animation playback, or other mods. Passing it does not prove those scenarios work.
