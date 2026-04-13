# MHW_AutoDodge

Auto **Perfect Dodge** and **Perfect Guard** for **Monster Hunter Wilds**.

Currently supported: **Bow** (perfect dodge), **LBG** (dodge), **HBG** (perfect guard), **GS** (perfect guard).

More weapons are being added over time based on requests from the [Nexus Mods comments](https://www.nexusmods.com/monsterhunterwilds/mods/4275).

> Requires [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/4275).


## Showcase ( **Works with unequipped weapon also!** )


[![Watch the video](https://youtu.be/CrHF1qwJr9U)](https://youtu.be/CrHF1qwJr9U)


## Installation

1. Download the latest release.
2. Copy the `reframework/` folder into your game directory (merge if asked).
3. Launch the game — the mod loads automatically via REFramework autorun.
4. Configure in-game via the REFramework menu → **Auto Evade / Guard** button.


## Config

Settings are saved to `MHW_AutoDodge.json` and editable in-game via the UI.

| Setting | Default | Description |
|---|---|---|
| `enabled` | true | Master switch |
| `evadeEnabled` | true | Bow auto perfect dodge |
| `lbgEnabled` | true | LBG auto dodge |
| `guardEnabled` | true | HBG auto perfect guard |
| `gsEnabled` | true | GS auto perfect guard |
| `universalCooldown` | 0.3s | Cooldown for all weapons (individual sliders also available) |
| `guardIframes` / `gsIframes` | 0.25s | Invincibility frames for guard weapons |
| `bypassChecks` | true | Skip mine/enemy validation (disable if you want stricter targeting) |


## Credits

- [MHR_AutoDodge](https://github.com/Atomoxide/MHR_AutoDodge) by Atomoxide — original concept
- [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/93) by praydog
- MH Wilds port by Abeelha
