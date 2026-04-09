-- MHW_MethodDumper.lua
-- Dumps ALL methods of key hunter character classes to the REFramework log.
-- Use this when adding support for a new weapon to find available API calls.
--
-- HOW TO USE:
--   1. Copy this file to reframework/autorun/
--   2. Load into a hunt — dump runs automatically on first frame
--   3. Open re2_framework_log.txt and search for relevant keywords:
--      dodge / evade / guard / perfect / sub / controller / action
--   4. Use the "Probe SubActionController" button in the UI for live inspection

local dumped = false

re.on_pre_application_entry('BeginRendering', function()
    if dumped then return end
    dumped = true

    local types = {
        'app.HunterCharacter',
        'app.CharacterBase',
        'app.HunterCharacterBase',
    }

    for _, typeName in ipairs(types) do
        local td = sdk.find_type_definition(typeName)
        if not td then
            log.info('[Dumper] NOT FOUND: ' .. typeName)
        else
            local methods = td:get_methods()
            log.info(string.format('[Dumper] === %s  (%d methods) ===', typeName, #methods))
            for _, m in ipairs(methods) do
                log.info('[Dumper]   ' .. m:get_name())
            end
        end
    end

    -- Dump beginDodgeNoHit exact parameter types
    local hcTd = sdk.find_type_definition('app.HunterCharacter')
    if hcTd then
        for _, m in ipairs(hcTd:get_methods()) do
            if m:get_name() == 'beginDodgeNoHit' then
                local params = m:get_params()
                local sig = 'beginDodgeNoHit('
                for i, p in ipairs(params) do
                    sig = sig .. p:get_type():get_full_name()
                    if i < #params then sig = sig .. ', ' end
                end
                sig = sig .. ')'
                log.info('[Dumper] SIGNATURE: ' .. sig)
                for _, p in ipairs(params) do
                    log.info('[Dumper]   param "' .. p:get_name() .. '" : ' .. p:get_type():get_full_name())
                end
            end
        end
    end

    log.info('[Dumper] Done — check re2_framework_log.txt')
end)

local character_ref = nil
re.on_pre_application_entry('BeginRendering', function()
    pcall(function()
        local pm = sdk.get_managed_singleton('app.PlayerManager')
        if not pm then return end
        local mp = pm:getMasterPlayer()
        if not mp then return end
        character_ref = mp:get_Character()
    end)
end)

re.on_draw_ui(function()
    if not imgui.tree_node('[Dumper] Method Dumper') then return end

    if dumped then
        imgui.text_colored('Type dump complete — check re2_framework_log.txt', 0xFF44FF44)
    else
        imgui.text('Waiting for first frame...')
    end

    imgui.spacing()
    imgui.text('Search log for: dodge / evade / guard / perfect / controller')

    -- Live SubActionController probe
    if character_ref and imgui.button('Probe SubActionController (live)') then
        local names = {
            "get_SubActionController",
            "get_WeaponActionController",
            "get_BowActionController",
            "get_AimActionController",
        }
        for _, n in ipairs(names) do
            local ok, v = pcall(function() return character_ref:call(n) end)
            log.info(string.format('[Dumper] %s  ok=%s  val=%s', n, tostring(ok), tostring(v)))
        end
        pcall(function()
            local base = character_ref:call("get_BaseActionController")
            if base then
                log.info('[Dumper] BaseActionController type: ' .. tostring(base:get_type_definition():get_full_name()))
                for _, m in ipairs(base:get_type_definition():get_methods()) do
                    log.info('[Dumper]   CTRL M: ' .. m:get_name())
                end
            end
        end)
        log.info('[Dumper] Probe done.')
    end

    if character_ref then
        imgui.text_colored('Character ready — click button above', 0xFF44FF44)
    else
        imgui.text_colored('No character yet (load a hunt)', 0xFFAAAAFF)
    end

    imgui.tree_pop()
end)
