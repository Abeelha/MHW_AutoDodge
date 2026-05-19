# MHW_AutoDodge — Project Knowledge Base

REFramework Lua mod for Monster Hunter Wilds. Hooks the player character's damage event to
automatically trigger a perfect dodge (Bow) or perfect guard (HBG) on every hit.

---

## How the game's hit/evade system works

Every monster hit calls two managed methods on `app.HunterCharacter` in sequence:

```
evHit_DamagePreProcess(...)   → always returns 0 (no action required from us)
evHit_Damage(...)             → returns 0 (player is hit) or 1425417188 (player evaded)
```

The return value of `evHit_Damage` is read by the **caller** to decide what happens:
- `0`           → hit lands, player enters hit-stun (Cat=1 Idx=49), takes damage
- `1425417188`  → hit evaded, game triggers dodge/guard chain naturally

When the player **manually** perfect-dodges, `evHit_Damage` runs and returns `1425417188`
naturally because the player is in a dodge-action state. The game then fires:
```
BASE Cat=2 Idx=9   (dodge start, ~7ms after evHit_Damage exits)
SUB  Cat=0 Idx=0
[secondary evHit_DamagePreProcess calls from same multi-hit attack, ~35ms later]
BASE Cat=2 Idx=33  (perfect dodge state)
SUB  Cat=1 Idx=1   (perfect dodge marker — triggers flash/slow-mo effect)
```

The **perfect dodge flash/slow effect** is NOT triggered by setting action IDs manually.
It is triggered by the game's own secondary hit re-evaluation while the player is in
`Cat=2 Idx=9` state. The secondary `evHit_DamagePreProcess` calls are what upgrade the
dodge to perfect. They only come if:
1. `evHit_Damage` was skipped (SKIP_ORIGINAL) AND
2. `Cat=2 Idx=9` was queued so the player enters that state before the secondary hits arrive

---

## Working solution

### Bow — Auto Perfect Dodge

```lua
-- In evHit_Damage PRE hook:
triggerAction(2, 9)            -- queue Cat=2 Idx=9 (dodge start)
return sdk.PreHookResult.SKIP_ORIGINAL

-- POST hook: return retval unchanged
```

What happens:
1. SKIP_ORIGINAL cancels the hit (no damage, no hit-stun)
2. SKIP_ORIGINAL causes retval → 1425417188 (game treats hit as evaded)
3. `changeActionRequest(2,9)` queues on the base action controller, fires ~1 frame later
4. Secondary hits from the same attack see `Cat=2 Idx=9` active → natural upgrade to
   `BASE Cat=2 Idx=33 + SUB Cat=1 Idx=1` → perfect dodge flash/slow fires

### HBG — Auto Perfect Guard

```lua
-- In evHit_Damage PRE hook:
character:call("startNoHitTimer(System.Single)", cfg.guardIframes)
triggerAction(1, 146)          -- Cat=1 Idx=146 = HBG perfect guard action
return sdk.PreHookResult.SKIP_ORIGINAL
```

`startNoHitTimer` grants extra invincibility frames during the guard animation.
`Cat=1 Idx=146` is the HBG perfect guard action. SKIP_ORIGINAL cancels the hit and retval
becomes 1425417188 automatically.

### LBG — Auto Dodge

Same pattern as Bow but with a different action ID:

```lua
-- In evHit_Damage PRE hook:
triggerAction(1, 19)           -- Cat=1 Idx=19 = LBG dodge start
return sdk.PreHookResult.SKIP_ORIGINAL
```

### GS — Auto Perfect Guard

Same pattern as HBG (guard-type), same perfect guard action ID:

```lua
-- In evHit_Damage PRE hook:
character:call("startNoHitTimer(System.Single)", cfg.gsIframes)
triggerAction(1, 146)          -- Cat=1 Idx=146 = GS perfect guard (same ID as HBG)
return sdk.PreHookResult.SKIP_ORIGINAL
```

---

## Known action IDs

