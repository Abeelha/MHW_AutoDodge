-- MHW_AutoDodge.lua
-- Auto Perfect Dodge (Bow, LBG, DB) and Auto Perfect Guard (HBG, GS, SnS, CB) for Monster Hunter Wilds.
-- Auto Perfect Counter / Offset (SA) via enemy pre-process hook.
--
-- BOW:  evHit_Damage PRE → queues Cat=2 Idx=9 (dodge start) + SKIP_ORIGINAL.
--       Secondary evHit_DamagePreProcess calls upgrade to Cat=2 Idx=33 + SUB Cat=1 Idx=1.
--
-- LBG:  evHit_Damage PRE → queues Cat=1 Idx=19 (dodge start) + SKIP_ORIGINAL.
--
-- HBG:  evHit_Damage PRE → startNoHitTimer + Cat=1 Idx=146 (perfect guard) + SKIP_ORIGINAL.
--
-- GS:   evHit_Damage PRE → startNoHitTimer + Cat=1 Idx=146 (perfect guard) + SKIP_ORIGINAL.
--
-- SnS:  evHit_Damage PRE → guard (Cat=1 Idx=146) or dodge (Cat=1 Idx=19) + SKIP_ORIGINAL.
--
-- CB:   evHit_Damage PRE → guard (Cat=1 Idx=146) or dodge (Cat=1 Idx=19) + SKIP_ORIGINAL.
--
-- DB:   evHit_Damage PRE → Cat=2 Idx=53 (demon mode) + Cat=2 Idx=47 (demon dodge) + SKIP_ORIGINAL.
--
-- SA:   mode via app.cHunterWp08Handling._Mode: 0=axe, 1=sword.
--       Hooks evHit_AttackPreProcess on app.EnemyCharacter (fires BEFORE damage reaches hunter).
--       Sets CollisionLayer=18 (PARRY) + _ParryDamage → game applies counter damage natively.
--       Also queues counter animation + startNoHitTimer on player for visual + safety.
--       Axe:   CollisionLayer=18 + _ParryDamage=150 + Cat=2 Idx=5 → upgrades to Cat=2 Idx=8.
--       Sword: CollisionLayer=18 + _ParryDamage=600 + Cat=2 Idx=54 + Cat=2 Idx=31 → Cat=2 Idx=32.
--
-- Mount detection: get_IsPorterRiding == true → skip hooks entirely.

local CONFIG_PATH = "MHW_AutoDodge.json"
local SNS = 1
local DB  = 2
local GS  = 0
local SA  = 8
local CB  = 9
local BOW = 11
local HBG = 12
local LBG = 13

local ACTION_ID_TD = sdk.find_type_definition("ace.ACTION_ID")
local HUNTER_TD    = sdk.find_type_definition("app.HunterCharacter")
local ENEMY_TD     = sdk.find_type_definition("app.EnemyCharacter")

local character      = nil
local weaponType     = -1
local isPorterRiding = false
local isWeaponOn     = false
local saIsSwordMode   = false

local lastHitAt      = 0

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
        hbgOffset     = false,
        hbgCooldown   = 0.3,
        -- GS
        gsEnabled     = true,
        gsCooldown    = 0.3,
        -- SnS
        snsEnabled    = true,
        snsGuard      = true,
        snsCooldown   = 0.3,
        -- DB
        dbEnabled     = true,
        dbCooldown    = 0.3,
        -- CB
        cbEnabled     = true,
        cbGuard       = true,
        cbCooldown    = 0.3,
        -- SA
        saEnabled     = true,
        saCooldown    = 0.3,
        -- Misc
        requireWeaponOn = true,
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
        local wok2, wv = pcall(function() return char:call("get_IsWeaponOn") end)
        isWeaponOn = wok2 and wv == true
        -- SA mode: app.cHunterWp08Handling._Mode  0=axe 1=sword
        if weaponType == SA then
            pcall(function()
                local wh = char:call("get_WeaponHandling")
                if not wh then return end
                local mode = wh:get_field("_Mode")
                if mode ~= nil then saIsSwordMode = (mode == 1) end
            end)
        end
    else
        character      = nil
        weaponType     = -1
        isPorterRiding = false
        isWeaponOn     = false
        saIsSwordMode   = false
    end
end)

local hitMethod = HUNTER_TD and HUNTER_TD:get_method('evHit_Damage')

