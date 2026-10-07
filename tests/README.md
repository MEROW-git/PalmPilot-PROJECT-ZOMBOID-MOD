# Regression checks

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
```

This loads the actual Snake screen and checks active play, game-time pause,
pause/resume, stat minimums, collision, and a long-update cap with mocked
Build 42 character stats. It does not replace a live single-player and
multiplayer check before publishing.

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
