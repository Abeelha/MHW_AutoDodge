-- MHW_AutoDodge.lua
-- Auto Perfect Dodge (Bow) and Auto Perfect Guard (HBG) for Monster Hunter Wilds.
--
-- BOW:  hooks evHit_Damage PRE + SKIP_ORIGINAL, queues Cat=2 Idx=9 (dodge start).
--       Secondary evHit_DamagePreProcess calls then upgrade to Cat=2 Idx=33 + SUB Cat=1 Idx=1.
--
-- HBG:  hooks evHit_Damage + SKIP_ORIGINAL (confirmed working, unchanged).

local CONFIG_PATH = "MHW_AutoDodge.json"
local BOW         = 11
local HBG         = 12
local COOLDOWN    = 0.3

local ACTION_ID_TD = sdk.find_type_definition("ace.ACTION_ID")
local HUNTER_TD    = sdk.find_type_definition("app.HunterCharacter")

local character  = nil
local weaponType = -1
local lastHitAt  = 0

local function defaultConfig()
    return {
        enabled      = true,
        evadeEnabled = true,
        guardEnabled = true,
        guardIframes = 0.25,
        bypassChecks = true,
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

local function triggerHBGGuard()
    pcall(function() character:call("startNoHitTimer(System.Single)", cfg.guardIframes) end)
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
    else
        character  = nil
        weaponType = -1
    end
end)

local hitMethod = HUNTER_TD and HUNTER_TD:get_method('evHit_Damage')

if hitMethod then
    sdk.hook(hitMethod,
        function(args)
            if not cfg.enabled then return end

            local now = os.clock()
            if now - lastHitAt < COOLDOWN then return end

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
                triggerHBGGuard()
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.evadeEnabled and weaponType == BOW then
                -- Cat=2 Idx=9 (dodge start) → secondary PreProcess hits → Cat=2 Idx=33 + SUB 1,1
                triggerAction(2, 9)
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

re.on_draw_ui(function()
    if imgui.button('Auto Evade / Guard') then
        showWindow = not showWindow
        saveConfig()
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

    imgui.begin_disabled(not cfg.enabled)

    imgui.text('Auto Perfect Dodge  (Bow)')
    imgui.indent(16)
    c, cfg.evadeEnabled = imgui.checkbox('Active##evade', cfg.evadeEnabled)
    changed = changed or c
    imgui.unindent(16)

    imgui.spacing()

    imgui.text('Auto Perfect Guard  (HBG)')
    imgui.indent(16)
    c, cfg.guardEnabled = imgui.checkbox('Active##guard', cfg.guardEnabled)
    changed = changed or c
    imgui.begin_disabled(not cfg.guardEnabled)
    c, cfg.guardIframes = imgui.slider_float('IFrames (s)##guard', cfg.guardIframes, 0.1, 2.0)
    changed = changed or c
    imgui.end_disabled()
    imgui.unindent(16)

    imgui.end_disabled()

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    c, cfg.bypassChecks = imgui.checkbox('Bypass mine/enemy checks', cfg.bypassChecks)
    changed = changed or c

    imgui.spacing()
    imgui.text_colored(
        string.format('Weapon: %d  (%s)', weaponType,
            weaponType == HBG and 'HBG' or weaponType == BOW and 'Bow' or 'other'),
        0xFFAAAAAA)

    imgui.spacing()
    if imgui.button('Reset to defaults') then cfg = defaultConfig(); saveConfig() end
    if changed then saveConfig() end

    imgui.end_window()
end)