if hitMethod then
    sdk.hook(hitMethod,
        function(args)
            if not cfg.enabled then return end
            if isPorterRiding then return end
            if cfg.requireWeaponOn and not isWeaponOn then return end

            local now = os.clock()
            local cd  = cfg.universalCooldown
            if     weaponType == BOW then cd = cfg.bowCooldown
            elseif weaponType == LBG then cd = cfg.lbgCooldown
            elseif weaponType == HBG then cd = cfg.hbgCooldown
            elseif weaponType == GS  then cd = cfg.gsCooldown
            elseif weaponType == SNS then cd = cfg.snsCooldown
            elseif weaponType == DB  then cd = cfg.dbCooldown
            elseif weaponType == CB  then cd = cfg.cbCooldown
            elseif weaponType == SA  then cd = cfg.saCooldown
            end
            if now - lastHitAt < cd then return end

            -- Check 1: hit is on OUR character (try args[1] and args[2]).
            do
                local isMine = false
                for _, ai in ipairs({1, 2}) do
                    if isMine then break end
                    pcall(function()
                        local obj = sdk.to_managed_object(args[ai])
                        if obj and obj:call("get_IsMaster") == true then isMine = true end
                    end)
                end
                if not isMine then return end
            end

            -- Check 2: attack is FROM an enemy (not ally/mine hitting us).
            do
                local isEnemy = false
                for _, ai in ipairs({2, 3}) do
                    if isEnemy then break end
                    pcall(function()
                        local hi = sdk.to_managed_object(args[ai])
                        if not hi then return end
                        local ao = hi:get_field("<AttackOwner>k__BackingField")
                        if not ao then return end
                        local tag = ao:get_Tag()
                        if tag and tag:find("Enemy") then isEnemy = true end
                    end)
                end
                if not isEnemy then return end
            end

            lastHitAt = now

            if cfg.guardEnabled and weaponType == HBG then
                if cfg.hbgOffset then triggerAction(2, 30)
                else triggerGuard() end
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.gsEnabled and weaponType == GS then
                triggerGuard()
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.snsEnabled and weaponType == SNS then
                if cfg.snsGuard then triggerGuard()
                else triggerAction(1, 19) end
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.evadeEnabled and weaponType == BOW then
                triggerAction(2, 9)
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.lbgEnabled and weaponType == LBG then
                triggerAction(1, 19)
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.cbEnabled and weaponType == CB then
                if cfg.cbGuard then triggerGuard()
                else triggerAction(1, 19) end
                return sdk.PreHookResult.SKIP_ORIGINAL
            elseif cfg.dbEnabled and weaponType == DB then
                triggerAction(2, 53)  -- force demon mode enable
                triggerAction(2, 47)  -- demon dodge → secondary hits upgrade to perfect (Cat=2 Idx=48)
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end,
        function(retval) return retval end
    )
    log.info('[MHW_AutoDodge] evHit_Damage hooked OK')
else
    log.warn('[MHW_AutoDodge] evHit_Damage not found — mod inactive.')
end

-- SA: hook evHit_AttackPreProcess on app.EnemyCharacter.
-- Fires when an enemy's attack is about to process a hit. DamageOwner == "MasterPlayer"
-- means the attack is targeting us. We set CollisionLayer=18 (PARRY) + _ParryDamage to
-- make the game apply counter damage to the enemy natively, then queue the SA animation.
local saEnemyMethod = ENEMY_TD and ENEMY_TD:get_method("evHit_AttackPreProcess(app.HitInfo)")

if saEnemyMethod then
    sdk.hook(saEnemyMethod,
        function(args)
            if not cfg.enabled or not cfg.saEnabled then return end
            if weaponType ~= SA then return end
            if isPorterRiding then return end
            if cfg.requireWeaponOn and not isWeaponOn then return end

            local now = os.clock()
            if now - lastHitAt < cfg.saCooldown then return end

            local hit_info = sdk.to_managed_object(args[3])
            if not hit_info then return end

            -- DamageOwner = who receives the damage. Must be our player.
            local dmg_owner_ok, damage_owner = pcall(function()
                return hit_info:get_field("<DamageOwner>k__BackingField")
            end)
            if not dmg_owner_ok or not damage_owner then return end
            local name_ok, dname = pcall(function() return damage_owner:get_Name() end)
            if not name_ok or dname ~= "MasterPlayer" then return end

            -- AttackOwner must be an enemy (not an ally or env hazard).
            local atk_owner_ok, attack_owner = pcall(function()
                return hit_info:get_field("<AttackOwner>k__BackingField")
            end)
            if not atk_owner_ok or not attack_owner then return end
            local tag_ok, tag = pcall(function() return attack_owner:get_Tag() end)
            if not tag_ok or not tag or not tag:find("Enemy") then return end

            -- Must be a real damaging hit (not zero-damage triggers).
            local atkdata_ok, attack_data = pcall(function()
                return hit_info:get_field("<AttackData>k__BackingField")
            end)
            if not atkdata_ok or not attack_data then return end
            local atk_ok, atk_val = pcall(function() return attack_data:get_field("_Attack") end)
            if not atk_ok or not atk_val or atk_val <= 0 then return end

            lastHitAt = now

            -- Set CollisionLayer=18 (PARRY) and inject parry damage so the game applies
            -- counter damage to the enemy. _ParryDamage=150 axe / 600 sword (vanilla values).
            pcall(function()
                hit_info:set_field("<CollisionLayer>k__BackingField", 18)
                local apl = sdk.create_instance("app.cAttackParamPl", true)
                hit_info:set_DamageAttackData(apl)
                local dad = hit_info:get_field("<DamageAttackData>k__BackingField")
                dad:set_field("_HitEffectType", 18)
                dad:set_field("_ParryDamage", saIsSwordMode and 600 or 150)
                dad:set_field("_HitEffectOverwriteConnectID", -1)
            end)

            -- Protect player during the counter animation.
            pcall(function() character:call("startNoHitTimer(System.Single)", 0.4) end)

            -- Queue counter animation on the player.
            if saIsSwordMode then
                triggerAction(2, 54)  -- counter stance
                triggerAction(2, 31)  -- sword counter start → game upgrades to Cat=2 Idx=32
            else
                triggerAction(2, 5)   -- axe offset start → game upgrades to Cat=2 Idx=8
            end
        end,
        function(retval) return retval end
    )
    log.info('[MHW_AutoDodge] SA evHit_AttackPreProcess hooked OK')
