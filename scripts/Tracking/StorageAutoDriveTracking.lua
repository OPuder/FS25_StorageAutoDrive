StorageAutoDriveTracking = {}

local function sameFilename(a,b)
    if a == nil or b == nil then return false end
    local aa,bb=string.lower(tostring(a)),string.lower(tostring(b))
    return aa==bb or string.sub(aa,-#bb)==bb or string.sub(bb,-#aa)==aa
end

local function objectMatches(session, object)
    if session == nil or object == nil then return false end

    -- Ein Storage-Spawn ist asynchron. Solange der GIANTS-Callback noch
    -- kein konkretes Objekt gesetzt hat, darf ein bereits vorhandenes UAL-
    -- Objekt niemals anhand von Datei oder FillType als neue Spawn-Palette
    -- erkannt werden. Genau das hat zuvor zu mehrfachen Spawns geführt.
    if session.pendingObject == nil then
        return false
    end

    -- Ab hier zählt ausschließlich die Objektidentität des aktuellen Spawns.
    return session.pendingObject == object
end

function StorageAutoDriveTracking:beginPending(session, object, filename)
    StorageAutoDriveConfig:traceFunction("TRACKING", "StorageAutoDriveTracking:beginPending")
    StorageAutoDriveConfig:debug("TRACKING", "beginPending | Job=" .. tostring(session and session.job and session.job.id) .. " | object=" .. tostring(object and object.id) .. " | file=" .. tostring(filename))
    session.pendingObject = object
    session.pendingFilename = filename
    session.pendingSince = g_currentMission ~= nil and g_currentMission.time or 0
    session.state = "WAITING_FOR_LOAD"
    StorageAutoDriveSession:markDirty(session)
end

function StorageAutoDriveTracking:update(session)
    StorageAutoDriveConfig:traceFunction("TRACKING", "StorageAutoDriveTracking:update")
    if session == nil then
        StorageAutoDriveConfig:traceDecision("TRACKING", "UPDATE_NO_SESSION")
        return false
    end
    if session.trailer == nil or session.pendingFilename == nil then
        StorageAutoDriveConfig:traceDecision("TRACKING", "UPDATE_NOT_READY", "trailer=" .. tostring(session.trailer) .. " | pendingFile=" .. tostring(session.pendingFilename))
        StorageAutoDriveConfig:debug("TRACKING", "update übersprungen | trailer=" .. tostring(session.trailer ~= nil) .. " | pendingFile=" .. tostring(session.pendingFilename))
        return false
    end
    local trailer = session.trailer
    local spec = trailer.spec_universalAutoload
    if spec == nil then
        StorageAutoDriveConfig:error("TRACKING: Trailer besitzt keine spec_universalAutoload")
        return false
    end
    local availableCount = StorageAutoDriveUtils:getTableCount(spec.availableObjects)
    local age = session.pendingSince ~= nil and ((g_currentMission and g_currentMission.time or 0) - session.pendingSince) or nil
    StorageAutoDriveConfig:debugState("track:" .. tostring(session.job and session.job.id), "TRACKING",
        "Pending-Status | Job=" .. tostring(session.job and session.job.id) .. " | state=" .. tostring(session.state) .. " | object=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | file=" .. tostring(session.pendingFilename) .. " | UAL.available=" .. tostring(availableCount) .. " | age=" .. tostring(age))

    -- Falls der GIANTS-Callback ausgeblieben ist, kann UAL das neue Objekt
    -- trotzdem bereits in seinen normalen Collections führen. Wir übernehmen
    -- hier ausschließlich ein Objekt, das
    --   1. denselben Dateinamen wie der aktuelle Spawn besitzt und
    --   2. vor dem Spawn noch NICHT in UAL vorhanden war.
    -- Damit kann eine bereits vorhandene Palette niemals erneut als eigener
    -- Spawn gezählt werden. AD und UAL werden dabei nicht verändert.
    local knownObjects = session.pendingKnownObjects or {}
    local function discoverMissedSpawn(collection, collectionName)
        for object in pairs(collection or {}) do
            local isKnown = knownObjects[object] == true
            local filename = StorageAutoDriveUtils:getObjectFilename(object)
            local sameFile = sameFilename(filename, session.pendingFilename)
            if not isKnown and sameFile then
                session.pendingObject = object
                StorageAutoDriveConfig:debug("CALLBACK",
                    "Spawn-Callback offenbar verpasst | neues UAL-Objekt ueber Polling gefunden | Sammlung=" .. tostring(collectionName)
                    .. " | object=" .. tostring(object and object.id)
                    .. " | file=" .. tostring(filename))
                StorageAutoDriveConfig:debugRaw("CALLBACK",
                    "MISSED SPAWN DISCOVERY | Job=" .. tostring(session.job and session.job.id)
                    .. " | objectRef=" .. tostring(object)
                    .. " | objectId=" .. tostring(object and object.id)
                    .. " | pendingFile=" .. tostring(session.pendingFilename)
                    .. " | callbackFile=" .. tostring(filename)
                    .. " | collection=" .. tostring(collectionName)
                    .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
                return object
            end
        end
        return nil
    end

    if session.pendingObject == nil then
        local discovered = discoverMissedSpawn(spec.loadedObjects, "loadedObjects")
        if discovered ~= nil then
            StorageAutoDriveSession:addSpawned(session, discovered)
            StorageAutoDriveSession:markLoaded(session, discovered)
            session.pendingObject = nil
            session.pendingFilename = nil
            session.pendingSince = nil
            session.pendingKnownObjects = {}
            session.state = "EXTRACTING"
            StorageAutoDriveConfig:debug("TRACKING",
                "Verpasster Spawn direkt als geladen erkannt | spawned=" .. tostring(session.spawnedCount))
            return true
        end

        local availableDiscovered = discoverMissedSpawn(spec.availableObjects, "availableObjects")
        if availableDiscovered ~= nil then
            StorageAutoDriveSession:addSpawned(session, availableDiscovered)
            StorageAutoDriveConfig:debug("TRACKING",
                "Verpasster Spawn in UAL.availableObjects gefunden | object=" .. tostring(availableDiscovered.id)
                .. " | warte auf normale UAL-Uebernahme.")
        end
    end

    for object in pairs(spec.loadedObjects or {}) do
        local exact = session.pendingObject ~= nil and object == session.pendingObject
        local sameFile = sameFilename(StorageAutoDriveUtils:getObjectFilename(object), session.pendingFilename)
        local sameFill = session.job ~= nil and session.job.fillType ~= nil and not StorageAutoDriveUtils:isUnknownFillType(session.job.fillType) and StorageAutoDriveUtils:getObjectFillType(object) == session.job.fillType
        StorageAutoDriveConfig:debugRaw("TRACKING", "LOADED CANDIDATE | Job=" .. tostring(session.job and session.job.id) .. " | object=" .. tostring(object and object.id) .. " | ref=" .. tostring(object) .. " | exactPending=" .. tostring(exact) .. " | sameFile=" .. tostring(sameFile) .. " | sameFill=" .. tostring(sameFill) .. " | pending=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | pendingFile=" .. tostring(session.pendingFilename))
        StorageAutoDriveConfig:traceValue("TRACKING", "CHECK_LOADED object=" .. tostring(object and object.id) .. " | pending=" .. tostring(session.pendingObject and session.pendingObject.id))
        if objectMatches(session, object) then
            StorageAutoDriveConfig:debug("TRACKING", "MATCH in UAL.loadedObjects | object=" .. tostring(object and object.id) .. " | pending=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | file=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)))
            StorageAutoDriveSession:markLoaded(session, object)
            session.pendingObject = nil
            session.pendingFilename = nil
            session.pendingSince = nil
            session.pendingKnownObjects = {}
            session.state = "EXTRACTING"
            StorageAutoDriveConfig:debug("TRACKING", "Eigene Storage-Palette laut UAL.loadedObjects geladen. | ACHTUNG: dies ist nur die UAL-Statusmeldung zur eigenen Pending-Palette.")
            return true
        end
    end

    -- UAL may expose the exact object in availableObjects before it moves it to loadedObjects.
    for object in pairs(spec.availableObjects or {}) do
        local exact = session.pendingObject ~= nil and object == session.pendingObject
        local sameFile = sameFilename(StorageAutoDriveUtils:getObjectFilename(object), session.pendingFilename)
        local sameFill = session.job ~= nil and session.job.fillType ~= nil and not StorageAutoDriveUtils:isUnknownFillType(session.job.fillType) and StorageAutoDriveUtils:getObjectFillType(object) == session.job.fillType
        StorageAutoDriveConfig:debugRaw("TRACKING", "AVAILABLE CANDIDATE | Job=" .. tostring(session.job and session.job.id) .. " | object=" .. tostring(object and object.id) .. " | ref=" .. tostring(object) .. " | exactPending=" .. tostring(exact) .. " | sameFile=" .. tostring(sameFile) .. " | sameFill=" .. tostring(sameFill) .. " | pending=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | pendingFile=" .. tostring(session.pendingFilename))
        StorageAutoDriveConfig:traceValue("TRACKING", "CHECK_LOADED object=" .. tostring(object and object.id) .. " | pending=" .. tostring(session.pendingObject and session.pendingObject.id))
        if objectMatches(session, object) then
            session.pendingObject = object
            StorageAutoDriveConfig:debug("TRACKING", "Pending-Objekt in UAL.availableObjects | object=" .. tostring(object and object.id) .. " | file=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)) .. " | warte auf loadedObjects.")
            return false
        end
    end
    StorageAutoDriveConfig:debugRaw("TRACKING", "NO MATCH | Job=" .. tostring(session.job and session.job.id) .. " | pendingObject=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | pendingFile=" .. tostring(session.pendingFilename) .. " | age=" .. tostring(age) .. " | spawnedCount=" .. tostring(session.spawnedCount))
    if StorageAutoDriveConfig.VERBOSE and age ~= nil and age >= (StorageAutoDriveConfig.PENDING_EXTRACTION_TIMEOUT_MS or 15000) then
        StorageAutoDriveConfig:debug("TRACKING", "WARNUNG: Pending wartet länger als Timeout | age=" .. tostring(age) .. " ms | Job=" .. tostring(session.job and session.job.id))
    end
    return false
end


function StorageAutoDriveTracking:adFinished(session)
    StorageAutoDriveConfig:traceFunction("TRACKING", "StorageAutoDriveTracking:adFinished")
    if session == nil or session.vehicle == nil then return true end
    return StorageAutoDriveAutoDrive:hasTaskFinished(session.vehicle)
end
