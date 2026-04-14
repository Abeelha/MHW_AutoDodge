-- config
-- Credits to Actri
local function merge_tables(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k] or false) == "table" then
            merge_tables(t1[k], v)
        else
            t1[k] = v
        end
    end
end

local saved_config = json.load_file("sa_offsets.json") or {}

local config = {
    mod_enabled = true,

    offsets = {
        sa_morph_offset = {
            enabled = true,  
        },
		sa_zerosum_finisher_offset = {
			enabled = true,
		},
        sa_zerosum_offset = {
            enabled = true,  
        },
		sa_sword_offset = {
			enabled = true,
		},
        sa_fade_offset = {
            enabled = true,  
        },
        sa_spiral_offset = {
            enabled = true,  
        },
		sa_vanilla_offset = {
			enabled = true,
		},
    },
    Rocksteady = {
		sa_morph_offset_start = 14, --Original = 14
		sa_morph_offset = 30, --Original = 30
		sa_spiral_offset_start = 70, --Original = 70
		sa_spiral_offset = 90, --Original = 90
        sa_zerosum_offset_start = 0, --Original = 0
        sa_zerosum_offset = 20, -- Original = 20
		sa_zerosum_finisher_offset_start = 0, --Original 0
		sa_zerosum_finisher_offset = 20, -- Original 20
		sa_sword_offset_start = 65, --Original = 65
		sa_sword_offset = 81, --Original = 81
		sa_fade_offset_start = 25, -- Original = 25
		sa_fade_offset = 37, -- Original = 37
		sa_vanilla_offset_start = 48, --Original = 48
		sa_vanilla_offset = 68, --Original = 68

    },
    parry = {
		sa_morph_offset_start = 14, --Original = 14
		sa_morph_offset = 30, --Original = 30
		sa_spiral_offset_start = 70, --Original = 70
		sa_spiral_offset = 90, --Original = 90
        sa_zerosum_offset_start = 0, --Original = 73
        sa_zerosum_offset = 20, --Original = 90
		sa_zerosum_finisher_offset_start = 0, --Original 0
		sa_zerosum_finisher_offset = 20, -- Original 20
		sa_sword_offset_start = 65, --Original value = 65
		sa_sword_offset = 81, -- Original = 81
		sa_fade_offset_start = 25, -- Original = 25
		sa_fade_offset = 37, -- Original = 37
        parry_all_attacks = false,
    },
	parry_damage = {
		sa_morph_offset = 200, --Original = 200
		sa_spiral_offset = 200, --Original = 200
		sa_zerosum_offset = 200, --Original = 200
		sa_zerosum_finisher_offset = 2000, --Original = 2000
		sa_sword_offset = 600, --Original = 600
		sa_fade_offset = 30, -- Original = 30
		sa_vanilla_offset = 150, --Original = 150
	},

}

merge_tables(config, saved_config)

re.on_config_save(
    function()
        json.dump_file("sa_offsets.json", config)
    end
)

local last_parry_frame = -1

local function get_hunter()
    local player_manager = sdk.get_managed_singleton("app.PlayerManager")
    if not player_manager then return nil end
    local player_info = player_manager:getMasterPlayer()
    if not player_info then return nil end
    local hunter_character = player_info:get_Character()
    return hunter_character
end

local function get_action()
    local hunter = get_hunter()
    local action_controller     = hunter:get_BaseActionController()
    if not action_controller then return nil end
    local action_id = action_controller:get_CurrentActionID()
    if not action_id then return nil end
    local action_id_type = sdk.find_type_definition("ace.ACTION_ID")
    return {
        Index = sdk.get_native_field(action_id, action_id_type, "_Index"),
        Category = sdk.get_native_field(action_id, action_id_type, "_Category"),
    }
end

	local function get_wp_type()
		local hunter = get_hunter()
		if not hunter then return nil end
		return hunter:get_WeaponType()
	end

re.on_frame(function()
    local wp_type = get_wp_type()
end)


local function get_wp()
    local hunter = get_hunter()
    if not hunter then return nil end
    local wp = hunter:get_WeaponHandling()
    return wp
end