else
    log.warn('[MHW_AutoDodge] SA evHit_AttackPreProcess not found — SA inactive.')
end


-- UI
local showWindow = false

local function weaponName()
    if     weaponType == SNS then return 'SnS'
    elseif weaponType == CB  then return 'CB'
    elseif weaponType == DB  then return 'DB'
    elseif weaponType == SA  then return 'SA'
    elseif weaponType == BOW then return 'Bow'
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
        cfg.snsCooldown = cfg.universalCooldown
        cfg.dbCooldown  = cfg.universalCooldown
        cfg.cbCooldown  = cfg.universalCooldown
        cfg.saCooldown  = cfg.universalCooldown
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
    imgui.text('Auto Perfect Guard / Offset  (HBG)')
    imgui.indent(16)
    c, cfg.guardEnabled = imgui.checkbox('Active##guard', cfg.guardEnabled)
    changed = changed or c
    imgui.begin_disabled(not cfg.guardEnabled)
    c, cfg.hbgOffset = imgui.checkbox('Offset (unchecked = Perfect Guard)##hbg', cfg.hbgOffset)
    changed = changed or c
    c, cfg.hbgCooldown = imgui.slider_float('Cooldown (s)##hbg', cfg.hbgCooldown, 0.05, 2.0)
    changed = changed or c
    imgui.end_disabled()
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

    imgui.spacing()

    -- SnS
    imgui.text('Auto Guard / Dodge  (SnS)')
    imgui.indent(16)
    c, cfg.snsEnabled = imgui.checkbox('Active##sns', cfg.snsEnabled)
    changed = changed or c
    imgui.begin_disabled(not cfg.snsEnabled)
    c, cfg.snsGuard = imgui.checkbox('Perfect Guard (unchecked = Dodge)##sns', cfg.snsGuard)
    changed = changed or c
    c, cfg.snsCooldown = imgui.slider_float('Cooldown (s)##sns', cfg.snsCooldown, 0.05, 2.0)
    changed = changed or c
    imgui.end_disabled()
    imgui.unindent(16)

    imgui.spacing()

    -- DB
    imgui.text('Auto Dodge / Perfect Dodge in Demon Mode  (Dual Blades)')
    imgui.indent(16)
    c, cfg.dbEnabled = imgui.checkbox('Active##db', cfg.dbEnabled)
    changed = changed or c
    c, cfg.dbCooldown = imgui.slider_float('Cooldown (s)##db', cfg.dbCooldown, 0.05, 2.0)
    changed = changed or c
    imgui.unindent(16)

    imgui.spacing()

    -- CB
    imgui.text('Auto Guard / Dodge  (Charge Blade)')
    imgui.indent(16)
    c, cfg.cbEnabled = imgui.checkbox('Active##cb', cfg.cbEnabled)
    changed = changed or c
    imgui.begin_disabled(not cfg.cbEnabled)
    c, cfg.cbGuard = imgui.checkbox('Perfect Guard (unchecked = Dodge)##cb', cfg.cbGuard)
    changed = changed or c
    c, cfg.cbCooldown = imgui.slider_float('Cooldown (s)##cb', cfg.cbCooldown, 0.05, 2.0)
    changed = changed or c
    imgui.end_disabled()
    imgui.unindent(16)

    imgui.spacing()

    -- SA
    imgui.text('Auto Counter / Offset  (Switch Axe)')
    imgui.indent(16)
    c, cfg.saEnabled = imgui.checkbox('Active##sa', cfg.saEnabled)
    changed = changed or c
    c, cfg.saCooldown = imgui.slider_float('Cooldown (s)##sa', cfg.saCooldown, 0.05, 2.0)
    changed = changed or c
    if weaponType == SA then
        imgui.text_colored(
            saIsSwordMode and 'Mode: Sword  (Counter)' or 'Mode: Axe  (Offset)',
            saIsSwordMode and 0xFF44FF44 or 0xFF4488FF)
        local liveMode = -1
        if character then pcall(function()
            local wh = character:call("get_WeaponHandling")
            if wh then liveMode = wh:get_field("_Mode") or -1 end
        end) end
        imgui.text_colored(string.format('cHunterWp08Handling._Mode: %d  (0=axe 1=sword)', liveMode), 0xFF888888)
    end
    imgui.unindent(16)

    imgui.end_disabled()

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    c, cfg.requireWeaponOn = imgui.checkbox('Only trigger with weapon drawn (uncheck = works sheathed too)', cfg.requireWeaponOn)
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
