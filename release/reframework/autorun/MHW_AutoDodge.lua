-- MHW_AutoDodge.lua
-- Auto Perfect Dodge (Bow, LBG) and Auto Perfect Guard (HBG, GS) for Monster Hunter Wilds.
--
-- All weapons hook evHit_Damage PRE and return SKIP_ORIGINAL to cancel the hit.
--
-- BOW:  queues Cat=2 Idx=9 (dodge start). Secondary evHit_DamagePreProcess calls
--       from the same attack upgrade to Cat=2 Idx=33 + SUB Cat=1 Idx=1 naturally.
--
-- LBG:  queues Cat=1 Idx=19 (dodge start). Same secondary-hit upgrade pattern as Bow.
--
-- HBG:  startNoHitTimer + queues Cat=1 Idx=146 (perfect guard).
--
-- GS:   startNoHitTimer + queues Cat=1 Idx=146 (perfect guard, same action ID as HBG).
--
-- Mount detection: character:call("get_IsPorterRiding") == true → skip hook entirely.

local CONFIG_PATH = "MHW_AutoDodge.json"
local GS          = 0
local BOW         = 11
local HBG         = 12
local LBG         = 13

local ACTION_ID_TD = sdk.find_type_definition("ace.ACTION_ID")
local HUNTER_TD    = sdk.find_type_definition("app.HunterCharacter")

local character     = nil
local weaponType    = -1
local isPorterRiding = false
local lastHitAt     = 0

local function defaultConfig()
    return {
        enabled           = true,
        universalCooldown = 0.3,
        -- Bow
        evadeEnabled  = true,
        bowCooldown   = 0.3,
        -- LBG
        lbgEnabled    = true,
        lbgCooldown   = 0.3,
        -- HBG
        guardEnabled  = true,
        hbgCooldown   = 0.3,
        -- GS
        gsEnabled     = true,
        gsCooldown    = 0.3,
        -- Misc
        bypassChecks  = true,
    }
end

local cfg = defaultConfig()

local function loadConfig()
    if not json then return end
    local f = json.load_file(CONFIG_PATH)
    if not f then return end
    for k in pairs(cfg) do
        if f[k] ~= nil then cfg[k] = f[k] end
    end
end

local function saveConfig()
    if json then json.dump_file(CONFIG_PATH, cfg) end
end

loadConfig()

local function sendAction(ctrl, cat, idx)
    if not ctrl then return end
    if ACTION_ID_TD then
        local ok = pcall(function()
            local aid = ValueType.new(ACTION_ID_TD)
            aid._Category = cat
            aid._Index    = idx
            ctrl:call("changeActionRequest(ace.ACTION_ID)", aid)
        end)
        if ok then return end
    end
    pcall(function() ctrl:call("changeActionRequest(System.Int32,System.Int32)", cat, idx) end)
end

local function triggerAction(cat, idx)
    if not character then return end
    local ok, ctrl = pcall(function() return character:call("get_BaseActionController") end)
    if ok and ctrl then sendAction(ctrl, cat, idx) end
end

local function triggerGuard()
    pcall(function() character:call("startNoHitTimer(System.Single)", 0.25) end)
    triggerAction(1, 146)
end

re.on_pre_application_entry('BeginRendering', function()
    local ok, char = pcall(function()
        local pm = sdk.get_managed_singleton('app.PlayerManager')
        if not pm then return nil end
        local mp = pm:getMasterPlayer()
        if not mp then return nil end
        return mp:get_Character()
    end)
    if ok and char then
        character = char
        local wok, wt = pcall(function() return char:get_WeaponType() end)
        weaponType = wok and wt or -1
        local rok, rv = pcall(function() return char:call("get_IsPorterRiding") end)
        isPorterRiding = rok and rv == true
    else
        character      = nil
        weaponType     = -1
        isPorterRiding = false
    end
end)

local hitMethod = HUNTER_TD and HUNTER_TD:get_method('evHit_Damage')