local function change_action(layer, category, index)
    local hunter = get_hunter()
    if not hunter then return end
    local ActionIDType = sdk.find_type_definition("ace.ACTION_ID")
    local instance = ValueType.new(ActionIDType)
    sdk.set_native_field(instance, ActionIDType, "_Category", category)
    sdk.set_native_field(instance, ActionIDType, "_Index", index)
    hunter:call("changeActionRequest(app.AppActionDef.LAYER, ace.ACTION_ID, System.Boolean)", layer, instance, true)
    if category and index and (category ~= last_category or index ~= last_index) then
        log.info("[Action Info] Category: " .. tostring(category) .. " | Index: " .. tostring(index))
        last_category = category
        last_index = index
    end
end

local function get_motion_frame() -- credits to lingsamuel
    local player_manager = sdk.get_managed_singleton("app.PlayerManager")
    local player_info = player_manager:getMasterPlayer()
    if not player_info then return 0 end
    local player_object = player_info:get_Object()
    if not player_object then return 0 end
    local motion = player_object:getComponent(sdk.typeof("via.motion.Motion"))
    if not motion then return 0 end
    local layer = motion:getLayer(0)
    if not layer then return 0 end
    local frame = layer:get_Frame()
    return frame
end

local function get_motion(layer_id) -- credits to lingsamuel
    layer_id = layer_id or 0
    local player_manager = sdk.get_managed_singleton("app.PlayerManager")
    local player_info = player_manager:getMasterPlayer()
    if not player_info then return 0 end
    local player_object = player_info:get_Object()
    if not player_object then return 0 end
    local motion = player_object:getComponent(sdk.typeof("via.motion.Motion"))
    if not motion then return 0 end
    local layer = motion:getLayer(layer_id)
    if not layer then return 0 end

    local nodeCount = layer:getMotionNodeCount()
    local result = {
        Layer = layer,
        LayerID = layer_id,
        MotionID = layer:get_MotionID(),
        MotionBankID = layer:get_MotionBankID(),
        Frame = layer:get_Frame(),
    }

    return result
end

local function get_sub_motion()
    return get_motion(3)
end

local function get_config(motion_name, function_name) 
    local start_frame = config[function_name][motion_name .. "_start"]
    local end_frame = config[function_name][motion_name]
    return start_frame, end_frame
end

function contains_token(haystack, needle)
    local needle_lower = needle:lower()
    for token in string.gmatch(haystack, "[^|]+") do
        if token:lower() == needle_lower then
            return true
        end
    end
    return false
end

local motion_max_frames = {
	sa_morph_offset = 300,
	sa_spiral_offset = 300,
    sa_zerosum_offset = 300,
	sa_zerosum_finisher_offset = 300,
	sa_sword_offset = 300,
	sa_fade_offset = 300,
	sa_vanilla_offset = 300,
}

local in_motion = {
	sa_morph_offset = false,
	sa_spiral_offset = false,
    sa_zerosum_offset = false,
	sa_zerosum_finisher_offset = false,
    sa_sword_offset = false,
	sa_fade_offset = false,
	sa_vanilla_offset = false,
}

local on_vanilla_parry = false
local on_mod_parry = false

local function in_window(function_name)
for motion_name, in_motion_value in pairs(in_motion) do
    if in_motion_value 
       and (config.offsets[motion_name] == nil or config.offsets[motion_name].enabled)
    then
            local start_frame, end_frame = get_config(motion_name, function_name)
            local frame = nil
                frame = get_motion_frame()
            return frame > start_frame and frame < end_frame
        end
    end
end

local function get_current_motion()
    for motion_name, is_active in pairs(in_motion) do
        if is_active then
            return motion_name
        end
    end
    return nil
end


re.on_frame(function()
    local action = get_action()
    if not action then return end

    local target_category = 2
    local target_index = 18

    if action.Category == target_category and action.Index == target_index and get_wp_type() == 8 then
        in_motion.sa_morph_offset = true
    else
        in_motion.sa_morph_offset = false
    end
end)

re.on_frame(function()
    local action = get_action()
    if not action then return end

    local target_category = 2
    local target_index = 39

    if action.Category == target_category and action.Index == target_index and get_wp_type() == 8 then
        in_motion.sa_zerosum_offset = true
    else
        in_motion.sa_zerosum_offset = false
    end
end)

re.on_frame(function()
    local action = get_action()
    if not action then return end
	
    local target_category = 2
    local target_index = 38

    if action.Category == target_category and action.Index == target_index and get_wp_type() == 8 then
        in_motion.sa_zerosum_finisher_offset = true
    else
        in_motion.sa_zerosum_finisher_offset = false
    end
end)

