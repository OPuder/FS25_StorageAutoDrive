StorageAutoDriveStorage = { registeredStorages = {} }

function StorageAutoDriveStorage:register(storage)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveStorage:register")
    local cfg = StorageAutoDriveConfig
    if not StorageAutoDriveUtils:isObjectStorage(storage) or self.registeredStorages[storage] then return end
    self.registeredStorages[storage] = true
    local spec = storage.spec_objectStorage
    cfg:debug("STORAGE", "ObjectStorage erkannt: " .. StorageAutoDriveUtils:getStorageName(storage))
    if spec ~= nil then
        cfg:debug("STORAGE", "  Kapazität=" .. tostring(spec.capacity))
        cfg:debug("STORAGE", "  supportsBales=" .. tostring(spec.supportsBales))
        cfg:debug("STORAGE", "  supportsPallets=" .. tostring(spec.supportsPallets))
    end
end

function StorageAutoDriveStorage:unregister(storage)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveStorage:unregister")
    self.registeredStorages[storage] = nil
end

function StorageAutoDriveStorage:scan()
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveStorage:scan")
    local cfg = StorageAutoDriveConfig
    cfg:heartbeat("STORAGE", "scan start | registered=" .. tostring(self:count()))
    if g_currentMission == nil then return end
    if g_currentMission.placeableSystem == nil then return end
    local placeables = g_currentMission.placeableSystem.placeables
    if placeables == nil then return end
    for _, placeable in pairs(placeables) do
        if placeable ~= nil and placeable.spec_objectStorage ~= nil then self:register(placeable) end
    end
    cfg:heartbeat("STORAGE", "scan done | registered=" .. tostring(self:count()))
end

function StorageAutoDriveStorage:getNearest(vehicle)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveStorage:getNearest")
    local cfg = StorageAutoDriveConfig
    if vehicle == nil or vehicle.rootNode == nil then return nil end
    local vehicleX, vehicleY, vehicleZ = getWorldTranslation(vehicle.rootNode)
    local nearestStorage, nearestDistance = nil, StorageAutoDriveConfig.CHECK_DISTANCE
    for storage in pairs(self.registeredStorages) do
        if storage ~= nil and storage.spec_objectStorage ~= nil then
            local node = storage.spec_objectStorage.objectTriggerNode
            if node ~= nil then
                local x, y, z = getWorldTranslation(node)
                local dx, dy, dz = vehicleX - x, vehicleY - y, vehicleZ - z
                local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
                if distance <= nearestDistance then nearestDistance, nearestStorage = distance, storage end
            end
        end
    end
    if nearestStorage ~= nil then
        local vehicleKey = tostring(vehicle.id or vehicle)
        cfg:debugState(
            "nearestStorage:" .. vehicleKey,
            "STORAGE",
            "Nächstes Storage: " .. StorageAutoDriveUtils:getStorageName(nearestStorage)
        )
    end
    return nearestStorage
end

function StorageAutoDriveStorage:debugType(storage)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveStorage:debugType")
    local cfg = StorageAutoDriveConfig
    if not cfg.DEBUG or not cfg.LOG.STORAGE or storage == nil or storage.spec_objectStorage == nil then return end
    local spec = storage.spec_objectStorage
    if spec.supportsBales and spec.supportsPallets then cfg:debug("STORAGE", "Lagertyp: PALLETTEN + BALLEN")
    elseif spec.supportsBales then cfg:debug("STORAGE", "Lagertyp: BALLEN")
    elseif spec.supportsPallets then cfg:debug("STORAGE", "Lagertyp: PALETTEN")
    else cfg:debug("STORAGE", "Lagertyp: unbekannt") end
end

function StorageAutoDriveStorage:count()
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveStorage:count")
    return StorageAutoDriveUtils:getTableCount(self.registeredStorages)
end

function StorageAutoDriveStorage:cleanup()
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveStorage:cleanup")
    self.registeredStorages = {}
end
