-- MHW_SAxeDebugger.lua  v4
-- Finds the persistent sword/axe form flag for Switch Axe.
-- Safe: only calls get_/is/has methods and reads fields (no arbitrary method calls).
--
-- HOW TO USE:
--   1. Copy to reframework/autorun/
--   2. Equip SA, load hunt, open REFramework UI -> [SADebug]
--   3. KEYWORD LIVE SCAN: watch values while morphing axe<->sword
--   4. Or: stand idle AXE -> Capture Baseline -> morph SWORD -> watch Changed list
--   5. Remove from autorun when done

local character    = nil
local lastCharPtr  = nil
local saWeapon     = nil
local dumped       = false

local allGetters   = {}
local foundObjects = {}
local baseline     = {}
local current      = {}
local changedList  = {}
local baselineCaptured = false
local keywordGetters   = {}

local KEYWORDS = {
    "sword", "axe", "form", "mode", "morph", "stance",
    "switch", "attach", "parts", "onoff", "on_off",
    "visual", "state", "variety", "overwrite",
    "blade", "phial", "weapon",
}

local function matchesKeyword(label)
    local low = label:lower()
    for _, kw in ipairs(KEYWORDS) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

local seen_labels = {}

local function addGetter(obj, key, isField, labelPrefix)
    local label = labelPrefix .. (isField and '.#' or '.') .. key
    if seen_labels[label] then return end
    seen_labels[label] = true
    local g = { label = label, obj = obj, key = key, isField = isField }
    table.insert(allGetters, g)
    if matchesKeyword(label) then
        table.insert(keywordGetters, g)
    end
end

local function getValue(g)
    if not g.obj then return nil end
    if g.isField then
        local ok, v = pcall(function() return g.obj:get_field(g.key) end)
        return ok and v or nil
    else
        local ok, v = pcall(function() return g.obj:call(g.key) end)
        return ok and v or nil
    end
end

