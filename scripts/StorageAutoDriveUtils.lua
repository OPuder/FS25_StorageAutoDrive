StorageAutoDriveUtils = {}

function StorageAutoDriveUtils:getRootVehicle(vehicle)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:getRootVehicle")
    if vehicle == nil then return nil end
    if vehicle.getRootVehicle ~= nil then return vehicle:getRootVehicle() end
    return vehicle
end

function StorageAutoDriveUtils:getTableCount(t)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:getTableCount")
    local count = 0
    if t ~= nil then for _ in pairs(t) do count = count + 1 end end
    return count
end

function StorageAutoDriveUtils:getFillTypeName(fillTypeIndex)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:getFillTypeName")
    if fillTypeIndex == nil then return "UNKNOWN" end
    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeNameByIndex ~= nil then
        local ok, name = pcall(function()
            return g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
        end)
        if ok and name ~= nil then return tostring(name) end
    end
    return tostring(fillTypeIndex)
end

function StorageAutoDriveUtils:getStorageName(storage)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:getStorageName")
    if storage == nil then return "nil" end
    if storage.getName ~= nil then
        local ok, name = pcall(function() return storage:getName() end)
        if ok and name ~= nil and tostring(name) ~= "" then return tostring(name) end
    end
    if storage.xmlFile ~= nil and storage.xmlFile.getFilename ~= nil then
        local ok, filename = pcall(function() return storage.xmlFile:getFilename() end)
        if ok and filename ~= nil then return tostring(filename) end
    end
    return "ObjectStorage"
end

function StorageAutoDriveUtils:isObjectStorage(storage)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:isObjectStorage")
    return storage ~= nil and storage.spec_objectStorage ~= nil
end

function StorageAutoDriveUtils:isAllFillType(fillTypeIndex)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:isAllFillType")
    -- ALL ist ein interner Suchmodus und bewusst kein GIANTS FillType.
    return fillTypeIndex == nil
end

function StorageAutoDriveUtils:isUnknownFillType(fillTypeIndex)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:isUnknownFillType")
    -- FillType.UNKNOWN bleibt ein echter UNKNOWN-Wert. Er wird nicht mehr
    -- automatisch als ALL interpretiert.
    return fillTypeIndex == FillType.UNKNOWN
end

function StorageAutoDriveUtils:getRealObject(object)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:getRealObject")
    if object == nil then return nil end
    if object.getRealObject ~= nil then
        local ok, realObject = pcall(function() return object:getRealObject() end)
        if ok and realObject ~= nil then return realObject end
    end
    return object
end

function StorageAutoDriveUtils:getObjectFilename(object)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:getObjectFilename")
    if object == nil then return nil end
    local function read(o)
        if o == nil then return nil end
        if o.getXMLFilename ~= nil then
            local ok, filename = pcall(function() return o:getXMLFilename() end)
            if ok and filename ~= nil then return tostring(filename) end
        end
        if o.configFileName ~= nil then return tostring(o.configFileName) end
        if o.xmlFilename ~= nil then return tostring(o.xmlFilename) end
        return nil
    end
    local filename = read(object)
    if filename ~= nil then return filename end
    local realObject = self:getRealObject(object)
    if realObject ~= object then return read(realObject) end
    return nil
end

function StorageAutoDriveUtils:getObjectFillType(object)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:getObjectFillType")
    if object == nil then return nil end
    local function read(o)
        if o == nil then return nil end
        if o.getFillType ~= nil then
            local ok, fillType = pcall(function() return o:getFillType() end)
            if ok and fillType ~= nil then return fillType end
        end
        if o.fillType ~= nil then return o.fillType end
        if o.fillTypeIndex ~= nil then return o.fillTypeIndex end
        return nil
    end
    local fillType = read(object)
    if fillType ~= nil then return fillType end
    local realObject = self:getRealObject(object)
    if realObject ~= object then return read(realObject) end
    return nil
end

function StorageAutoDriveUtils:getObjectType(object)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveUtils:getObjectType")
    if StorageAutoDriveBaleObjects ~= nil then
        return StorageAutoDriveBaleObjects:getObjectType(object)
    end
    return "UNKNOWN"
end