re.on_frame(function()
    local action = get_action()
    if not action then return end

    local target_category = 2
    local target_index = 30

    if action.Category == target_category and action.Index == target_index and get_wp_type() == 8 then
        in_motion.sa_sword_offset = true
    else
        in_motion.sa_sword_offset = false
    end
end)

re.on_frame(function()
    local motion = get_motion()
    if not motion then return end

    local target_motion_id = 372    
    local target_motion_bank_id = 20  

    if motion.MotionID == target_motion_id and motion.MotionBankID == target_motion_bank_id and get_wp_type() == 8 then
        in_motion.sa_spiral_offset = true
    else
        in_motion.sa_spiral_offset = false
    end
end)

re.on_frame(function()
    local action = get_action()
    if not action then return end

    local target_category = 2
    local target_index = 14

    if action.Category == target_category and action.Index == target_index and get_wp_type() == 8 then
        in_motion.sa_fade_offset = true
    else
        in_motion.sa_fade_offset = false
    end
end)

re.on_frame(function()
    local action = get_action()
    if not action then return end

    local target_category = 2
    local target_index = 5

    if action.Category == target_category and action.Index == target_index and get_wp_type() == 8 then
        in_motion.sa_vanilla_offset = true
    else
        in_motion.sa_vanilla_offset = false
    end
end)



sdk.hook(sdk.find_type_definition("app.HunterCharacter"):get_method("evHit_Damage(app.HitInfo)"),
function(args)
    local this = sdk.to_managed_object(args[2])
    if not this then return end
    if not (this:get_IsMaster() and this:get_IsUserControl()) then return end

    local hit_info = sdk.to_managed_object(args[3])
    if not hit_info then return end

    local attack_owner = hit_info:get_field("<AttackOwner>k__BackingField")
    if not attack_owner then return end
    local attack_owner_tag = attack_owner:get_Tag()

    local attack_data = hit_info:get_field("<AttackData>k__BackingField")
    local attack_value = attack_data:get_field("_Attack")
    local heal_value = attack_data:get_field("_HealValue")

if contains_token(attack_owner_tag, "Enemy") and attack_value > 0 then
    local force_step = false

    if on_mod_parry and in_motion.sa_zerosum_finisher_offset then
        force_step = false --Turn these to true if you want that offset to have a followup attack.
    end
	if on_mod_parry and in_motion.sa_zerosum_offset then
		force_step = false
	end
	if on_mod_parry and in_motion.sa_fade_offset then
		force_step = false
	end
	if on_mod_parry and in_motion.sa_sword_offset then
		force_step = false
	end
	if on_mod_parry and in_motion.sa_vanilla_offset then
		force_step = false
	end
	
    if force_step then
    -- Clean up state
    in_motion.sa_zerosum_finisher_offset = false
    in_motion.sa_zerosum_offset = false
	in_motion.sa_sword_offset = false
	in_motion.sa_fade_offset = false
	in_motion.sa_vanilla_offset = false
    on_mod_parry = false

    change_action (0, 2, 27) -- (CATEGORY, INDEX)
    return sdk.PreHookResult.SKIP_ORIGINAL
end
end
	
end)


-- Parry
-- Credits to Actri	

-------------------------------------------------
-- 🔹 Safe Prefab Cache System (no player reload)
-------------------------------------------------

local function get_effect()
    local player_manager = sdk.get_managed_singleton("app.PlayerManager")
    local player_info = player_manager:getMasterPlayer()
    if not player_info then return 0 end
    local player_object = player_info:get_Object()
    return player_object:getComponent(sdk.typeof("via.effect.script.ObjectEffectManager2"))
end

local function get_prefab(wp_type)
    local player_manager = sdk.get_managed_singleton("app.PlayerManager")
    local catalog = player_manager:get_Catalog()
    if not catalog then return nil end
    local wp_assets = catalog:getWeaponEquipUseAssets(wp_type)
    if not wp_assets then return nil end
    return wp_assets:get_EpvRef()
end

local EFFECT_WP_TYPE = 0 -- Greatsword
local effect_override_types = {
	[0] = true, -- Greatsword
    [1] = true, -- Sword and Shield
    [2] = true, -- Dual Blades
    [3] = true, -- Long Sword
    [6] = true, -- Lance
    [7] = true, -- Gunlance
    [9] = true, -- Charge Blade
    [11] = true, -- Bow
    [12] = true, -- Heavy Bowgun
    [13] = true, -- Light Bowgun
}

