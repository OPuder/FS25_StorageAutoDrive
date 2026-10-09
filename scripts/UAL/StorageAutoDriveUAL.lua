StorageAutoDriveUAL = {}

function StorageAutoDriveUAL:findTrailer(vehicle)
    StorageAutoDriveConfig:traceFunction("UAL", "StorageAutoDriveUAL:findTrailer")
    if vehicle == nil then return nil end
    local visited = {}
    local function search(current)
        if current == nil or visited[current] then return nil end
        visited[current] = true
        if current.spec_universalAutoload ~= nil then return current end
        if current.getAttachedImplements ~= nil then
            local implements = current:getAttachedImplements()
            if implements ~= nil then
                for _, info in pairs(implements) do
                    local child = info ~= nil and info.object or nil
                    local found = search(child)
                    if found ~= nil then return found end
                end
            end
        end
        return nil
    end
    local found = search(vehicle)
    if found ~= nil then return found end
    if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil then
        local root = StorageAutoDriveUtils:getRootVehicle(vehicle)
        for _, candidate in pairs(g_currentMission.vehicleSystem.vehicles or {}) do
            if candidate ~= nil and candidate.spec_universalAutoload ~= nil
                and StorageAutoDriveUtils:getRootVehicle(candidate) == root then
                return candidate
            end
        end
    end
    return nil
end

function StorageAutoDriveUAL:getLoadedObjects(trailer)
    StorageAutoDriveConfig:traceFunction("UAL", "StorageAutoDriveUAL:getLoadedObjects")
    if trailer == nil or trailer.spec_universalAutoload == nil then
        StorageAutoDriveConfig:traceDecision("UAL", "LOADED_OBJECTS_EMPTY_NO_SPEC")
        return {}
    end
    local objects = trailer.spec_universalAutoload.loadedObjects or {}
    StorageAutoDriveConfig:traceValue("UAL", "loadedObjects count=" .. tostring(StorageAutoDriveUtils:getTableCount(objects)))
    return objects
end

function StorageAutoDriveUAL:getAvailableObjects(trailer)
    StorageAutoDriveConfig:traceFunction("UAL", "StorageAutoDriveUAL:getAvailableObjects")
    if trailer == nil or trailer.spec_universalAutoload == nil then
        StorageAutoDriveConfig:traceDecision("UAL", "AVAILABLE_OBJECTS_EMPTY_NO_SPEC")
        return {}
    end
    local objects = trailer.spec_universalAutoload.availableObjects or {}
    StorageAutoDriveConfig:traceValue("UAL", "availableObjects count=" .. tostring(StorageAutoDriveUtils:getTableCount(objects)))
    return objects
end

function StorageAutoDriveUAL:isFull(trailer)
    StorageAutoDriveConfig:traceFunction("UAL", "StorageAutoDriveUAL:isFull")
    if trailer == nil or trailer.spec_universalAutoload == nil then
        StorageAutoDriveConfig:traceDecision("UAL", "IS_FULL_FALSE_NO_SPEC")
        return false
    end
    local spec = trailer.spec_universalAutoload
    local result = spec.trailerIsFull == true
    StorageAutoDriveConfig:traceValue("UAL", "isFull | trailer=" .. tostring(trailer.id) .. " | trailerIsFull=" .. tostring(spec.trailerIsFull) .. " | result=" .. tostring(result))
    return result
end

function StorageAutoDriveUAL:isLoading(trailer)
    StorageAutoDriveConfig:traceFunction("UAL", "StorageAutoDriveUAL:isLoading")
    local result = trailer ~= nil and trailer.spec_universalAutoload ~= nil and trailer.spec_universalAutoload.isLoading == true
    StorageAutoDriveConfig:traceValue("UAL", "isLoading | trailer=" .. tostring(trailer and trailer.id) .. " | result=" .. tostring(result))
    return result
end

