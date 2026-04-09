# MHW_AutoDodge

Auto dodge, guard, and counter for all 14 weapon types in **Monster Hunter Wilds**.

Ported from [MHR_AutoDodge](https://github.com/Atomoxide/MHR_AutoDodge) by Atomoxide.

---

## How it works

When an enemy attack lands on the player the mod:

1. **Grants invincibility frames** — calls `startNoHitTimer` on the hunter character. This always works regardless of weapon or animation state.
2. **Blocks the hit** — returns `SKIP_ORIGINAL` in the damage pre-hook, equivalent to a perfect dodge.
3. **Triggers a counter animation** — calls `changeActionRequest` with the weapon-specific counter move (where action IDs are known).

### Why do I still get hit sometimes?

The invincibility window has a configurable duration (default 0.6 s). There is also a 0.3 s cooldown between auto-dodges to prevent animation glitches. If two hits arrive in rapid succession the second may land during the cooldown. Increase the iframe duration slider in the config UI to reduce this.

---

## Installation

Requires [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/93).

1. Download `release/`.
2. Drop the `reframework/` folder into your game directory (merge if asked).
3. Launch the game — the mod loads automatically via REFramework autorun.
4. Configure via the in-game REFramework GUI → **Toggle Auto Dodge Config GUI**.

---

## Features

All features can be toggled individually in the in-game config window.

| Weapon | Auto-dodge | Weapon counter |
|---|---|---|
| Great Sword | roll dodge | Strong Arm Stance, Tackle |
| Long Sword | roll dodge | Foresight Slash, IAI Release, Serene Pose, Spirit Blade |
| Sword & Shield | roll dodge | Windmill, Shoryugeki, Guard Slash |
| Dual Blades | roll dodge | Shrouded Vault |
| Hammer | roll dodge | — |
| Hunting Horn | roll dodge | — |
| Lance | roll dodge | Insta-Guard, Spiral Thrust, Anchor Rage |
| Gunlance | roll dodge | Guard Edge |
| Switch Axe | roll dodge | Elemental Counter Burst |
| Charge Blade | roll dodge | Counter Peak Performance, Guard Points morph |
| Insect Glaive | roll dodge | — |
| Bow | roll dodge | Dodgebolt / Charging Side Step |
| Light Bowgun | roll dodge | Wyvern Counter |
| Heavy Bowgun | roll dodge | Counter Shot (Focus Blast), Counter Charge |

---

## Weapon counter action IDs

MH Wilds uses a different action system from MH Rise. Counter animations are triggered via `changeActionRequest(category, index)`. Most `index` values are currently stubs — they need to be discovered by inspecting `get_SubActionController():get_CurrentActionID()` in-game while performing each move.

**To contribute action IDs:**

1. Enable REFramework's Lua console.
2. Perform the move you want to map.
3. Read the `_Category` and `_Index` from:
   ```lua
   local char = sdk.get_managed_singleton('app.PlayerManager'):getMasterPlayer():get_Character()
   local aid  = char:get_SubActionController():get_CurrentActionID()
   print(aid._Category, aid._Index)
   ```
4. Update `MHW_AutoDodge/ActionMove.lua` and submit a PR.

The dodge lock table (`dodgeLockMove`) also needs filling in — these are indices of animations that should NOT be interrupted (e.g. while already mid-counter).

---

## Config

Settings are saved to `MHW_AutoDodge.json` in the REFramework scripts directory.

| Setting | Default | Description |
|---|---|---|
| `enabled` | true | Master switch |
| `rollDodge` | true | Trigger dodge animation (visual) |
| `iframeDuration` | 0.6 | Seconds of invincibility granted |
| `forcedDodge` | false | Bypass animation lock (very OP) |
| Per-weapon counters | true | Toggle each counter move individually |
| Distance sliders | 3–7 | Counter activates only within this range of lock-on target |

---

## Differences from MHR_AutoDodge

| MH Rise | MH Wilds |
|---|---|
| `snow.player.PlayerManager` | `app.PlayerManager` |
| `findMasterPlayer()` | `getMasterPlayer():get_Character()` |
| `behaviorTree:setCurrentNode(nodeID)` | `changeActionRequest(category, index)` |
| `checkCalcDamage_DamageSide` hook | `evHit_Damage` hook |
| `snow.player.ActStatus` status tags | TBD — status checks removed until Wilds API confirmed |
| Node ID hashes (32-bit) | `ace.ACTION_ID` { _Category, _Index } |

---

## Credits

- [MHR_AutoDodge](https://github.com/Atomoxide/MHR_AutoDodge) by Atomoxide — original mod this is based on
- [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/93) by praydog
- Port and MH Wilds adaptation by Abeelha
