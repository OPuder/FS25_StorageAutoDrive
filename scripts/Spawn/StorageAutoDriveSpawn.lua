StorageAutoDriveSpawn = {}

function StorageAutoDriveSpawn:findObject(job)
    StorageAutoDriveConfig:traceFunction("SPAWN", "StorageAutoDriveSpawn:findObject")
    if job ~= nil and job.baleSelection ~= nil then
        return StorageAutoDriveObjects:findObjectInfoForBaleSelection(job.storage, job.baleSelection)
    end
    return StorageAutoDriveObjects:findObjectInfoForFillType(job.storage, job.fillType)
end

function StorageAutoDriveSpawn:startNext(session)
    StorageAutoDriveConfig:traceFunction("SPAWN", "StorageAutoDriveSpawn:startNext")
    if session == nil then
        StorageAutoDriveConfig:traceDecision("SPAWN", "ABGELEHNT_SESSION_NIL")
        StorageAutoDriveConfig:debug("SPAWN", "startNext ABGELEHNT: session=nil")
        return false
    end
    StorageAutoDriveConfig:debug("SPAWN", "startNext | Job=" .. tostring(session.job and session.job.id) .. " | State=" .. tostring(session.state) .. " | spawned=" .. tostring(session.spawnedCount) .. " | pending=" .. tostring(session.pendingObject ~= nil) .. " | pendingFile=" .. tostring(session.pendingFilename))
    if session.storage == nil or session.trailer == nil then
        StorageAutoDriveConfig:traceDecision("SPAWN", "ABGELEHNT_STORAGE_ODER_TRAILER_FEHLT")
        StorageAutoDriveConfig:traceValue("SPAWN", "storage=" .. tostring(session.storage) .. " | trailer=" .. tostring(session.trailer))
        StorageAutoDriveConfig:error("SPAWN: startNext ABGELEHNT: Storage oder Trailer fehlt")
        return false
    end
    if session.pendingObject ~= nil or session.pendingFilename ~= nil then
        StorageAutoDriveConfig:traceDecision("SPAWN", "WAIT_PENDING_AKTIV", "pendingObject=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | pendingFile=" .. tostring(session.pendingFilename))
        StorageAutoDriveConfig:debug("SPAWN", "Kein neuer Spawn: Pending-Objekt/Datei noch aktiv.")
        return false
    end

    -- GIANTS lehnt removeAbstractObjectsFromStorage ab, solange die
    -- ObjectStorage-Infos noch aktualisiert werden (objectInfosUpdateTimer ~= 0).
    -- Der Timer startet nach Abschluss der vorherigen Ausgabe; unser Intervall
    -- ab dem Request allein kann deshalb wenige Millisekunden zu kurz sein.
    local storageSpec = session.storage.spec_objectStorage
    local infosTimer = storageSpec ~= nil and storageSpec.objectInfosUpdateTimer or nil
    if infosTimer ~= nil and infosTimer ~= 0 then
        StorageAutoDriveConfig:traceDecision("SPAWN", "WAIT_STORAGE_INFOS_UPDATE",
            "Job=" .. tostring(session.job and session.job.id)
            .. " | objectInfosUpdateTimer=" .. tostring(infosTimer))
        StorageAutoDriveConfig:debugRaw("SPAWN",
            "ObjectStorage noch nicht bereit | Job=" .. tostring(session.job and session.job.id)
            .. " | objectInfosUpdateTimer=" .. tostring(infosTimer)
            .. " ms | warte auf GIANTS-Update")
        return false
    end

    -- GIANTS ObjectStorage spawnt asynchron. Auch wenn der vorherige
    -- Callback bereits eingetroffen ist, darf der nächste remove-Aufruf
    -- nicht direkt im folgenden Tick erfolgen. Das Storage-System braucht
    -- einen kurzen Abstand zwischen zwei Auslagerungen. Ohne diese Pause
    -- kann ein Spawn verloren gehen und der Auftrag bleibt mit pending=nil
    -- dauerhaft in WAITING_FOR_LOAD hängen.
    local now = g_currentMission ~= nil and g_currentMission.time or 0
    local spawnInterval = tonumber(StorageAutoDriveConfig.SPAWN_INTERVAL_MS) or 1000
    if session.lastSpawnAt ~= nil then
        local elapsed = now - session.lastSpawnAt
        if elapsed < spawnInterval then
            StorageAutoDriveConfig:traceDecision("SPAWN", "WAIT_SPAWN_INTERVAL", "elapsed=" .. tostring(elapsed) .. " | required=" .. tostring(spawnInterval))
            StorageAutoDriveConfig:debugRaw("SPAWN",
                "Spawn-Intervall aktiv | Job=" .. tostring(session.job and session.job.id)
                .. " | elapsed=" .. tostring(elapsed)
                .. " ms | required=" .. tostring(spawnInterval)
                .. " ms")
            return false
        end
    end

    local ualFull = StorageAutoDriveUAL:isFull(session.trailer)
    StorageAutoDriveConfig:traceValue("SPAWN", "UAL full=" .. tostring(ualFull))
    if ualFull then
        StorageAutoDriveConfig:traceDecision("SPAWN", "WAIT_UAL_FULL")
        StorageAutoDriveSession:setState(session, StorageAutoDriveSession.STATES.WAITING_FOR_AD_FINISH, "UAL meldet voll")
        return false
    end
    local info, index = self:findObject(session.job)
    local requestedFillType = session.job and session.job.requestedFillType or nil
    local orderMode = session.job and session.job.isAllOrder == true and "ALL" or "SPECIFIC"
    StorageAutoDriveConfig:debug("SPAWN", "Storage-Suche | mode=" .. tostring(orderMode) .. " | requestedFillType=" .. tostring(requestedFillType) .. " | searchFillType=" .. tostring(session.job and session.job.fillType) .. " | baleSelection=" .. tostring(session.job and session.job.baleSelection and (session.job.baleSelection.fillTypeName .. "/" .. session.job.baleSelection.shape .. "/wrap=" .. tostring(session.job.baleSelection.wrapRequirement)) or "none") .. " | Gruppe=" .. tostring(index) .. " | Anzahl=" .. tostring(info and info.numObjects))
    if info == nil or index == nil then
        StorageAutoDriveConfig:traceDecision("SPAWN", "NO_STORAGE_OBJECT")
        StorageAutoDriveEmptyStorage:begin(session, "Lager liefert aktuell keine passende Palette")
        return false
    end
    local object = info.objects ~= nil and info.objects[1] or nil
    local filename = StorageAutoDriveUtils:getObjectFilename(object)
    StorageAutoDriveConfig:debug("SPAWN", "SELECTED OBJECT | mode=" .. tostring(orderMode) .. " | requestedFillType=" .. tostring(requestedFillType) .. " | selectedFillType=" .. tostring(StorageAutoDriveUtils:getObjectFillType(object)) .. " | Gruppe=" .. tostring(index) .. " | Objekt=" .. tostring(object and object.id) .. " | Typ=" .. StorageAutoDriveUtils:getObjectType(object) .. " | Datei=" .. tostring(filename))
    -- Vor dem asynchronen GIANTS-Spawn merken wir uns alle bereits bei UAL
    -- sichtbaren Objekte. Falls der GIANTS-Callback ausbleibt, darf die
    -- Tracking-Schicht später nur ein wirklich NEU erschienenes Objekt
    -- übernehmen. Bereits vorhandene Paletten bleiben damit unangetastet.
    session.pendingKnownObjects = {}
    local trailerSpec = session.trailer ~= nil and session.trailer.spec_universalAutoload or nil
    if trailerSpec ~= nil then
        for knownObject in pairs(trailerSpec.loadedObjects or {}) do
            session.pendingKnownObjects[knownObject] = true
        end
        for knownObject in pairs(trailerSpec.availableObjects or {}) do
            session.pendingKnownObjects[knownObject] = true
        end
    end

    -- Session/Tracking wird VOR dem GIANTS-Spawn angelegt, weil der Callback synchron eintreffen kann.
    session.pendingObject = nil
    session.pendingFilename = filename
    session.pendingSince = g_currentMission ~= nil and g_currentMission.time or 0
    StorageAutoDriveConfig:debugRaw("SPAWN", "BEFORE REMOVE | Job=" .. tostring(session.job and session.job.id) .. " | RuntimeSession=" .. tostring(session.runtimeId) .. " | group=" .. tostring(index) .. " | candidate=" .. tostring(object and object.id) .. " | candidateRef=" .. tostring(object) .. " | file=" .. tostring(filename) .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
    StorageAutoDriveConfig:traceDecision("SPAWN", "REMOVE_REQUEST", "group=" .. tostring(index) .. " | filename=" .. tostring(filename))
    local ok = StorageAutoDriveObjects:removeObjectFromStorage(session.storage, index)
    StorageAutoDriveConfig:traceValue("SPAWN", "REMOVE_REQUEST_RESULT=" .. tostring(ok))
    if not ok then
        StorageAutoDriveConfig:error("SPAWN: removeObjectFromStorage fehlgeschlagen | Job=" .. tostring(session.job and session.job.id))
        return false
    end
    StorageAutoDriveConfig:debug("SPAWN", "removeObjectFromStorage erfolgreich zurückgegeben; warte auf GIANTS-Spawn-Callback.")
    StorageAutoDriveConfig:debugRaw("SPAWN", "AFTER REMOVE | Job=" .. tostring(session.job and session.job.id) .. " | pendingObject=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | pendingFile=" .. tostring(session.pendingFilename) .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
    session.lastSpawnAt = now
    StorageAutoDriveConfig:traceDecision("SPAWN", "REMOVE_ACCEPTED_WAIT_CALLBACK", "filename=" .. tostring(filename))
    session.spawnedCount = session.spawnedCount + 1
    session.job.spawned = session.spawnedCount
    session.state = StorageAutoDriveSession.STATES.WAITING_FOR_LOAD
    StorageAutoDriveSession:markDirty(session)
    StorageAutoDriveConfig:debug("SPAWN", "Storage-Ausgabe gestartet | Nr=" .. tostring(session.spawnedCount) .. " | Datei=" .. tostring(filename))
    return true
end

function StorageAutoDriveSpawn:onObjectStorageSpawned(storage, object)
    StorageAutoDriveConfig:traceFunction("SPAWN", "StorageAutoDriveSpawn:onObjectStorageSpawned")
    StorageAutoDriveConfig:debug("CALLBACK", "GIANTS onObjectFromStorageSpawned | storage=" .. tostring(storage) .. " | object=" .. tostring(object and object.id) .. " | file=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)))
    if storage == nil or object == nil then
        StorageAutoDriveConfig:traceDecision("CALLBACK", "IGNORED_INVALID_CALLBACK", "storage=" .. tostring(storage) .. " | object=" .. tostring(object))
        return
    end
    local session = StorageAutoDriveVehicle:getSessionForStorage(storage)
    if session == nil then
        StorageAutoDriveConfig:traceDecision("CALLBACK", "IGNORED_NO_SESSION")
        StorageAutoDriveConfig:debug("CALLBACK", "Spawn-Callback keinem aktiven StorageAutoDrive-Auftrag zugeordnet.")
        return
    end
    local filename = StorageAutoDriveUtils:getObjectFilename(object)
    local matches = session.pendingFilename == nil or filename == nil or string.lower(tostring(filename)) == string.lower(tostring(session.pendingFilename))
    StorageAutoDriveConfig:debugRaw("CALLBACK", "CALLBACK RAW | Job=" .. tostring(session.job and session.job.id) .. " | RuntimeSession=" .. tostring(session.runtimeId) .. " | objectRef=" .. tostring(object) .. " | objectId=" .. tostring(object.id) .. " | callbackFile=" .. tostring(filename) .. " | pendingRef=" .. tostring(session.pendingObject) .. " | pendingId=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | pendingFile=" .. tostring(session.pendingFilename) .. " | fileMatch=" .. tostring(matches) .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
    StorageAutoDriveConfig:debug("CALLBACK", "Callback-Prüfung | Job=" .. tostring(session.job and session.job.id) .. " | pendingFile=" .. tostring(session.pendingFilename) .. " | callbackFile=" .. tostring(filename) .. " | match=" .. tostring(matches) .. " | state=" .. tostring(session.state))
    if matches then
        StorageAutoDriveConfig:traceDecision("CALLBACK", "ACCEPT_CALLBACK", "object=" .. tostring(object.id) .. " | file=" .. tostring(filename))
        session.pendingObject = object
        StorageAutoDriveSession:addSpawned(session, object)
        StorageAutoDriveTracking:beginPending(session, object, filename)
        StorageAutoDriveConfig:debug("SPAWN", "GIANTS-Spawn dem aktuellen Auftrag zugeordnet | Datei=" .. tostring(filename) .. " | pendingObject=" .. tostring(session.pendingObject and session.pendingObject.id))
    else
        StorageAutoDriveConfig:traceDecision("CALLBACK", "REJECT_CALLBACK_FILENAME_MISMATCH", "pending=" .. tostring(session.pendingFilename) .. " | callback=" .. tostring(filename))
        StorageAutoDriveConfig:debug("CALLBACK", "GIANTS-Spawn NICHT übernommen: Filename passt nicht zum Pending.")
    end
end