function StorageAutoDriveUAL:getFillState(trailer)
    StorageAutoDriveConfig:traceFunction("UAL", "StorageAutoDriveUAL:getFillState")
    if trailer == nil then return nil, nil, nil end
    local level, capacity, free = nil, nil, nil
    if trailer.ualGetFillUnitFillLevel ~= nil then
        local ok, value = pcall(function() return trailer:ualGetFillUnitFillLevel() end)
        if ok then level = tonumber(value) end
    end
    if trailer.ualGetFillUnitCapacity ~= nil then
        local ok, value = pcall(function() return trailer:ualGetFillUnitCapacity() end)
        if ok then capacity = tonumber(value) end
    end
    if trailer.ualGetFillUnitFreeCapacity ~= nil then
        local ok, value = pcall(function() return trailer:ualGetFillUnitFreeCapacity() end)
        if ok then free = tonumber(value) end
    end
    return level, capacity, free
end

function StorageAutoDriveUAL:debug(trailer)
    StorageAutoDriveConfig:traceFunction("UAL", "StorageAutoDriveUAL:debug")
    if trailer == nil or trailer.spec_universalAutoload == nil then return end
    local level, capacity, free = self:getFillState(trailer)
    local spec = trailer.spec_universalAutoload
    StorageAutoDriveConfig:debugRaw("UAL", "SPEC RAW | trailer=" .. tostring(trailer.id) .. " | ref=" .. tostring(trailer) .. " | loading=" .. tostring(spec.isLoading) .. " | full=" .. tostring(spec.trailerIsFull) .. " | totalUnload=" .. tostring(spec.totalUnloadCount) .. " | totalAvailable=" .. tostring(spec.totalAvailableCount) .. " | validLoad=" .. tostring(spec.validLoadCount) .. " | validUnload=" .. tostring(spec.validUnloadCount) .. " | materialIndex=" .. tostring(spec.currentMaterialIndex or spec.materialIndex))
    StorageAutoDriveConfig:debug("UAL",
        "READ-ONLY | loading=" .. tostring(spec.isLoading)
        .. " | full=" .. tostring(spec.trailerIsFull)
        .. " | available=" .. tostring(StorageAutoDriveUtils:getTableCount(spec.availableObjects))
        .. " | fill=" .. tostring(level) .. "/" .. tostring(capacity)
        .. " | free=" .. tostring(free))
end


function StorageAutoDriveUAL:debugCollections(trailer, reason)
    StorageAutoDriveConfig:traceFunction("UAL", "StorageAutoDriveUAL:debugCollections")
    if trailer == nil or trailer.spec_universalAutoload == nil then return end
    local spec = trailer.spec_universalAutoload
    StorageAutoDriveConfig:traceCollections("BEGIN | trailer=" .. tostring(trailer.id) .. " | reason=" .. tostring(reason))
    local partsLoaded = {}
    local partsAvailable = {}
    for object in pairs(spec.loadedObjects or {}) do
        StorageAutoDriveConfig:debugRaw("UAL", "LOADED OBJECT | trailer=" .. tostring(trailer.id) .. " | objectRef=" .. tostring(object) .. " | objectId=" .. tostring(object and object.id) .. " | file=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)) .. " | fillType=" .. tostring(StorageAutoDriveUtils:getObjectFillType(object)))
        partsLoaded[#partsLoaded + 1] = tostring(object and object.id) .. ":" .. tostring(StorageAutoDriveUtils:getObjectFilename(object))
    end
    for object in pairs(spec.availableObjects or {}) do
        StorageAutoDriveConfig:debugRaw("UAL", "AVAILABLE OBJECT | trailer=" .. tostring(trailer.id) .. " | objectRef=" .. tostring(object) .. " | objectId=" .. tostring(object and object.id) .. " | file=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)) .. " | fillType=" .. tostring(StorageAutoDriveUtils:getObjectFillType(object)))
        partsAvailable[#partsAvailable + 1] = tostring(object and object.id) .. ":" .. tostring(StorageAutoDriveUtils:getObjectFilename(object))
    end
    StorageAutoDriveConfig:debug("UAL",
        "COLLECTIONS | " .. tostring(reason)
        .. " | loading=" .. tostring(spec.isLoading)
        .. " | full=" .. tostring(spec.trailerIsFull)
        .. " | totalUnload=" .. tostring(spec.totalUnloadCount)
        .. " | available=[" .. table.concat(partsAvailable, ",") .. "]"
        .. " | loaded=[" .. table.concat(partsLoaded, ",") .. "]")
end
