local function getStorageRequestDiagnostics(storage, objectInfoIndex)
    local spec = storage ~= nil and storage.spec_objectStorage or nil
    if spec == nil then
        return "spec_objectStorage=nil"
    end

    local spawn = spec.objectSpawn
    local infos = spec.objectInfos
    local info = infos ~= nil and infos[objectInfoIndex] or nil
    local objectsCount = info ~= nil and info.objects ~= nil and #info.objects or nil

    return "isActive=" .. tostring(spawn ~= nil and spawn.isActive)
        .. " | objectInfosUpdateTimer=" .. tostring(spec.objectInfosUpdateTimer)
        .. " | numStoredObjects=" .. tostring(spec.numStoredObjects)
        .. " | groupExists=" .. tostring(info ~= nil)
        .. " | groupNumObjects=" .. tostring(info ~= nil and info.numObjects or nil)
        .. " | groupObjectsLength=" .. tostring(objectsCount)
        .. " | spawnInfoIndex=" .. tostring(spawn ~= nil and spawn.objectInfoIndex or nil)
        .. " | spawnRemaining=" .. tostring(spawn ~= nil and spawn.numObjectsToSpawn or nil)
        .. " | overlapIsActive=" .. tostring(spawn ~= nil and spawn.overlapIsActive)
        .. " | overlapObjectCount=" .. tostring(spawn ~= nil and spawn.overlapObjectCount or nil)
end

StorageAutoDriveObjects = {}

function StorageAutoDriveObjects:getObjectInfos(storage)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveObjects:getObjectInfos")
    StorageAutoDriveConfig:heartbeat("OBJECTS", "object infos")
    if not StorageAutoDriveUtils:isObjectStorage(storage) then return nil end
    if storage.getObjectStorageObjectInfos ~= nil then
        local ok, infos = pcall(function() return storage:getObjectStorageObjectInfos() end)
        if ok and infos ~= nil then return infos end
    end
    local spec = storage.spec_objectStorage
    if spec ~= nil then return spec.objectInfos end
    return nil
end

