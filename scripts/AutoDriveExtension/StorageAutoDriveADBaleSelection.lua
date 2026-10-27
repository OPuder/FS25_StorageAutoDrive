-- StorageAutoDrive bale selection definitions.
-- Custom AD values are translated back to real GIANTS fill types before AD stores them.
StorageAutoDriveADBaleSelection = StorageAutoDriveADBaleSelection or {}
local S = StorageAutoDriveADBaleSelection
S.VERSION = 2
S.ID_BASE = 9001
S.MODE_NONE = 0
S.byId = S.byId or {}
S.entries = S.entries or {}
S.lastSignature = nil

local function safeCall(object, method, ...)
    if object == nil or type(object[method]) ~= "function" then return nil end
    local ok, result = pcall(object[method], object, ...)
    if ok then return result end
    return nil
end

local function getFillTypeName(index)
    if g_fillTypeManager == nil then return nil end
    local fillType = safeCall(g_fillTypeManager, "getFillTypeByIndex", index)
    return fillType ~= nil and fillType.name or nil
end

local function getFillTypeTitle(index, fallback)
    if g_fillTypeManager ~= nil then
        local title = safeCall(g_fillTypeManager, "getFillTypeTitleByIndex", index)
        if title ~= nil and title ~= "" then return title end
    end
    if g_i18n ~= nil and type(g_i18n.getText) == "function" then
        local key = "fillType_" .. tostring(getFillTypeName(index) or "")
        local title = safeCall(g_i18n, "getText", key)
        if title ~= nil and title ~= key and title ~= "" then return title end
    end
    return fallback or tostring(getFillTypeName(index) or "Ballen")
end

local function makeSignature(entries)
    local parts = {}
    for _, e in ipairs(entries) do
        parts[#parts + 1] = table.concat({e.fillTypeName, e.shape, tostring(e.wrapRequirement)}, ":")
    end
    return table.concat(parts, "|")
end

function S:refreshEntries()
    local manager = g_baleManager
    local bales = manager ~= nil and manager.bales or nil
    if type(bales) ~= "table" then return self.entries end

    local combinations, keys = {}, {}
    for _, bale in ipairs(bales) do
        if type(bale) == "table" and type(bale.fillTypes) == "table" then
            local shape = bale.isRoundbale == true and "ROUND" or "SQUARE"
            for _, ft in ipairs(bale.fillTypes) do
                local name = ft ~= nil and getFillTypeName(ft.fillTypeIndex) or nil
                if name ~= nil and name ~= "" then
                    local supportsWrapping = ft.supportsWrapping == true or name == "GRASS" or name == "SILAGE"
                    local wrapStates = supportsWrapping and {false, true} or {false}
                    for _, wrapState in ipairs(wrapStates) do
                        local requirement = supportsWrapping and wrapState or nil
                        local key = name .. "|" .. shape .. "|" .. tostring(requirement)
                        if not keys[key] then
                            keys[key] = true
                            combinations[#combinations + 1] = {
                                fillTypeIndex=ft.fillTypeIndex,
                                fillTypeName=name,
                                fillTypeTitle=getFillTypeTitle(ft.fillTypeIndex, name),
                                shape=shape,
                                wrapRequirement=requirement,
                                supportsWrapping=supportsWrapping
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(combinations, function(a, b)
        if a.fillTypeTitle ~= b.fillTypeTitle then return a.fillTypeTitle < b.fillTypeTitle end
        if a.shape ~= b.shape then return a.shape == "ROUND" end
        if a.wrapRequirement ~= b.wrapRequirement then return a.wrapRequirement == false end
        return a.fillTypeName < b.fillTypeName
    end)

    local signature = makeSignature(combinations)
    if signature == self.lastSignature then return self.entries end
    self.lastSignature = signature
    self.entries = {}
    self.byId = {}
    local nextId = self.ID_BASE
    for _, e in ipairs(combinations) do
        e.id = nextId
        nextId = nextId + 1
        local shapeText = e.shape == "ROUND" and "Rundballen" or "Quaderballen"
        local label = e.fillTypeTitle .. " – " .. shapeText
        if e.wrapRequirement == true then label = label .. " (mit Folie)"
        elseif e.wrapRequirement == false and e.supportsWrapping then label = label .. " (ohne Folie)" end
        e.displayName = label
        e.localizationKey = nil
        self.entries[#self.entries + 1] = e
        self.byId[e.id] = e
    end
    return self.entries
end

function S:getEntries()
    return self:refreshEntries()
end

function S:getEntryForId(id)
    if id == nil then return nil end
    self:refreshEntries()
    return self.byId[id]
end

function S:getModeForId(id)
    local entry = self:getEntryForId(id)
    return entry ~= nil and entry.id or self.MODE_NONE
end

function S:getBaseFillTypeId(id)
    local entry = self:getEntryForId(id)
    return entry ~= nil and entry.fillTypeIndex or nil
end

function S:getDisplayName(entry)
    if entry == nil then return "Ballen" end
    return entry.displayName or (entry.fillTypeTitle .. " – " .. (entry.shape == "ROUND" and "Rundballen" or "Quaderballen"))
end

function S:getForVehicle(vehicle)
    if vehicle == nil then return self.MODE_NONE end
    local root = vehicle.getRootVehicle and vehicle:getRootVehicle() or vehicle
    local state = root and root.ad and root.ad.stateModule or nil
    local id = state and state.storageAutoDriveBaleSelection or self.MODE_NONE
    return self:getEntryForId(id) ~= nil and id or self.MODE_NONE
end

function S:getEntryForVehicle(vehicle)
    return self:getEntryForId(self:getForVehicle(vehicle))
end

function S:setForVehicle(vehicle, id)
    if vehicle == nil then return false end
    local root = vehicle.getRootVehicle and vehicle:getRootVehicle() or vehicle
    local state = root and root.ad and root.ad.stateModule or nil
    if state == nil then return false end
    state.storageAutoDriveBaleSelection = id or self.MODE_NONE
    if state.raiseDirtyFlag ~= nil then state:raiseDirtyFlag() end
    return true
end
