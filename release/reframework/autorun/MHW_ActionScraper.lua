-- MHW_ActionScraper.lua
-- Dumps methods relevant to the MHR AutoDodge pattern adapted for Wilds.
-- We need:
--   1. A damage CHECK method (equivalent to snow.player.PlayerQuestBase:checkCalcDamage_DamageSide)
--   2. BehaviorTree access + setCurrentNode
--   3. ActStatus / action status tags
-- Check reframework/log.txt after loading.

local P = "[Scraper] "

local DAMAGE_KEYWORDS = {
    "damage", "calc", "check", "receive", "hit", "hurt",
    "damageside", "damagecalc", "questbase",
}

local BEHAVIOR_KEYWORDS = {
    "behavior", "behaviortree", "setcurrent", "setnode",
    "currentnode", "nodeid", "tree",
}

local STATUS_KEYWORDS = {
    "actstatus", "actionstatus", "statusTag", "isaction",
    "isstate", "dodge", "escape", "guard", "jump",
}

local function hasAny(name, keywords)
    local lower = name:lower()
    for _, kw in ipairs(keywords) do
        if lower:find(kw, 1, true) then return true end
    end
    return false
end

local function dumpType(typeName, keywords, label)
    local td = sdk.find_type_definition(typeName)
    if not td then
        log.info(P .. "TYPE NOT FOUND: " .. typeName)
        return
    end
    log.info(P .. "=== " .. label .. " [" .. typeName .. "] ===")
    for _, m in ipairs(td:get_methods()) do
        local name = m:get_name()
        if hasAny(name, keywords) then
            log.info(P .. "  METHOD: " .. name)
        end
    end
    for _, f in ipairs(td:get_fields()) do
        local name = f:get_name()
        if hasAny(name, keywords) then
            log.info(P .. "  FIELD:  " .. name)
        end
    end
end

-- Classes to search for damage check equivalent
local damageClasses = {
    "app.HunterCharacter",
    "app.PlayerQuestBase",
    "app.PlayerBase",
    "app.CharacterBase",
    "app.DamageCalculator",
    "app.HitManager",
    "app.AttackManager",
    "app.DamageManager",
}

-- Classes to search for behavior tree
local behaviorClasses = {
    "app.HunterCharacter",
    "app.PlayerBase",
    "via.behaviortree.BehaviorTree",
    "via.behaviortree.BehaviorTreeCoreController",
}

-- Classes to search for ActStatus equivalent
local statusClasses = {
    "app.HunterCharacter",
    "app.PlayerBase",
    "app.ActStatus",
    "app.player.ActStatus",
}

log.info(P .. "========== DAMAGE CHECK METHODS ==========")
for _, cls in ipairs(damageClasses) do
    dumpType(cls, DAMAGE_KEYWORDS, "DAMAGE")
end

log.info(P .. "========== BEHAVIOR TREE METHODS ==========")
for _, cls in ipairs(behaviorClasses) do
    dumpType(cls, BEHAVIOR_KEYWORDS, "BEHAVIOR")
end

log.info(P .. "========== ACT STATUS METHODS ==========")
for _, cls in ipairs(statusClasses) do
    dumpType(cls, STATUS_KEYWORDS, "STATUS")
end

-- Also try to find checkCalcDamage_DamageSide directly by brute-force type search
log.info(P .. "========== BRUTE FORCE: searching all app.* types for checkCalcDamage ==========")
local function tryFindMethod(typeName)
    local td = sdk.find_type_definition(typeName)
    if not td then return end
    for _, m in ipairs(td:get_methods()) do
        local name = m:get_name():lower()
        if name:find("calcdamage") or name:find("damageside") or name:find("checkdamage") then
            log.info(P .. "FOUND in " .. typeName .. ": " .. m:get_name())
        end
    end
end

local playerTypes = {
    "app.HunterCharacter", "app.PlayerQuestBase", "app.PlayerBase",
    "app.CharacterBase", "app.PlayerManager", "app.QuestManager",
    "app.DamageReceiverBase", "app.DamageReceiver", "app.DamageController",
    "app.HitReceiver", "app.HitController", "app.player.PlayerQuestBase",
}
for _, t in ipairs(playerTypes) do tryFindMethod(t) end

log.info(P .. "========== DONE — open reframework/log.txt ==========")

-- ── Runtime: find behavior tree on character ───────────────────────────────

local character = nil

re.on_pre_application_entry('BeginRendering', function()
    pcall(function()
        local pm = sdk.get_managed_singleton('app.PlayerManager')
        if not pm then return end
        local mp = pm:getMasterPlayer()
        if not mp then return end
        character = mp:get_Character()
    end)
end)

re.on_draw_ui(function()
    if not imgui.tree_node("Action Scraper — BehaviorTree Finder") then return end

    if character and imgui.button("Dump character component list to log") then
        pcall(function()
            local go = character:call("get_GameObject")
            if not go then log.info(P .. "No GameObject"); return end

            -- Try to get BehaviorTree component
            local bt = go:call("getComponent(System.Type)", sdk.typeof("via.behaviortree.BehaviorTree"))
            if bt then
                log.info(P .. "BehaviorTree FOUND: " .. tostring(bt))
                -- Try setCurrentNode
                local td = sdk.find_type_definition("via.behaviortree.BehaviorTree")
                if td then
                    for _, m in ipairs(td:get_methods()) do
                        local name = m:get_name()
                        if name:lower():find("node") or name:lower():find("current") then
                            log.info(P .. "  BT METHOD: " .. name)
                        end
                    end
                end
            else
                log.info(P .. "BehaviorTree component NOT found via getComponent")
            end

            -- Try motion FSM2 (used in MHR)
            local fsm = go:call("getComponent(System.Type)", sdk.typeof("via.motion.MotionFsm2"))
            if fsm then
                log.info(P .. "MotionFsm2 FOUND")
                local td = sdk.find_type_definition("via.motion.MotionFsm2")
                if td then
                    for _, m in ipairs(td:get_methods()) do
                        local name = m:get_name()
                        if name:lower():find("node") or name:lower():find("current") or name:lower():find("id") then
                            log.info(P .. "  FSM METHOD: " .. name)
                        end
                    end
                end
            else
                log.info(P .. "MotionFsm2 NOT found")
            end
        end)
    end

    imgui.text_colored("Open reframework/log.txt and search:", 0xFFFFAA00)
    imgui.text("  FOUND in   -> damage check method location")
    imgui.text("  BT METHOD  -> behavior tree node setter")
    imgui.text("  FSM METHOD -> motion FSM node ID getter")

    imgui.tree_pop()
end)
