-- StorageAutoDrive: narrowly scoped runtime extension for the AutoDrive fill-type dropdown.
-- No AutoDrive/UAL ZIP is modified. The patch is installed only if AutoDrive's actual
-- custom environment can be found and the expected functions are present.
StorageAutoDriveADBaleIntegration = StorageAutoDriveADBaleIntegration or {}
StorageAutoDriveADBaleIntegration.VERSION = "1.0.4.51"
StorageAutoDriveADBaleIntegration.installed = false
StorageAutoDriveADBaleIntegration.lastSearchLog = -10000
StorageAutoDriveADBaleIntegration.searchTimer = 0
StorageAutoDriveADBaleIntegration.lastFailure = nil

local function safeGet(t, k)
    if type(t) ~= "table" then return nil end
    local ok, value = pcall(function() return t[k] end)
    if ok then return value end
    return nil
end

local function isADEvironment(t)
    if type(t) ~= "table" then return false end
    local ad = safeGet(t, "AutoDrive")
    local list = safeGet(t, "ADPullDownList")
    local state = safeGet(t, "ADStateModule")
    return type(ad) == "table" and type(safeGet(ad, "getALFillTypes")) == "function"
        and type(list) == "table" and type(safeGet(list, "createSelection_FillType")) == "function"
        and type(state) == "table" and type(safeGet(state, "setFillType")) == "function"
end