local function valToStr(v)
    if v == nil then return "nil" end
    local t = type(v)
    if t == "boolean" or t == "number" then return tostring(v) end
    if t == "string" then
        return #v > 24 and v:sub(1,24)..'…' or v
    end
    local s = tostring(v)
    return (s and #s > 32) and s:sub(1,32)..'…' or (s or "?")
end

-- Only safe getter-style methods
local function scanMethods(obj, labelPrefix)
    if not obj then return 0 end
    local td; pcall(function() td = obj:get_type_definition() end)
    if not td then return 0 end
    local n = 0
    for _, m in ipairs(td:get_methods()) do
        pcall(function()
            local name = m:get_name()
            if name:sub(1,4)=="get_" or name:sub(1,2)=="is" or name:sub(1,3)=="has" then
                addGetter(obj, name, false, labelPrefix)
                n = n + 1
            end
        end)
    end
    return n
end

local function scanFields(obj, labelPrefix)
    if not obj then return 0 end
    local td; pcall(function() td = obj:get_type_definition() end)
    if not td then return 0 end
    local n = 0
    for _, f in ipairs(td:get_fields()) do
        pcall(function()
            addGetter(obj, f:get_name(), true, labelPrefix)
            n = n + 1
        end)
    end
    return n
end

local function tryGetObj(source, mname)
    local ok, obj = pcall(function() return source:call(mname) end)
    if ok and obj ~= nil and type(obj) == "userdata" then return obj end
    return nil
end

local function scanGameObject(go, label)
    if not go then return end
    local compCount = 0
    pcall(function() compCount = go:call("get_ComponentCount") or 0 end)
    for i = 0, math.min(compCount-1, 150) do
        pcall(function()
            local comp = go:call("get_Component(System.Int32)", i)
            if not comp then return end
            local td; pcall(function() td = comp:get_type_definition() end)
            if not td then return end
            local tname = td:get_full_name()
            local lbl = label..'[C'..i..':'..tname..']'
            table.insert(foundObjects, lbl)
            scanMethods(comp, lbl)
            scanFields(comp, lbl)
        end)
    end
end

-- Character types to scan
local CHAR_TYPES = { "app.HunterCharacter", "app.CharacterBase" }

-- SA-specific type guesses
local SA_TYPES = {
    "app.SwitchAxeCharacter", "app.SaCharacter", "app.SACharacter",
    "app.SwitchAxeWeapon",    "app.SaWeapon",    "app.SAWeapon",
    "app.SwitchAxe",          "app.WeaponSwitchAxe",
    "app.HunterWeapon",       "app.WeaponBase",  "app.Weapon",
}

local WEAPON_ACCESSORS = {
    "get_Weapon", "get_WeaponController", "get_WeaponBase",
    "get_ActionWeapon", "get_WeaponObject", "get_CurrentWeapon",
    "get_SubWeapon", "get_MainWeapon",
}

local function buildGetterList()
    allGetters    = {}
    keywordGetters= {}
    foundObjects  = {}
    seen_labels   = {}

    -- 1. Known character types
    for _, t in ipairs(CHAR_TYPES) do
        local td = sdk.find_type_definition(t)
        if td then
            local nm, nf = 0, 0
            for _, m in ipairs(td:get_methods()) do
                pcall(function()
                    local name = m:get_name()
                    if name:sub(1,4)=="get_" or name:sub(1,2)=="is" or name:sub(1,3)=="has" then
                        addGetter(character, name, false, '['..t..']')
                        nm = nm + 1
                    end
                end)
            end
            for _, f in ipairs(td:get_fields()) do
                pcall(function()
                    addGetter(character, f:get_name(), true, '['..t..']')
                    nf = nf + 1
                end)
            end
            log.info(string.format('[SADebug] %s: %dm %df', t, nm, nf))
        end
    end

    -- 2. SA-specific type guesses scanned against character object
    for _, t in ipairs(SA_TYPES) do
        local td = sdk.find_type_definition(t)
        if td then
            local nm, nf = 0, 0
            for _, m in ipairs(td:get_methods()) do
                pcall(function()
                    local name = m:get_name()
                    if name:sub(1,4)=="get_" or name:sub(1,2)=="is" or name:sub(1,3)=="has" then
                        addGetter(character, name, false, '[SA:'..t..']')
                        nm = nm + 1
                    end
                end)
            end
            for _, f in ipairs(td:get_fields()) do
                pcall(function()
                    addGetter(character, f:get_name(), true, '[SA:'..t..']')
                    nf = nf + 1
                end)
            end
            if nm+nf > 0 then
                log.info(string.format('[SADebug] SA type %s: %dm %df', t, nm, nf))
            end
        end
    end

    -- 3. Weapon accessors: safe getter methods + fields + weapon GO
    for _, mname in ipairs(WEAPON_ACCESSORS) do
        pcall(function()
            local obj = tryGetObj(character, mname)
            if not obj then return end
            local td; pcall(function() td = obj:get_type_definition() end)
            local tname = td and td:get_full_name() or mname
            local lbl = 'WPN['..mname..':'..tname..']'
            table.insert(foundObjects, lbl)
            local nm = scanMethods(obj, lbl)
            local nf = scanFields(obj, lbl)
            log.info(string.format('[SADebug] %s -> %dm %df', lbl, nm, nf))
            if not saWeapon then saWeapon = obj end

            local wpnGO = tryGetObj(obj, "get_GameObject")
            if wpnGO then
                log.info('[SADebug] Weapon GO — scanning components')
                scanGameObject(wpnGO, lbl..'.GO')
            end
        end)
    end

    -- Indexed weapon slots
    for slot = 0, 5 do
        pcall(function()
            local obj = character:call("get_Weapon(System.Int32)", slot)
            if obj == nil or type(obj) ~= "userdata" then return end
            local td; pcall(function() td = obj:get_type_definition() end)
            local tname = td and td:get_full_name() or ('slot'..slot)
            local lbl = 'WPN[slot'..slot..':'..tname..']'
            table.insert(foundObjects, lbl)
            scanMethods(obj, lbl)
            scanFields(obj, lbl)
            local wpnGO = tryGetObj(obj, "get_GameObject")
            if wpnGO then scanGameObject(wpnGO, lbl..'.GO') end
        end)
    end

    -- 4. Character game object components
    pcall(function()
        local go = tryGetObj(character, "get_GameObject")
        if not go then return end
        local compCount = 0
        pcall(function() compCount = go:call("get_ComponentCount") or 0 end)
        log.info('[SADebug] Char GO: '..compCount..' components')
        for i = 0, math.min(compCount-1, 150) do
            pcall(function()
                local comp = go:call("get_Component(System.Int32)", i)
                if not comp then return end
                local td; pcall(function() td = comp:get_type_definition() end)
                if not td then return end
                local tname = td:get_full_name()
                local lbl = 'CharComp[C'..i..':'..tname..']'
                table.insert(foundObjects, lbl)
                scanMethods(comp, lbl)
                scanFields(comp, lbl)
            end)
        end
    end)

    log.info(string.format('[SADebug] Done: %d getters (%d keyword), %d objects',
        #allGetters, #keywordGetters, #foundObjects))
end

-- Live values
local liveVS = -1
local liveVIMT = -999
local liveOWOS_getfield = "?"   -- via obj:get_field()
local liveOWOS_native   = "?"   -- via sdk.get_native_field()
local liveBaseCat, liveBaseIdx = -1, -1
local liveMotionID, liveMotionBankID = -1, -1
local liveWpHandling = "nil"
local kwLive = {}

local HUNTER_TD_DBG = sdk.find_type_definition("app.HunterCharacter")

local function pollAll()
    current = {}
    kwLive  = {}
    if not character then return end

    pcall(function()
        local w = character:call("get_Weapon")
        if w then saWeapon = w end
    end)

    pcall(function() liveVS = saWeapon and saWeapon:call("get_VisualState") or -1 end)
    pcall(function() liveVIMT = character:call("get_VarietyIdleMotionType") end)

    -- Two ways to read _OverwriteWeaponOnOffState
    pcall(function()
        local v = character:get_field("_OverwriteWeaponOnOffState")
        liveOWOS_getfield = tostring(v)
    end)
    pcall(function()
        local v = sdk.get_native_field(character, HUNTER_TD_DBG, "_OverwriteWeaponOnOffState")
        liveOWOS_native = tostring(v)
    end)

    -- Motion layer (via.motion.Motion component)
    pcall(function()
        local pm = sdk.get_managed_singleton("app.PlayerManager")
        local mp = pm:getMasterPlayer()
        local obj = mp:get_Object()
        local motion = obj:getComponent(sdk.typeof("via.motion.Motion"))
        if not motion then return end
        local layer = motion:getLayer(0)
        if not layer then return end
        liveMotionID     = layer:get_MotionID()
        liveMotionBankID = layer:get_MotionBankID()
    end)

    -- WeaponHandling object type
    pcall(function()
        local wh = character:call("get_WeaponHandling")
        if not wh then liveWpHandling = "nil"; return end
        local td; pcall(function() td = wh:get_type_definition() end)
        liveWpHandling = td and td:get_full_name() or "?"
        -- scan it
        local lbl = 'WH['..liveWpHandling..']'
        scanMethods(wh, lbl)
        scanFields(wh, lbl)
    end)

    pcall(function()
        local ctrl = character:call("get_BaseActionController")
        if not ctrl then return end
        local id = ctrl:call("get_CurrentActionID")
        if not id then return end
        liveBaseCat = id:get_field("_Category")
        liveBaseIdx = id:get_field("_Index")
    end)

    for _, g in ipairs(keywordGetters) do
        local val = getValue(g)
        if val ~= nil then kwLive[g.label] = valToStr(val) end
    end

    for _, g in ipairs(allGetters) do
        local val = getValue(g)
        if val ~= nil then
            local t = type(val)
            if t == "boolean" or t == "number" then
                current[g.label] = tostring(val)
            end
        end
    end
end

local function captureBaseline()
    baseline = {}
    for k, v in pairs(current) do baseline[k] = v end
    changedList = {}
    baselineCaptured = true
    log.info('[SADebug] Baseline captured')
end

local function updateChanged()
    changedList = {}
    for k, now in pairs(current) do
        local was = baseline[k]
        if was ~= nil and was ~= now then
            table.insert(changedList, { label = k, was = was, now = now })
        end
    end
    table.sort(changedList, function(a, b) return a.label < b.label end)
end

re.on_pre_application_entry('BeginRendering', function()
    pcall(function()
        local pm = sdk.get_managed_singleton('app.PlayerManager')
        if not pm then return end
        local mp = pm:getMasterPlayer()
        if not mp then return end
        character = mp:get_Character()
    end)

    if character then
        local ptr = tostring(character)
        if ptr ~= lastCharPtr then
            lastCharPtr = ptr
            dumped = false
            baselineCaptured = false
            baseline = {}; changedList = {}
            saWeapon = nil
        end
    end

    if not dumped and character then
        dumped = true
        buildGetterList()
    end

    if not character then return end
    pollAll()
    if baselineCaptured then updateChanged() end
end)

local sortedKwLabels = nil
local lastKwCount = 0

re.on_draw_ui(function()
    if not imgui.tree_node('[SADebug] Switch Axe Mode Finder v5') then return end

    if not character then
        imgui.text_colored('No character', 0xFFAAAAFF)
        imgui.tree_pop(); return
    end

    imgui.text_colored('=== LIVE ===', 0xFFFFAA44)
    imgui.text(string.format('VisualState: %d    VarietyIdleMotionType: %d', liveVS, liveVIMT))
    imgui.text(string.format('BASE Cat=%d Idx=%d', liveBaseCat, liveBaseIdx))
    imgui.text(string.format('Motion: ID=%d  BankID=%d', liveMotionID, liveMotionBankID))
    imgui.text_colored('WeaponHandling type: '..liveWpHandling, 0xFF88AAFF)
    imgui.text_colored(
        string.format('OWOS get_field=%s  native=%s', liveOWOS_getfield, liveOWOS_native),
        0xFFFFFF44)
    imgui.text_colored('  (0=axe 1=sword — if both show ? field doesnt exist / wrong type)',
        0xFF888888)
    imgui.text_colored('Weapon: ' .. (saWeapon and 'YES' or 'NO'),
        saWeapon and 0xFF44FF44 or 0xFFFF4444)
    imgui.spacing()

    if not dumped then
        imgui.text('Building...'); imgui.tree_pop(); return
    end

    imgui.text_colored(
        string.format('%d getters | %d keyword | %d objects',
            #allGetters, #keywordGetters, #foundObjects),
        0xFF44FF44)

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    -- KEYWORD LIVE SCAN
    imgui.text_colored('=== KEYWORD LIVE SCAN (morph and watch) ===', 0xFFFFAA44)
    imgui.text_colored('Watch for any value that flips and stays flipped between forms', 0xFF888888)
    imgui.spacing()

    if not sortedKwLabels or #keywordGetters ~= lastKwCount then
        sortedKwLabels = {}
        for _, g in ipairs(keywordGetters) do
            table.insert(sortedKwLabels, g.label)
        end
        table.sort(sortedKwLabels)
        lastKwCount = #keywordGetters
    end

    if #sortedKwLabels == 0 then
        imgui.text_colored('No keyword matches', 0xFFAAAAFF)
    else
        imgui.indent(8)
        for _, lbl in ipairs(sortedKwLabels) do
            local val = kwLive[lbl]
            if val then
                imgui.text_colored(lbl, 0xFF88CCFF)
                imgui.same_line()
                imgui.text_colored('= '..val, 0xFFFFFF44)
            end
        end
        imgui.unindent(8)
    end

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    -- BASELINE DIFF
    imgui.text_colored('=== BASELINE DIFF ===', 0xFFFFAA44)
    imgui.text_colored('1. AXE form idle  2. Capture  3. SWORD form idle', 0xFFFFFF44)
    imgui.spacing()

    if imgui.button('Capture Baseline') then captureBaseline() end
    if baselineCaptured then imgui.same_line(); imgui.text_colored('OK', 0xFF44FF44) end
    imgui.spacing()

    if baselineCaptured then
        imgui.text(string.format('Changed (%d):', #changedList))
        if #changedList == 0 then
            imgui.text_colored('No changes yet', 0xFFAAAAAA)
        else
            imgui.indent(12)
            for _, e in ipairs(changedList) do
                imgui.text_colored(e.label, 0xFF44FF44)
                imgui.indent(12)
                imgui.text_colored(string.format('axe: %s   sword: %s', e.was, e.now), 0xFFFFFF44)
                imgui.unindent(12)
            end
            imgui.unindent(12)
        end
    end

    imgui.spacing()
    if imgui.tree_node('Objects scanned') then
        for _, s in ipairs(foundObjects) do imgui.text_colored(s, 0xFF777777) end
        imgui.tree_pop()
    end

    imgui.tree_pop()
end)