if hitMethod then
    sdk.hook(hitMethod,
        function(args)
            if not cfg.enabled then return end
            if isPorterRiding then return end

            local now = os.clock()
            local cd  = cfg.universalCooldown
            if     weaponType == BOW then cd = cfg.bowCooldown
            elseif weaponType == LBG then cd = cfg.lbgCooldown
            elseif weaponType == HBG then cd = cfg.hbgCooldown
            elseif weaponType == GS  then cd = cfg.gsCooldown
            end
            if now - lastHitAt < cd then return end

            if not cfg.bypassChecks then
                if not character then return end
                local mine = false
                pcall(function() mine = sdk.to_managed_object(args[1]) == character end)
                if not mine then
                    pcall(function() mine = sdk.to_managed_object(args[2]) == character end)
                end
                if not mine then return end
            end

            lastHitAt = now

            if cfg.guardEnabled and weaponType == HBG then
                triggerGuard()
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.gsEnabled and weaponType == GS then
                triggerGuard()
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.evadeEnabled and weaponType == BOW then
                triggerAction(2, 9)
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.lbgEnabled and weaponType == LBG then
                triggerAction(1, 19)
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end,
        function(retval) return retval end
    )
    log.info('[MHW_AutoDodge] hooked OK')
else
    log.warn('[MHW_AutoDodge] evHit_Damage not found — mod inactive.')
end

-- UI
local showWindow = false

local function weaponName()
    if     weaponType == BOW then return 'Bow'
    elseif weaponType == HBG then return 'HBG'
    elseif weaponType == LBG then return 'LBG'
    elseif weaponType == GS  then return 'GS'
    else return 'other' end
end

re.on_draw_ui(function()
    if imgui.button('Auto Evade / Guard') then
        showWindow = not showWindow
    end
    if not showWindow then return end

    showWindow = imgui.begin_window('MHW Auto Evade / Guard', showWindow, 0)

    local changed = false
    local c

    c, cfg.enabled = imgui.checkbox('Enabled', cfg.enabled)
    changed = changed or c

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    imgui.text('Universal Cooldown')
    imgui.indent(16)
    c, cfg.universalCooldown = imgui.slider_float('All weapons##uni', cfg.universalCooldown, 0.05, 2.0)
    if c then
        cfg.bowCooldown = cfg.universalCooldown
        cfg.lbgCooldown = cfg.universalCooldown
        cfg.hbgCooldown = cfg.universalCooldown
        cfg.gsCooldown  = cfg.universalCooldown
        changed = true
    end
    imgui.unindent(16)

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    imgui.begin_disabled(not cfg.enabled)

    -- Bow
    imgui.text('Auto Perfect Dodge  (Bow)')
    imgui.indent(16)
    c, cfg.evadeEnabled = imgui.checkbox('Active##evade', cfg.evadeEnabled)
    changed = changed or c
    c, cfg.bowCooldown = imgui.slider_float('Cooldown (s)##bow', cfg.bowCooldown, 0.05, 2.0)
    changed = changed or c
    imgui.unindent(16)

    imgui.spacing()

    -- LBG
    imgui.text('Auto Dodge  (LBG)')
    imgui.indent(16)
    c, cfg.lbgEnabled = imgui.checkbox('Active##lbg', cfg.lbgEnabled)
    changed = changed or c
    c, cfg.lbgCooldown = imgui.slider_float('Cooldown (s)##lbg', cfg.lbgCooldown, 0.05, 2.0)
    changed = changed or c
    imgui.unindent(16)

    imgui.spacing()

    -- HBG
    imgui.text('Auto Perfect Guard  (HBG)')
    imgui.indent(16)
    c, cfg.guardEnabled = imgui.checkbox('Active##guard', cfg.guardEnabled)
    changed = changed or c
    c, cfg.hbgCooldown = imgui.slider_float('Cooldown (s)##hbg', cfg.hbgCooldown, 0.05, 2.0)
    changed = changed or c
    imgui.unindent(16)

    imgui.spacing()

    -- GS
    imgui.text('Auto Perfect Guard  (GS)')
    imgui.indent(16)
    c, cfg.gsEnabled = imgui.checkbox('Active##gs', cfg.gsEnabled)
    changed = changed or c
    c, cfg.gsCooldown = imgui.slider_float('Cooldown (s)##gs', cfg.gsCooldown, 0.05, 2.0)
    changed = changed or c
    imgui.unindent(16)

    imgui.end_disabled()

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    c, cfg.bypassChecks = imgui.checkbox('Bypass mine/enemy checks', cfg.bypassChecks)
    changed = changed or c

    imgui.spacing()
    imgui.text_colored(
        string.format('Weapon: %d  (%s)%s', weaponType, weaponName(), isPorterRiding and '  [MOUNTED]' or ''),
        isPorterRiding and 0xFF44FF44 or 0xFFAAAAAA)

    imgui.spacing()
    if imgui.button('Reset to defaults') then cfg = defaultConfig(); saveConfig() end
    if changed then saveConfig() end

    imgui.end_window()
end)
