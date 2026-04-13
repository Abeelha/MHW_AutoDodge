-- MHW_MountDebugger.lua
-- Identifies the correct "is mounted" flag for MHW_AutoDodge.
--
-- HOW TO USE:
--   1. Copy this file to reframework/autorun/
--   2. Load a hunt, open REFramework UI -> [MountDebug]
--   3. Mount your Seikret, watch which entries flip GREEN
--   4. That's your flag — add it to MHW_AutoDodge.lua
--   5. Remove from autorun when done

local character    = nil
local masterPlayer = nil
local probeResults = {}

-- Methods that return objects: nil = not mounted, non-nil = mounted
local OBJECT_PROBES = {
    "get_RiderMotionCtrl",
    "get_RiderCommand",
    "get_RiderPostureInfo",
    "get_SecondaryRiderConstraint",
}

-- Methods that might return bool/int directly
local VALUE_PROBES = {
    "get_IsRiding",
    "get_IsMounted",
    "get_IsRidingSeikret",
    "isRiding",
    "isMounted",
    "get_RideState",
    "get_RidingState",
    "checkAfterWarpNoRide",
}

re.on_pre_application_entry('BeginRendering', function()
    pcall(function()
        local pm = sdk.get_managed_singleton('app.PlayerManager')
        if not pm then return end
        local mp = pm:getMasterPlayer()
        if not mp then return end
        masterPlayer = mp
        character    = mp:get_Character()
    end)

    if not character then return end

    probeResults = {}

    -- Object probes: non-nil = likely mounted
    for _, m in ipairs(OBJECT_PROBES) do
        local ok, val = pcall(function() return character:call(m) end)
        if ok then
            local isMounted = (val ~= nil)
            table.insert(probeResults, {
                label    = m,
                raw      = tostring(val),
                active   = isMounted,
                callable = true,
            })
        else
            table.insert(probeResults, {
                label    = m,
                raw      = "ERROR",
                active   = false,
                callable = false,
            })
        end
    end

    -- Value probes: true/non-zero = mounted
    for _, m in ipairs(VALUE_PROBES) do
        local ok, val = pcall(function() return character:call(m) end)
        if ok and val ~= nil then
            local active = (val == true or (type(val) == "number" and val ~= 0))
            table.insert(probeResults, {
                label    = m,
                raw      = tostring(val),
                active   = active,
                callable = true,
            })
        else
            table.insert(probeResults, {
                label    = m,
                raw      = ok and "nil/error" or "no such method",
                active   = false,
                callable = false,
            })
        end
    end
end)

re.on_draw_ui(function()
    if not imgui.tree_node('[MountDebug] Mount State Finder') then return end

    if not character then
        imgui.text_colored('No character — load a hunt first', 0xFFAAAAFF)
        imgui.tree_pop()
        return
    end

    imgui.text_colored('Mount your Seikret then watch which line turns GREEN', 0xFFFFFF44)
    imgui.text_colored('GREEN = likely the correct mount flag', 0xFF44FF44)
    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    imgui.text('Object probes (non-nil = mounted?):')
    imgui.indent(16)
    for _, r in ipairs(probeResults) do
        if not r.callable then goto continue end
        -- only show object probes first
        local is_obj_probe = false
        for _, m in ipairs(OBJECT_PROBES) do
            if r.label == m then is_obj_probe = true break end
        end
        if not is_obj_probe then goto continue end

        local col = r.active and 0xFF44FF44 or 0xFF666666
        imgui.text_colored(string.format('%-40s  =  %s', r.label, r.raw), col)
        ::continue::
    end
    imgui.unindent(16)

    imgui.spacing()
    imgui.text('Value probes (true/non-zero = mounted?):')
    imgui.indent(16)
    for _, r in ipairs(probeResults) do
        local is_val_probe = false
        for _, m in ipairs(VALUE_PROBES) do
            if r.label == m then is_val_probe = true break end
        end
        if not is_val_probe then goto continue end

        local col
        if not r.callable then
            col = 0xFF444444
        elseif r.active then
            col = 0xFF44FF44
        else
            col = 0xFF666666
        end
        imgui.text_colored(string.format('%-40s  =  %s', r.label, r.raw), col)
        ::continue::
    end
    imgui.unindent(16)

    imgui.spacing()
    imgui.separator()
    imgui.spacing()
    imgui.text_colored('From existing logs, candidates are:', 0xFFAAAAAA)
    imgui.text_colored('  get_RiderMotionCtrl   (returns object, nil when not mounted)', 0xFFAAAAAA)
    imgui.text_colored('  get_RiderCommand       (returns object, nil when not mounted)', 0xFFAAAAAA)

    imgui.tree_pop()
end)