local prefab_cache = nil
local should_restore_effect = false

-- safe init: grab IG prefab directly from the catalog (no reload, no set_WpType)
local function init_prefab_cache()
    if prefab_cache then return end

    local player_manager = sdk.get_managed_singleton("app.PlayerManager")
    if not player_manager then
        log.info("[revamp] init_prefab_cache: no PlayerManager")
        return
    end

    local catalog = player_manager:get_Catalog()
    if not catalog then
        log.info("[revamp] init_prefab_cache: no Catalog")
        return
    end

    local wp_assets = catalog:getWeaponEquipUseAssets(EFFECT_WP_TYPE) -- IG assets
    if not wp_assets then
        log.info("[revamp] init_prefab_cache: no WeaponEquipUseAssets for IG")
        return
    end

    local epvref = wp_assets:get_EpvRef()
    if not epvref then
        log.info("[revamp] init_prefab_cache: get_EpvRef() returned nil")
        return
    end

    prefab_cache = epvref
    prefab_cache:add_ref_permanent()
    log.info("[revamp] init_prefab_cache: cached prefab for WP_TYPE " .. tostring(EFFECT_WP_TYPE) .. " (epvref: " .. string.format("%x", prefab_cache:get_address()) .. ")")
end

-- Try to initialize the prefab cache every frame until successful (safe - no reload)
re.on_frame(function()
    if not config.mod_enabled then return end
    if not prefab_cache then
        init_prefab_cache()
    end
end)

sdk.hook(
    sdk.find_type_definition("app.EnemyCharacter"):get_method("evHit_AttackPreProcess(app.HitInfo)"),
    function(args)
        if not config.mod_enabled then return end
        local hit_info = sdk.to_managed_object(args[3])
        if not hit_info then return end
        local damage_owner = hit_info:get_field("<DamageOwner>k__BackingField")
        if not damage_owner or damage_owner:get_Name() ~= "MasterPlayer" then return end

        local attack_owner = hit_info:get_field("<AttackOwner>k__BackingField")
        if not attack_owner then return end
        local attack_owner_tag = attack_owner:get_Tag()
        local attack_data = hit_info:get_field("<AttackData>k__BackingField")
        if not attack_data then return end
        local attack_value = attack_data:get_field("_Attack")
        if attack_value <= 0 or attack_owner_tag:find("Shell") then return end

        -- If within parry window
        if in_window("parry") then
            local current_frame = get_motion_frame()
            if current_frame == last_parry_frame then return end
            last_parry_frame = current_frame

            hit_info:set_field("<CollisionLayer>k__BackingField", 18) -- PARRY
            local attack_param_pl = sdk.create_instance("app.cAttackParamPl", true)
            hit_info:set_DamageAttackData(attack_param_pl)
            hit_info:get_field("<DamageAttackData>k__BackingField"):set_field("_HitEffectType", 18)

            local motion_name = get_current_motion()
            local parry_damage = config.parry_damage[motion_name]
            hit_info:get_field("<DamageAttackData>k__BackingField"):set_field("_ParryDamage", parry_damage)
            hit_info:get_field("<DamageAttackData>k__BackingField"):set_field("_HitEffectOverwriteConnectID", -1)
			on_mod_parry = true
            -- 🔹 Inject IG prefab so VFX plays
            local effect = get_effect()
            local wp_type = get_wp_type()
            if effect and effect_override_types[wp_type] then
                if prefab_cache then
                    log.info("[revamp] Parry triggered - injecting IG prefab to effect manager")
                    effect:requestSetDataContainer(prefab_cache, 0, EFFECT_WP_TYPE)
                    -- lateUpdate often ensures the effect manager picks up the new data immediately
                    pcall(function() effect:lateUpdate() end)
                    should_restore_effect = true
                else
                    log.info("[revamp] Parry triggered but prefab_cache is nil - VFX won't show")
                end
            end

-- And in the post-hook restore function (the return hook) keep this:
    if should_restore_effect then
        local effect = get_effect()
        local wp_type = get_wp_type()
        local current_prefab = get_prefab(wp_type)
        if effect and current_prefab then
            log.info("[revamp] Restoring weapon prefab to effect manager for wp_type " .. tostring(wp_type))
            pcall(function() effect:requestSetDataContainer(current_prefab, 0, wp_type) end)
        else
            log.info("[revamp] restore: effect or current_prefab nil (effect: " .. tostring(effect ~= nil) .. ", prefab: " .. tostring(current_prefab ~= nil) .. ")")
        end
        should_restore_effect = false
    end
        end
    end,
    function(retval)
        if should_restore_effect then
            local effect = get_effect()
            local wp_type = get_wp_type()
            local current_prefab = get_prefab(wp_type)
            if effect and current_prefab then
                effect:requestSetDataContainer(current_prefab, 0, wp_type)
            end
            should_restore_effect = false
        end
        return retval
    end
)