| Weapon | Action | BASE Cat | BASE Idx | SUB Cat | SUB Idx |
|--------|--------|----------|----------|---------|---------|
| Bow    | Dodge start (queue this) | 2 | 9 | — | — |
| Bow    | Dodge / Perfect dodge state | 2 | 33 | 1 | 1 |
| Bow    | Hit-stun | 1 | 49 | — | — |
| LBG    | Dodge start (queue this) | 1 | 19 | — | — |
| LBG    | Post-dodge state | 2 | 60 | 1 | 9 |
| LBG    | Aiming idle | 1 | 153 | — | — |
| HBG    | Perfect guard (queue this) | 1 | 146 | — | — |
| GS     | Guard start | 1 | 141 | — | — |
| GS     | Perfect guard (queue this) | 1 | 146 | — | — |
| SnS    | Guard start | 2 | 6 | — | — |
| SnS    | Guard state | 1 | 141/142 | — | — |
| SnS    | Perfect guard (queue this) | 1 | 146 | — | — |
| SnS    | Dodge (queue this) | 1 | 19 | — | — |
| DB     | Dodge start normal (queue this) | 1 | 19 | — | — |
| DB     | Demon mode enable | 2 | 53 | — | — |
| DB     | Demon mode dodge (queue this) | 2 | 42 | — | — |
| DB     | Demon mode perfect dodge | 2 | 47 | — | — |
| CB     | Perfect guard (queue this) | 1 | 146 | — | — |
| CB     | Dodge (queue this) | 1 | 19 | — | — |
| SA     | Sword counter start (queue this) | 2 | 31 | — | — |
| SA     | Sword perfect counter | 2 | 32 | — | — |
| SA     | Axe offset start (queue this) | 2 | 5 | — | — |
| SA     | Axe perfect offset | 2 | 8 | — | — |
| Any    | Perfect dodge marker (SUB) | — | — | 1 | 1 |

`BASE Cat=2 Idx=33` is shared between normal and perfect dodge for Bow. The difference is whether
`SUB Cat=1 Idx=1` fires alongside it — that only happens via the natural secondary-hit upgrade.

HBG, GS, SnS (guard mode), and CB (guard mode) all share the same perfect guard action ID (`Cat=1 Idx=146`).
The `triggerGuard` helper handles all four.

DB demon mode — no persistent flag found via method scanning. Brute force: always queue
Cat=2 Idx=53 (demon mode enable) + Cat=2 Idx=47 (demon dodge) together. Works in both stances.

SA sword/axe mode — detected via `character:call("get_WeaponHandling"):get_field("_Mode")`.
`app.cHunterWp08Handling._Mode`: 0 = axe form, 1 = sword form. Persistent, polled each frame, reliable.
Access: `char:call("get_WeaponHandling")` returns `app.cHunterWp08Handling`, then `:get_field("_Mode")`.
Do NOT use _OverwriteWeaponOnOffState — always 0 in both forms (false positive from baseline diff timing).
Do NOT use app.Weapon.get_VisualState — transitional only (flashes 4/5 during morph animation).
Do NOT use get_IsAttachToHand — stays true in both forms.
Do NOT use get_VarietyIdleMotionType — returns -1 during all non-idle states including sword combat.
Sword mode → queue Cat=2 Idx=31 (counter). Axe mode → queue Cat=2 Idx=5 (offset).

SnS and CB have user-selectable mode (guard vs dodge) stored in `cfg.snsGuard` / `cfg.cbGuard`.

Weapon type IDs from `char:get_WeaponType()`:
- GS  = `0`
- SNS = `1`
- DB  = `2`
- SA  = `8`
- CB  = `9`
- Bow = `11`
- HBG = `12`
- LBG = `13`

---

## Adding a new weapon

1. Find the weapon's ID via `char:get_WeaponType()` (use `MHW_ActionLogger` while in-game)
2. Find the guard/evade action ID — use `MHW_ActionLogger` to record BASE/SUB changes while
   manually performing the action
3. Decide the pattern:
   - **Evade-type** (like Bow): queue the dodge-start action + SKIP_ORIGINAL
   - **Guard-type** (like HBG): `startNoHitTimer` + queue guard action + SKIP_ORIGINAL
4. Add the weapon constant and a config toggle following the existing `BOW`/`HBG` pattern
5. Add a UI section in `re.on_draw_ui` following the existing indent/checkbox pattern