local function findEnvironment()
    if isADEvironment(_G) then return _G, "_G" end
    if type(getfenv) == "function" then
        local ok, env = pcall(getfenv, 0)
        if ok and isADEvironment(env) then return env, "getfenv(0)" end
    end

    -- The AutoDrive classes live in AutoDrive's mod-specific Lua environment.
    -- The mod manager does not expose that environment. Resolve it from a real
    -- ADStateModule method on a live vehicle instead (Lua 5.1 getfenv).
    if type(getfenv) == "function" then
        local mission = g_currentMission
        local candidates = {}
        local function addVehicle(vehicle)
            if type(vehicle) == "table" then candidates[#candidates + 1] = vehicle end
        end
        if mission ~= nil then
            addVehicle(safeGet(mission, "controlledVehicle"))
            addVehicle(safeGet(mission, "currentVehicle"))
            -- FS25 stores mission vehicles under vehicleSystem.vehicles; mission.vehicles
            -- is not a reliable source and was the reason the previous environment
            -- lookup usually never inspected a vehicle carrying the AD specialization.
            local vehicleSystem = safeGet(mission, "vehicleSystem")
            local vehicles = safeGet(vehicleSystem, "vehicles")
            if type(vehicles) == "table" then
                for _, vehicle in pairs(vehicles) do addVehicle(vehicle) end
            end
            -- Keep a compatibility fallback for game versions exposing mission.vehicles.
            local legacyVehicles = safeGet(mission, "vehicles")
            if type(legacyVehicles) == "table" then
                for _, vehicle in pairs(legacyVehicles) do addVehicle(vehicle) end
            end
        end
        local seenVehicles = {}
        for _, vehicle in ipairs(candidates) do
            if not seenVehicles[vehicle] then
                seenVehicles[vehicle] = true
                local ad = safeGet(vehicle, "ad")
                local state = safeGet(ad, "stateModule")
                if type(state) == "table" then
                    local getFillType = safeGet(state, "getFillType")
                    if type(getFillType) == "function" then
                        local ok, env = pcall(getfenv, getFillType)
                        if ok and isADEvironment(env) then
                            return env, "getfenv(vehicle.ad.stateModule.getFillType; vehicleSystem scan)"
                        end
                    end
                end
            end
        end
    end

    local manager = g_modManager
    if type(manager) ~= "table" then return nil, "g_modManager unavailable" end

    -- Some GIANTS versions expose the custom environment on the mod descriptor;
    -- names differ between engine versions, so inspect only shallow known fields first.
    local candidates = {}
    local function addCandidate(value, label)
        if type(value) == "table" then
            candidates[#candidates + 1] = {value=value, label=label}
        end
    end
    local function inspectMod(mod, label)
        if type(mod) ~= "table" then return end
        for _, key in ipairs({"customEnvironment", "modEnvironment", "environment", "modEnv", "env", "scriptEnvironment"}) do
            addCandidate(safeGet(mod, key), label .. "." .. key)
        end
        addCandidate(mod, label)
    end

    for _, key in ipairs({"mods", "modItems", "loadedMods", "loadedModList", "modList"}) do
        local list = safeGet(manager, key)
        if type(list) == "table" then
            for k, mod in pairs(list) do
                local name = safeGet(mod, "name") or safeGet(mod, "modName") or safeGet(mod, "id") or tostring(k)
                if tostring(name):find("AutoDrive", 1, true) then inspectMod(mod, "g_modManager." .. key .. "." .. tostring(name)) end
            end
        end
    end
    if type(manager.getModByName) == "function" then
        for _, name in ipairs({"FS25_AutoDrive", "FS25_AutoDrive.zip"}) do
            local ok, mod = pcall(manager.getModByName, manager, name)
            if ok and mod ~= nil then inspectMod(mod, "getModByName(" .. name .. ")") end
        end
    end

    -- Bounded traversal of manager-owned tables; stop immediately when the real AD env is found.
    local seen, visited = {}, 0
    local function walk(t, path, depth)
        if type(t) ~= "table" or seen[t] or depth > 5 or visited > 12000 then return nil end
        seen[t] = true
        visited = visited + 1
        if isADEvironment(t) then return t, path end
        for k, v in pairs(t) do
            if type(v) == "table" then
                local result, label = walk(v, path .. "." .. tostring(k), depth + 1)
                if result ~= nil then return result, label end
            end
        end
        return nil
    end
    for _, candidate in ipairs(candidates) do
        local result, label = walk(candidate.value, candidate.label, 0)
        if result ~= nil then return result, label end
    end
    local result, label = walk(manager, "g_modManager", 0)
    if result ~= nil then return result, label end
    return nil, "AutoDrive-Umgebung weder über aktive AD-State-Methode noch Mod-Manager erreichbar (visited=" .. tostring(visited) .. ")"
end

local function getStrawFillTypeId()
    if g_fillTypeManager == nil then return nil end
    if type(g_fillTypeManager.getFillTypeIndexByName) == "function" then
        local ok, id = pcall(g_fillTypeManager.getFillTypeIndexByName, g_fillTypeManager, "STRAW")
        if ok and type(id) == "number" and id > 0 then return id end
    end
    if type(g_fillTypeManager.getFillTypes) == "function" then
        local ok, fillTypes = pcall(g_fillTypeManager.getFillTypes, g_fillTypeManager)
        if ok and type(fillTypes) == "table" then
            for index, fillType in ipairs(fillTypes) do
                if fillType ~= nil and fillType.name == "STRAW" then return index end
            end
        end
    end
    return nil
end

local function displayName(key, fallback)
    if g_i18n ~= nil and type(g_i18n.getText) == "function" then
        local ok, value = pcall(g_i18n.getText, g_i18n, key)
        if ok and value ~= nil and value ~= key and value ~= "" then return value end
    end
    return fallback
end

local function installOnEnvironment(env, label)
    local selection = StorageAutoDriveADBaleSelection
    local pullDown = env.ADPullDownList
    local stateModule = env.ADStateModule
    if type(pullDown) ~= "table" or type(stateModule) ~= "table" then return false, "HUD/state classes missing" end
    if pullDown.__storageAutoDriveBaleHook51 or stateModule.__storageAutoDriveBaleHook51 then
        return true, "already installed"
    end

    local originalCreate = pullDown.createSelection_FillType
    local originalGetState = pullDown.getNewState_FillType
    local originalSetFillType = stateModule.setFillType
    if type(originalCreate) ~= "function" or type(originalGetState) ~= "function" or type(originalSetFillType) ~= "function" then
        return false, "required AD methods missing"
    end

    pullDown.createSelection_FillType = function(self, ...)
        local results = {originalCreate(self, ...)}
        local entries = selection:getEntries()
        if type(self.options) == "table" and type(self.options[1]) == "table" then
            local list = self.options[1]
            local existing = {}
            for _, item in ipairs(list) do
                if item ~= nil then existing[item.returnValue] = true end
            end
            -- Keep variants next to the matching real fill type. If AD does not
            -- expose that fill type in this list, append the variant rather than
            -- guessing a different position or altering existing entries.
            local insertedAfterFillType = {}
            for _, entry in ipairs(entries) do
                if not existing[entry.id] then
                    local insertAt = #list + 1
                    for i, item in ipairs(list) do
                        if item ~= nil and item.returnValue == entry.fillTypeIndex then
                            insertAt = i + 1 + (insertedAfterFillType[entry.fillTypeIndex] or 0)
                            break
                        end
                    end
                    table.insert(list, insertAt, {displayName=entry.displayName, returnValue=entry.id, isFolder=false})
                    insertedAfterFillType[entry.fillTypeIndex] = (insertedAfterFillType[entry.fillTypeIndex] or 0) + 1
                    existing[entry.id] = true
                end
            end
        end
        return unpack(results)
    end

    stateModule.setFillType = function(self, fillTypeID, ...)
        local entry = selection:getEntryForId(fillTypeID)
        if entry ~= nil then
            self.storageAutoDriveBaleSelection = entry.id
            local result = originalSetFillType(self, entry.fillTypeIndex, ...)
            print("[StorageAutoDrive][ADBALE] Auswahl gesetzt | id=" .. tostring(entry.id)
                .. " | fillType=" .. tostring(entry.fillTypeName)
                .. " | shape=" .. tostring(entry.shape)
                .. " | wrap=" .. tostring(entry.wrapRequirement)
                .. " | env=" .. tostring(label))
            return result
        end
        self.storageAutoDriveBaleSelection = selection.MODE_NONE
        return originalSetFillType(self, fillTypeID, ...)
    end

    pullDown.getNewState_FillType = function(self, vehicle, ...)
        local a, b = originalGetState(self, vehicle, ...)
        local entry = selection:getEntryForVehicle(vehicle)
        if entry ~= nil then self.text = entry.displayName end
        return a, b
    end

    pullDown.__storageAutoDriveBaleHook51 = true
    stateModule.__storageAutoDriveBaleHook51 = true
    local entries = selection:getEntries()
    print("[StorageAutoDrive][ADBALE] AD-Ballenauswahl erweitert | env=" .. tostring(label) .. " | entries=" .. tostring(#entries) .. " | dynamic=BaleManager")
    return true, "installed"
end

function StorageAutoDriveADBaleIntegration:install()
    if self.installed then return true end
    local env, label = findEnvironment()
    if env == nil then
        local now = g_time or 0
        if now - self.lastSearchLog >= 5000 then
            self.lastSearchLog = now
            print("[StorageAutoDrive][ADBALE] AD-Umgebung noch nicht erreichbar | " .. tostring(label))
        end
        return false
    end
    local ok, message = installOnEnvironment(env, label)
    if ok then
        self.installed = true
        print("[StorageAutoDrive][ADBALE] Integration aktiv | " .. tostring(message))
        return true
    end
    local now = g_time or 0
    if now - self.lastSearchLog >= 5000 then
        self.lastSearchLog = now
        print("[StorageAutoDrive][ADBALE] AD-Umgebung gefunden, Hook nicht installiert | " .. tostring(message))
    end
    return false
end

function StorageAutoDriveADBaleIntegration:update(dt)
    if self.installed then return end
    self.searchTimer = self.searchTimer + (dt or 0)
    if self.searchTimer < 1000 then return end
    self.searchTimer = 0
    self:install()
end
