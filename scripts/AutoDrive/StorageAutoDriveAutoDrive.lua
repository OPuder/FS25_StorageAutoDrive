StorageAutoDriveAutoDrive = {}

function StorageAutoDriveAutoDrive:getOrderFillType(rootVehicle)
    StorageAutoDriveConfig:traceFunction("AUTODRIVE", "StorageAutoDriveAutoDrive:getOrderFillType")
    -- AD kann einen Auftrag ohne speziellen FillType als UNKNOWN melden.
    -- An dieser Grenze wird UNKNOWN einmalig in den internen Auftragssuchmodus
    -- ALL umgewandelt. Danach bleibt ALL intern nil und wird nicht mehr als
    -- GIANTS FillType.UNKNOWN weitergereicht.
    local rawFillType = self:getFillType(rootVehicle)
    if rawFillType == nil or rawFillType == FillType.UNKNOWN then
        return nil, rawFillType, true
    end
    return rawFillType, rawFillType, false
end

function StorageAutoDriveAutoDrive:getFillType(rootVehicle)
    StorageAutoDriveConfig:traceFunction("AUTODRIVE", "StorageAutoDriveAutoDrive:getFillType")
    if rootVehicle == nil or rootVehicle.ad == nil then return FillType.UNKNOWN end
    if rootVehicle.ad.ALCurrentFillTypeID ~= nil then
        return rootVehicle.ad.ALCurrentFillTypeID
    end
    local sm = rootVehicle.ad.stateModule
    if sm ~= nil and sm.getFillType ~= nil then
        local ok, value = pcall(function() return sm:getFillType() end)
        if ok and value ~= nil then return value end
    end
    return FillType.UNKNOWN
end

function StorageAutoDriveAutoDrive:isPickup(rootVehicle)
    StorageAutoDriveConfig:traceFunction("AUTODRIVE", "StorageAutoDriveAutoDrive:isPickup")
    if rootVehicle == nil or rootVehicle.ad == nil then return false end
    local sm = rootVehicle.ad.stateModule
    if sm == nil or sm.getCurrentMode == nil then return false end
    local ok, mode = pcall(function() return sm:getCurrentMode() end)
    if not ok or mode == nil then
        StorageAutoDriveConfig:debugRaw("AUTODRIVE", "PICKUP RAW | vehicle=" .. tostring(rootVehicle.id) .. " | stateModule=" .. tostring(sm) .. " | getCurrentModeOK=" .. tostring(ok) .. " | mode=nil")
        return false
    end
    if mode.shouldLoadOnTrigger ~= nil then
        local ok2, result = pcall(function() return mode:shouldLoadOnTrigger() end)
        if ok2 then
            StorageAutoDriveConfig:debugRaw("AUTODRIVE", "PICKUP RAW | vehicle=" .. tostring(rootVehicle.id) .. " | modeRef=" .. tostring(mode) .. " | modeName=" .. tostring(mode.name or mode.className or mode.modeName) .. " | shouldLoadOnTrigger=" .. tostring(result) .. " | callOK=" .. tostring(ok2))
            return result == true
        end
    end
    StorageAutoDriveConfig:debugRaw("AUTODRIVE", "PICKUP RAW | vehicle=" .. tostring(rootVehicle.id) .. " | modeRef=" .. tostring(mode) .. " | modeName=" .. tostring(mode.name or mode.className or mode.modeName) .. " | shouldLoadOnTrigger=nil")
    return false
end

function StorageAutoDriveAutoDrive:getTaskModeName(rootVehicle)
    StorageAutoDriveConfig:traceFunction("AUTODRIVE", "StorageAutoDriveAutoDrive:getTaskModeName")
    if rootVehicle == nil or rootVehicle.ad == nil or rootVehicle.ad.stateModule == nil then return "UNKNOWN" end
    local sm = rootVehicle.ad.stateModule
    if sm.getCurrentMode ~= nil then
        local ok, mode = pcall(function() return sm:getCurrentMode() end)
        if ok and mode ~= nil then
            return tostring(mode.name or mode.className or mode.modeName or "AD_MODE")
        end
    end
    return "UNKNOWN"
end

function StorageAutoDriveAutoDrive:hasTaskFinished(rootVehicle)
    StorageAutoDriveConfig:traceFunction("AUTODRIVE", "StorageAutoDriveAutoDrive:hasTaskFinished")
    if rootVehicle == nil then return true end
    -- Read-only completion signal. We intentionally do not finish the AD task.
    return self:isPickup(rootVehicle) == false
end

function StorageAutoDriveAutoDrive:debug(rootVehicle)
    StorageAutoDriveConfig:traceFunction("AUTODRIVE", "StorageAutoDriveAutoDrive:debug")
    if rootVehicle == nil then return end
    local ad = rootVehicle.ad
    StorageAutoDriveConfig:debugRaw("AUTODRIVE",
        "STATE RAW | vehicle=" .. tostring(rootVehicle.id)
        .. " | adRef=" .. tostring(ad)
        .. " | ALCurrentFillTypeID=" .. tostring(ad and ad.ALCurrentFillTypeID)
        .. " | stateModule=" .. tostring(ad and ad.stateModule)
        .. " | pickup=" .. tostring(self:isPickup(rootVehicle))
        .. " | mode=" .. tostring(self:getTaskModeName(rootVehicle)))
    StorageAutoDriveConfig:debug("AUTODRIVE",
        "READ-ONLY | Pickup=" .. tostring(self:isPickup(rootVehicle))
        .. " | Mode=" .. self:getTaskModeName(rootVehicle))
end