function StorageAutoDriveObjects:debugObjectInfos(storage)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveObjects:debugObjectInfos")
    local cfg = StorageAutoDriveConfig
    if not cfg.DEBUG or not cfg.LOG.OBJECTS then return end
    local infos = self:getObjectInfos(storage)
    if infos == nil then cfg:debug("OBJECTS", "ObjectStorage: keine objectInfos verfügbar"); return end
    cfg:debug("OBJECTS", "ObjectStorage: " .. tostring(#infos) .. " Objektgruppen")
    for index, info in ipairs(infos) do
        local object = info ~= nil and info.objects ~= nil and info.objects[1] or nil
        cfg:debug("OBJECTS", "Gruppe " .. tostring(index) .. ": Anzahl=" .. tostring(info ~= nil and info.numObjects or 0) .. " | Typ=" .. StorageAutoDriveUtils:getObjectType(object) .. " | FillType=" .. StorageAutoDriveUtils:getFillTypeName(StorageAutoDriveUtils:getObjectFillType(object)) .. " | Datei=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)))
    end
end

function StorageAutoDriveObjects:findObjectInfoForFillType(storage, fillTypeIndex)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveObjects:findObjectInfoForFillType")
    local cfg = StorageAutoDriveConfig
    local infos = self:getObjectInfos(storage)
    if infos == nil then
        cfg:debug("OBJECTS", "Keine ObjectStorage-Infos vorhanden.")
        return nil, nil
    end

    -- ALL ist ausschließlich der interne Auftragssuchmodus.
    -- UNKNOWN bleibt davon getrennt und wird nicht automatisch zu ALL.
    if StorageAutoDriveUtils:isAllFillType(fillTypeIndex) then
        cfg:debug("OBJECTS", "ALL-Suche -> erstes verfügbares Objekt.")
        for index, info in ipairs(infos) do
            if info ~= nil
                and (info.numObjects or 0) > 0
                and info.objects ~= nil
                and info.objects[1] ~= nil then
                cfg:debug("OBJECTS", "UNKNOWN-Treffer: Gruppe=" .. tostring(index))
                return info, index
            end
        end
        return nil, nil
    end

    local wantedName = StorageAutoDriveUtils:getFillTypeName(fillTypeIndex)
    cfg:debug("OBJECTS", "Suche FillType=" .. tostring(fillTypeIndex) .. " (" .. tostring(wantedName) .. ")")

    -- 1) Echtes Objekt-FillType prüfen, falls ObjectStorage es liefert.
    for index, info in ipairs(infos) do
        if info ~= nil
            and (info.numObjects or 0) > 0
            and info.objects ~= nil
            and info.objects[1] ~= nil then
            local object = info.objects[1]
            local objectFillType = StorageAutoDriveUtils:getObjectFillType(object)

            cfg:debug("OBJECTS",
                "Prüfe Gruppe " .. tostring(index)
                .. " | FillType=" .. tostring(objectFillType)
                .. " (" .. StorageAutoDriveUtils:getFillTypeName(objectFillType) .. ")"
                .. " | Datei=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)))

            if objectFillType == fillTypeIndex then
                cfg:debug("OBJECTS", "EXAKTER FillType-Treffer: Gruppe=" .. tostring(index))
                return info, index
            end
        end
    end

    -- 2) GIANTS ObjectStorage meldet bei den gespeicherten Paletten oft
    --    UNKNOWN. Dann nutzen wir die vom FillType hinterlegte Objektdatei.
    --    Genau dadurch können Garlic/Tomatoes/Lettuce usw. sauber unterschieden
    --    werden, obwohl getFillType() am gespeicherten AbstractObject UNKNOWN ist.
    local wantedFiles = {}
    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if fillType ~= nil then
            local fields = {"palletFilename", "baleFilename", "filename"}
            for _, fieldName in ipairs(fields) do
                local value = fillType[fieldName]
                if value ~= nil and tostring(value) ~= "" then
                    table.insert(wantedFiles, tostring(value))
                    cfg:debug("OBJECTS", "FillType-Datei " .. fieldName .. "=" .. tostring(value))
                end
            end
        end
    end

    for index, info in ipairs(infos) do
        if info ~= nil
            and (info.numObjects or 0) > 0
            and info.objects ~= nil
            and info.objects[1] ~= nil then
            local filename = StorageAutoDriveUtils:getObjectFilename(info.objects[1])
            if filename ~= nil then
                local lowerFilename = string.lower(tostring(filename))
                for _, wantedFile in ipairs(wantedFiles) do
                    local lowerWantedFile = string.lower(tostring(wantedFile))
                    if lowerFilename == lowerWantedFile
                        or string.sub(lowerFilename, -#lowerWantedFile) == lowerWantedFile then
                        cfg:debug("OBJECTS",
                            "DATEI-Treffer für " .. tostring(wantedName)
                            .. ": Gruppe=" .. tostring(index)
                            .. " | " .. tostring(filename))
                        return info, index
                    end
                end
            end
        end
    end

    cfg:debug("OBJECTS", "Kein Objekt für FillType " .. tostring(wantedName) .. " gefunden.")
    return nil, nil
end

function StorageAutoDriveObjects:removeObjectFromStorage(storage, objectInfoIndex)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveObjects:removeObjectFromStorage")
    local cfg = StorageAutoDriveConfig
    cfg:heartbeat("OBJECTS", "remove object | group=" .. tostring(objectInfoIndex))
    if storage == nil or objectInfoIndex == nil then
        cfg:traceDecision("OBJECTS", "REMOVE_REJECTED_INVALID_ARGUMENT", "storage=" .. tostring(storage) .. " | group=" .. tostring(objectInfoIndex))
        return false
    end
    if storage.removeAbstractObjectsFromStorage == nil then
        cfg:traceDecision("OBJECTS", "REMOVE_REJECTED_NO_GIANTS_FUNCTION")
        cfg:error("Lager besitzt removeAbstractObjectsFromStorage nicht.")
        return false
    end
    cfg:debug("OBJECTS", "Entnehme Objektgruppe " .. tostring(objectInfoIndex) .. " aus dem ObjectStorage.")
    cfg:traceStorage("REMOVE CALL | storage=" .. tostring(storage) .. " | group=" .. tostring(objectInfoIndex) .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
    cfg:traceStorage("GIANTS STORAGE STATE BEFORE REMOVE | storage=" .. tostring(storage) .. " | group=" .. tostring(objectInfoIndex) .. " | " .. getStorageRequestDiagnostics(storage, objectInfoIndex) .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
    cfg:traceStorage("BEFORE GIANTS removeAbstractObjectsFromStorage | storage=" .. tostring(storage) .. " | group=" .. tostring(objectInfoIndex) .. " | count=1 | callbackArg=nil")
    local ok, result = pcall(function() return storage:removeAbstractObjectsFromStorage(objectInfoIndex, 1, nil) end)
    cfg:traceStorage("GIANTS STORAGE STATE AFTER REMOVE | storage=" .. tostring(storage) .. " | group=" .. tostring(objectInfoIndex) .. " | " .. getStorageRequestDiagnostics(storage, objectInfoIndex) .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
    if not ok then cfg:traceDecision("OBJECTS", "REMOVE_PCALL_FAILED", tostring(result)); cfg:error("Fehler beim Auslagern: " .. tostring(result)); return false end
    cfg:traceValue("OBJECTS", "GIANTS_REMOVE_RETURN=" .. tostring(result))
    cfg:traceDecision("OBJECTS", "REMOVE_PCALL_OK", "return=" .. tostring(result))
    cfg:debug("OBJECTS", "1 Objekt zur Auslagerung freigegeben.")
    cfg:traceStorage("REMOVE RESULT | storage=" .. tostring(storage) .. " | group=" .. tostring(objectInfoIndex) .. " | pcallOK=" .. tostring(ok) .. " | return=" .. tostring(result) .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
    return true
end

function StorageAutoDriveObjects:returnObjectToStorage(storage, object)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveObjects:returnObjectToStorage")
    local cfg = StorageAutoDriveConfig
    if storage == nil or object == nil then return false end
    if storage.addObjectToObjectStorage == nil then
        cfg:error("ObjectStorage besitzt addObjectToObjectStorage nicht.")
        return false
    end

    -- Genau die GIANTS-ObjectStorage-Logik verwenden, die auch die
    -- normale manuelle Ruecklagerung verwendet. Fremde Objekte werden
    -- hier niemals gesucht oder veraendert.
    if storage.getObjectStorageCanStoreObject ~= nil then
        local ok, canStore = pcall(function() return storage:getObjectStorageCanStoreObject(object, true) end)
        if not ok or not canStore then
            ok, canStore = pcall(function() return storage:getObjectStorageCanStoreObject(object, false) end)
            if not ok or not canStore then
                cfg:debug("OBJECTS", "Eigene Ueberhangspalette kann nicht ins ObjectStorage zurueck | Objekt=" .. tostring(object.id))
                return false
            end
        end
    end

    cfg:traceStorage("BEFORE GIANTS addObjectToObjectStorage | storage=" .. tostring(storage) .. " | object=" .. tostring(object and object.id) .. " | force=false")
    local ok, result = pcall(function()
        return storage:addObjectToObjectStorage(object, false)
    end)
    if not ok then
        cfg:traceDecision("OBJECTS", "RETURN_PCALL_FAILED", tostring(result))
        cfg:error("Fehler beim Zurueckfuehren ins ObjectStorage: " .. tostring(result))
        return false
    end

    cfg:traceStorage("ADD RESULT | storage=" .. tostring(storage) .. " | object=" .. tostring(object and object.id) .. " | pcallOK=" .. tostring(ok) .. " | return=" .. tostring(result))
    cfg:debug("OBJECTS", "Eigene Ueberhangspalette ins ObjectStorage zurueckgefuehrt | Objekt=" .. tostring(object.id))
    return true
end
