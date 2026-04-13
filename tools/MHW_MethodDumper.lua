-- MHW_MethodDumper.lua
-- Dumps all methods of key hunter character classes to the REFramework log.
-- Use this when adding support for a new weapon to find available API calls.
--
-- HOW TO USE:
--   1. Copy this file to reframework/autorun/
--   2. Load into a hunt — dump runs automatically on first frame
--   3. Open re2_framework_log.txt and search for relevant keywords:
--      dodge / evade / guard / perfect / sub / controller / action / ride / mount
--   4. Remove from autorun when done

local dumped = false
local character = nil

local TYPES = {
    'app.HunterCharacter',
    'app.HunterCharacterBase',
    'app.CharacterBase',
}

re.on_pre_application_entry('BeginRendering', function()
    pcall(function()
        local pm = sdk.get_managed_singleton('app.PlayerManager')
        if not pm then return end
        local mp = pm:getMasterPlayer()
        if not mp then return end
        character = mp:get_Character()
    end)

    if dumped or not character then return end
    dumped = true

    for _, typeName in ipairs(TYPES) do
        local td = sdk.find_type_definition(typeName)
        if not td then
            log.info('[Dumper] NOT FOUND: ' .. typeName)
        else
            local methods = td:get_methods()
            log.info(string.format('[Dumper] === %s  (%d methods) ===', typeName, #methods))
            for _, m in ipairs(methods) do
                pcall(function() log.info('[Dumper]   ' .. m:get_name()) end)
            end
        end
    end

    log.info('[Dumper] Done — check re2_framework_log.txt')
end)

re.on_draw_ui(function()
    if not imgui.tree_node('[Dumper] Method Dumper') then return end

    if dumped then
        imgui.text_colored('Dump complete — check re2_framework_log.txt', 0xFF44FF44)
        imgui.text('Search for: dodge / guard / ride / mount / action / controller')
    elseif character then
        imgui.text('Dumping...')
    else
        imgui.text_colored('No character — load a hunt first', 0xFFAAAAFF)
    end

    imgui.tree_pop()
end)
