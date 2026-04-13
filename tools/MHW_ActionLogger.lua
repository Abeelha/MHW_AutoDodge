-- MHW_ActionLogger.lua
-- Real-time action ID watcher for BaseActionController and SubActionController.
-- Manually perform actions (dodge, perfect dodge, guard) to discover their Cat/Idx.
-- IDs show live in the REFramework UI and are logged to re2_framework_log.txt.
--
-- HOW TO USE:
--   1. Copy this file to reframework/autorun/
--   2. Load a hunt
--   3. Perform actions manually (dodge, guard, counter, etc.)
--   4. Watch the history list — each unique Cat/Idx change is logged
--   5. Use discovered IDs in MHW_AutoDodge.lua
--   6. Remove from autorun when done (has per-frame overhead)

local character = nil
local lastBase  = ""
local lastSub   = ""
local uiBase    = "?"
local uiSub     = "?"

local MAX_HISTORY = 30
local history = {}

local function addHistory(ctrl, cat, idx)
    table.insert(history, 1, string.format("[%s] %s  Cat=%d  Idx=%d",
        os.date("%H:%M:%S"), ctrl, cat, idx))
    if #history > MAX_HISTORY then
        table.remove(history, #history)
    end
end

re.on_pre_application_entry('BeginRendering', function()
    pcall(function()
        local pm = sdk.get_managed_singleton('app.PlayerManager')
        if not pm then return end
        local mp = pm:getMasterPlayer()
        if not mp then return end
        character = mp:get_Character()
    end)
    if not character then return end

    pcall(function()
        local ctrl = character:call("get_BaseActionController")
        if not ctrl then return end
        local id = ctrl:call("get_CurrentActionID")
        if not id then return end
        local cat = id:get_field("_Category")
        local idx = id:get_field("_Index")
        uiBase = string.format("Cat=%d  Idx=%d", cat, idx)
        local key = cat .. "_" .. idx
        if key ~= lastBase then
            lastBase = key
            log.info(string.format('[ActionLog] BASE  Cat=%d  Idx=%d', cat, idx))
            addHistory("BASE", cat, idx)
        end
    end)

    pcall(function()
        local ctrl = character:call("get_SubActionController")
        if not ctrl then return end
        local id = ctrl:call("get_CurrentActionID")
        if not id then return end
        local cat = id:get_field("_Category")
        local idx = id:get_field("_Index")
        uiSub = string.format("Cat=%d  Idx=%d", cat, idx)
        local key = cat .. "_" .. idx
        if key ~= lastSub then
            lastSub = key
            log.info(string.format('[ActionLog] SUB   Cat=%d  Idx=%d', cat, idx))
            addHistory("SUB ", cat, idx)
        end
    end)
end)

re.on_draw_ui(function()
    if not imgui.tree_node('[ActionLog] Action ID Logger') then return end

    if character then
        imgui.text('Current:')
        imgui.indent(16)
        imgui.text('Base: ') imgui.same_line() imgui.text_colored(uiBase, 0xFFFFFF44)
        imgui.text('Sub:  ') imgui.same_line() imgui.text_colored(uiSub,  0xFF44FFFF)
        imgui.unindent(16)

        imgui.spacing()
        imgui.text_colored('-> Perform actions manually and watch Base/Sub change', 0xFFFF8844)
        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        imgui.text(string.format('History (last %d changes):', #history))
        imgui.spacing()
        for _, entry in ipairs(history) do
            local col = entry:find("SUB") and 0xFF44FFFF or 0xFFFFFF44
            imgui.text_colored(entry, col)
        end

        imgui.spacing()
        if imgui.button('Clear history') then
            history = {}
        end
    else
        imgui.text_colored('No character — load a hunt first', 0xFFAAAAFF)
    end

    imgui.tree_pop()
end)