Example skeleton for a new guard weapon (e.g. Lance, weapon type 3):

```lua
local LANCE = 3

-- in defaultConfig():
lanceEnabled = true,

-- in hook PRE:
elseif cfg.lanceEnabled and weaponType == LANCE then
    triggerAction(X, Y)    -- replace X,Y with discovered guard action IDs
    return sdk.PreHookResult.SKIP_ORIGINAL
end

-- in UI:
imgui.text('Auto Guard  (Lance)')
imgui.indent(16)
c, cfg.lanceEnabled = imgui.checkbox('Active##lance', cfg.lanceEnabled)
changed = changed or c
imgui.unindent(16)
```

---

## Debugging workflow

Use `tools/MHW_ActionLogger.lua` (NOT the version in game's autorun — that one is disabled).

### To discover new action IDs:
1. Copy `tools/MHW_ActionLogger.lua` to `reframework/autorun/`
2. Load a hunt, open REFramework UI → `[ActionLog]` section shows live BASE/SUB changes
3. Perform actions manually, note the Cat/Idx sequence in the history list
4. Remove the file from autorun when done (it has per-frame overhead)

### To debug evHit_Damage behavior:
The full logging version is in `tools/MHW_ActionLogger.lua`. Replace its content with the
debug version below, copy to autorun, get hit, then read `re2_framework_log.txt`:

```lua
local HUNTER_TD = sdk.find_type_definition("app.HunterCharacter")
local character = nil
local lastBase, lastSub = "", ""

re.on_pre_application_entry('BeginRendering', function()
    pcall(function()
        local pm = sdk.get_managed_singleton('app.PlayerManager')
        character = pm and pm:getMasterPlayer() and pm:getMasterPlayer():get_Character()
    end)
    if not character then return end
    local function poll(getter, prefix, last)
        pcall(function()
            local ctrl = character:call(getter)
            if not ctrl then return end
            local id = ctrl:call("get_CurrentActionID")
            if not id then return end
            local cat, idx = id:get_field("_Category"), id:get_field("_Index")
            local key = cat.."_"..idx
            if key ~= last[1] then last[1] = key
                log.info(string.format('[%.3f] %s Cat=%d Idx=%d', os.clock(), prefix, cat, idx))
            end
        end)
    end
    poll("get_BaseActionController", "BASE", {lastBase})
    poll("get_SubActionController",  "SUB ", {lastSub})
end)

local evHit = HUNTER_TD and HUNTER_TD:get_method("evHit_Damage")
if evHit then
    sdk.hook(evHit,
        function(args) log.info(string.format('[%.3f] >> evHit_Damage ENTER', os.clock())) end,
        function(retval)
            log.info(string.format('[%.3f] << evHit_Damage EXIT retval=%d', os.clock(), sdk.to_int64(retval)))
            return retval
        end)
end

local preProc = HUNTER_TD and HUNTER_TD:get_method("evHit_DamagePreProcess")
if preProc then
    sdk.hook(preProc,
        function(args) log.info(string.format('[%.3f] >> evHit_DamagePreProcess ENTER', os.clock())) end,
        function(retval)
            log.info(string.format('[%.3f] << evHit_DamagePreProcess EXIT retval=%d', os.clock(), sdk.to_int64(retval)))
            return retval
        end)
end
```

### What the log should look like for a WORKING perfect dodge (Bow):
```
[T+0ms]  >> evHit_Damage ENTER
[T+0ms]  << evHit_Damage EXIT retval=1425417188   ← SKIP_ORIGINAL result
[T+7ms]  BASE Cat=2 Idx=9                          ← dodge start (our queued action)
[T+7ms]  SUB  Cat=0 Idx=0
[T+35ms] >> evHit_DamagePreProcess ENTER           ← secondary hit #1
[T+35ms] << evHit_DamagePreProcess EXIT retval=0
[T+35ms] >> evHit_DamagePreProcess ENTER           ← secondary hit #2
[T+35ms] << evHit_DamagePreProcess EXIT retval=0
[T+63ms] BASE Cat=2 Idx=33                         ← perfect dodge!
[T+63ms] SUB  Cat=1 Idx=1                          ← flash/slow effect fires here
```

If you see `retval=0` → player got hit, action was not set or SKIP_ORIGINAL wasn't returned.
If you see `retval=1425417188` but NO secondary PreProcess calls → dodge action didn't queue correctly.
If you see `retval=1425417188` + secondary PreProcess but NO `Cat=2 Idx=33` → wrong action ID queued.

---

## What does NOT work — do not retry these

### `changeActionRequest` in PRE hook WITHOUT SKIP_ORIGINAL
Queues the action for the next frame. `evHit_Damage` runs synchronously on the same frame
before the action propagates. Result: retval=0, player gets hit-stun, dodge fires a frame
later (overridden by hit-stun).

### `changeActionImmediate` (does not exist)
`ace.BaseActionController` does not have a `changeActionImmediate` managed method.
Both overloads silently fail inside `pcall`. Do not add `immediate=true` logic.

### SKIP_ORIGINAL + manually returning `sdk.to_ptr(1425417188)` from POST hook, without queuing any action
Returns the evade code to the caller correctly (godmode — no damage), but:
- No action was queued → player stays in idle state
- Secondary `evHit_DamagePreProcess` calls do NOT come (nothing set up the multi-hit chain)
- No dodge animation, no perfect effects. Just invisible godmode.

### SKIP_ORIGINAL + manually setting `Cat=2 Idx=33` directly (skipping Cat=2 Idx=9)
Produces a dodge animation but:
- Secondary PreProcess calls do NOT come (they only arrive when `Cat=2 Idx=9` is active)
- Without secondary calls, the game never upgrades to perfect dodge
- No flash/slow effect. Normal dodge animation only.

### `beginDodgeNoHit(true)` in PRE hook without SKIP_ORIGINAL
Calls the method, but `evHit_Damage` does not check this flag to determine evade/hit.
Result: retval=0, player gets hit-stun. Confirmed not the right state gate.

### `startNoHitTimer(X)` in PRE hook without SKIP_ORIGINAL (for Bow)
Same result — `evHit_Damage` does not check the no-hit timer to decide the evade path.
(Note: `startNoHitTimer` IS used for HBG but only alongside SKIP_ORIGINAL, for extra
guard invincibility frames — not to influence evHit_Damage's return value.)

### Hooking `evHit_DamagePreProcess` POST and changing its retval
The outer caller calls both functions sequentially. `evHit_Damage` does not read
`evHit_DamagePreProcess`'s return value. Changing it has no effect on evHit_Damage.

### Manually triggering SUB Cat=1 Idx=1 directly
`SUB Cat=1 Idx=1` is a consequence of perfect dodge detection, not a trigger for it.
Setting it manually does not fire the flash/slow effect.

---

## REFramework Lua gotchas

- **SKIP_ORIGINAL + retval**: When SKIP_ORIGINAL is returned from PRE hook, the POST hook
  still fires. The `retval` parameter in POST is effectively 1425417188 for `evHit_Damage`
  (the game treats the skipped call as "evaded"). Do not override this unless needed.

- **Hook registration order**: Files load alphabetically. PRE hooks fire in registration order
  (first registered = first to fire). POST hooks fire in reverse order. If ActionLogger loads
  before AutoDodge (M-H-W-_-A < M-H-W-_-Au), ActionLogger PRE fires first.

- **`pcall` swallows all errors silently**: Always wrap `character:call(...)` in `pcall`.
  If a method doesn't exist, it fails silently — not a crash, not a log entry. This is why
  `changeActionImmediate` appeared to "do nothing" for so long.

- **`sendAction` fallback pattern**: Try the typed overload `changeActionRequest(ace.ACTION_ID)`
  first (more reliable), fall back to `changeActionRequest(System.Int32,System.Int32)`.

- **`os.clock()` for cooldowns**: Game time, not wall time. Suitable for COOLDOWN checks.

- **`sdk.to_managed_object(args[1])`**: In instance methods, `args[1]` is `this` (the character
  instance the method was called on). `args[2]` onwards are actual parameters. This matters
  for the `bypassChecks = false` mine-check logic.

- **`character` can be nil between zones**: The BeginRendering poll handles this. All code
  paths that use `character` check it first (`if not character then return end` in triggerAction).
