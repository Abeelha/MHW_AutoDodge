# MHW_AutoDodge

Auto **Perfect Dodge** (Bow) and Auto **Perfect Guard** (HBG) for **Monster Hunter Wilds**.

When an enemy hits you, the mod intercepts the damage, blocks it, and triggers the correct defensive animation automatically.

> Requires [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/93).


## Showcase ( **Works with unequiped weapon also!** )


[![Watch the video](https://youtu.be/CrHF1qwJr9U)](https://youtu.be/CrHF1qwJr9U)


---

## Installation

1. Download the latest release.
2. Copy the `reframework/` folder into your game directory (merge if asked).
3. Launch the game — the mod loads automatically via REFramework autorun.
4. Configure in-game via the REFramework menu → **Auto Evade / Guard** button.

---

## How it works

| Weapon | Trigger | Animation |
|---|---|---|
| **Bow** | Any enemy hit while weapon drawn | Perfect Dodge (Cat=2 Idx=33) |
| **HBG** | Any enemy hit while weapon drawn | Perfect Guard (Cat=1 Idx=146) |

- Damage is blocked via `SKIP_ORIGINAL` on the `evHit_Damage` hook.
- The animation is forced via `changeActionImmediate` on the `BaseActionController`.
- **Weapon must be drawn** — sheathed hits are ignored (no godmode).

---

## Config

Settings are saved to `MHW_AutoDodge.json`.

| Setting | Default | Description |
|---|---|---|
| `enabled` | true | Master switch |
| `evadeEnabled` | true | Bow perfect dodge on/off |
| `evadeIframes` | 0.5 s | Iframes granted to Bow |
| `guardEnabled` | true | HBG perfect guard on/off |
| `guardIframes` | 0.25 s | Iframes granted to HBG |
| `bypassChecks` | false | Skip mine/enemy validation (enable if mod isn't triggering) |

---

## Dev tools (in `tools/`)

| File | Purpose |
|---|---|
| `MHW_ActionLogger.lua` | Real-time action ID logger — copy to `reframework/autorun/` and perform moves to discover Cat/Idx values |
| `MHW_MethodDumper.lua` | Dumps all methods of hunter character classes — use to find new API calls when adding weapon support |

---

## Adding more weapons

1. Equip the weapon in-game.
2. Copy `tools/MHW_ActionLogger.lua` to `reframework/autorun/`.
3. Perform the counter/perfect dodge manually.
4. Note the `BASE Cat` and `Idx` from the logger history.
5. Add to the `ACT` table in `MHW_AutoDodge.lua` and wire it in the hook.

---

## Credits

- [MHR_AutoDodge](https://github.com/Atomoxide/MHR_AutoDodge) by Atomoxide — original concept
- [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/93) by praydog
- MH Wilds port by Abeelha