-- Parry
-- Credits to Actri	

sdk.hook(sdk.find_type_definition("app.EnemyCharacter"):get_method("evHit_AttackPreProcess(app.HitInfo)"),
function(args)
    if not config.mod_enabled then return end

    local hit_info = sdk.to_managed_object(args[3])
    if not hit_info then return end

    local damage_owner = hit_info:get_field("<DamageOwner>k__BackingField")
    local damage_owner_name = damage_owner:get_Name()
    if damage_owner_name ~= "MasterPlayer" then return end

    local attack_owner = hit_info:get_field("<AttackOwner>k__BackingField")
    if not attack_owner then return end

    local attack_owner_tag = attack_owner:get_Tag()
    local is_parry_able = not contains_token(attack_owner_tag, "Shell")

    local attack_data = hit_info:get_field("<AttackData>k__BackingField")
    local attack_value = attack_data:get_field("_Attack")
    is_parry_able = is_parry_able and attack_value > 0

    if not is_parry_able then return end

    local collision_layer = hit_info:get_field("<CollisionLayer>k__BackingField")
    on_vanilla_parry = collision_layer == 18

    if in_window("parry") then
        local current_frame = get_motion_frame()

        if current_frame == last_parry_frame then
            return
        end
        last_parry_frame = current_frame

        hit_info:set_field("<CollisionLayer>k__BackingField", 18)
        local attack_param_pl = sdk.create_instance("app.cAttackParamPl", true)
        hit_info:set_DamageAttackData(attack_param_pl)
        hit_info:get_field("<DamageAttackData>k__BackingField"):set_field("_HitEffectType", 18)

        local motion_name = get_current_motion()
        local parry_damage = config.parry_damage[motion_name]
        hit_info:get_field("<DamageAttackData>k__BackingField"):set_field("_ParryDamage", parry_damage)
        hit_info:get_field("<DamageAttackData>k__BackingField"):set_field("_HitEffectOverwriteConnectID", -1)

        on_mod_parry = true

        -- VFX override begins here
        local effect = get_effect()
        local wp_type = get_wp_type()
        if effect and prefab_cache then
            effect:requestSetDataContainer(prefab_cache, 0, EFFECT_WP_TYPE)
            effect:lateUpdate()
            should_restore_effect = true
        end
    end
end)


-- Gui
-- Credits to Actri

re.on_draw_ui(function()
    local changed, any_changed = false, false

    local two_rows = function(name, var1, var2, name1, name2, min, max)
        imgui.text(name)
        imgui.begin_table(name, 2)
        imgui.table_next_row()
        imgui.table_next_column()
        changed, var1 = imgui.drag_int(name1, var1, 1, min, max)
        imgui.table_next_column()
        changed, var2 = imgui.drag_int(name2, var2, 1, min, max)
        imgui.end_table()
        return changed, var1, var2
    end
	

    if imgui.tree_node("Switch Axe Offsets") then
		local changed
		changed, config.mod_enabled = imgui.checkbox("Toggle Mod", config.mod_enabled or false)
        if imgui.tree_node("Rocksteady") then
            imgui.text("Set the start and end frames to be Rocksteady during each action. Set end frame to 0 to disable.")
            changed, config.Rocksteady.sa_morph_offset_start, config.Rocksteady.sa_morph_offset = two_rows("Morph Sweep Offset", config.Rocksteady.sa_morph_offset_start, config.Rocksteady.sa_morph_offset, "Start", "End", 0, motion_max_frames.sa_morph_offset)
            changed, config.Rocksteady.sa_spiral_offset_offset_start, config.Rocksteady.sa_spiral_offset = two_rows("Spiral Burst Slash Offset", config.Rocksteady.sa_spiral_offset_start, config.Rocksteady.sa_spiral_offset, "Start", "End", 0, motion_max_frames.sa_spiral_offset)
            changed, config.Rocksteady.sa_zerosum_offset_start, config.Rocksteady.sa_zerosum_offset = two_rows("Zero Sum Discharge Early", config.Rocksteady.sa_zerosum_offset_start, config.Rocksteady.sa_zerosum_offset, "Start", "End", 0, motion_max_frames.sa_zerosum_offset)
            changed, config.Rocksteady.sa_zerosum_finisher_offset_start, config.Rocksteady.sa_zerosum_finisher_offset = two_rows("Zero Sum Discharge Finisher", config.Rocksteady.sa_zerosum_finisher_offset_start, config.Rocksteady.sa_zerosum_finisher_offset, "Start", "End", 0, motion_max_frames.sa_zerosum_finisher_offset)
            changed, config.Rocksteady.sa_sword_offset_start, config.Rocksteady.sa_sword_offset = two_rows("Heavenward Flurry Offset", config.Rocksteady.sa_sword_offset_start, config.Rocksteady.sa_sword_offset, "Start", "End", 0, motion_max_frames.sa_sword_offset)
            changed, config.Rocksteady.sa_fade_offset_start, config.Rocksteady.sa_fade_offset = two_rows("Fade Slash Offset", config.Rocksteady.sa_fade_offset_start, config.Rocksteady.sa_fade_offset, "Start", "End", 0, motion_max_frames.sa_fade_offset)
            changed, config.Rocksteady.sa_vanilla_offset_start, config.Rocksteady.sa_vanilla_offset = two_rows("Vanilla Offset", config.Rocksteady.sa_vanilla_offset_start, config.Rocksteady.sa_vanilla_offset, "Start", "End", 0, motion_max_frames.sa_vanilla_offset)
            imgui.tree_pop()
        end
        if imgui.tree_node("Parry") then
            imgui.text("Set the start and end frames to parry during each action. Set end frame to 0 to disable.")
            changed, config.parry.sa_morph_offset_start, config.parry.sa_morph_offset = two_rows("Morph Sweep Offset", config.parry.sa_morph_offset_start, config.parry.sa_morph_offset, "Start", "End", 0, motion_max_frames.sa_morph_offset)
            changed, config.parry.sa_spiral_offset_offset_start, config.parry.sa_spiral_offset = two_rows("Spiral Burst Slash Offset", config.parry.sa_spiral_offset_start, config.parry.sa_spiral_offset, "Start", "End", 0, motion_max_frames.sa_spiral_offset)
            changed, config.parry.sa_zerosum_offset_start, config.parry.sa_zerosum_offset = two_rows("Zero Sum Discharge Early", config.parry.sa_zerosum_offset_start, config.parry.sa_zerosum_offset, "Start", "End", 0, motion_max_frames.sa_zerosum_offset)
            changed, config.parry.sa_zerosum_finisher_offset_start, config.parry.sa_zerosum_finisher_offset = two_rows("Zero sum Discharge Finisher", config.parry.sa_zerosum_finisher_offset_start, config.parry.sa_zerosum_finisher_offset, "Start", "End", 0, motion_max_frames.sa_zerosum_finisher_offset)
            changed, config.parry.sa_sword_offset_start, config.parry.sa_sword_offset = two_rows("Heavenward Flurry Offset", config.parry.sa_sword_offset_start, config.parry.sa_sword_offset, "Start", "End", 0, motion_max_frames.sa_sword_offset)
            changed, config.parry.sa_fade_offset_start, config.parry.sa_fade_offset = two_rows("Fade Slash Offset", config.parry.sa_fade_offset_start, config.parry.sa_fade_offset, "Start", "End", 0, motion_max_frames.sa_fade_offset)
            changed, config.parry.sa_vanilla_offset_start, config.parry.sa_vanilla_offset = two_rows("Vanilla Offset", config.parry.sa_vanilla_offset_start, config.parry.sa_vanilla_offset_offset, "Start", "End", 0, motion_max_frames.sa_vanilla_offset)
            imgui.tree_pop()
        end
if imgui.tree_node("Offset Toggles") then
    for motion_name, data in pairs(config.offsets) do
        local changed
        changed, data.enabled = imgui.checkbox(motion_name, data.enabled)
    end
    imgui.tree_pop()
end
        imgui.tree_pop()
    end
end)