StorageAutoDriveSession = {}
StorageAutoDriveSession.nextRuntimeId = 0

StorageAutoDriveSession.STATES = {
    WAITING = "WAITING",
    QUEUED = "QUEUED",
    EXTRACTING = "EXTRACTING",
    WAITING_FOR_LOAD = "WAITING_FOR_LOAD",
    WAITING_FOR_AD_FINISH = "WAITING_FOR_AD_FINISH",
    EMPTY_STORAGE = "EMPTY_STORAGE",
    COMPLETED = "COMPLETED",
    CLEANUP = "CLEANUP",
    DONE = "DONE",
    CANCELLED = "CANCELLED"
}

function StorageAutoDriveSession:new(job)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveSession:new")
    self.nextRuntimeId = (self.nextRuntimeId or 0) + 1
    local session = {
        runtimeId = self.nextRuntimeId,
        job = job,
        vehicle = job ~= nil and job.vehicle or nil,
        storage = job ~= nil and job.storage or nil,
        trailer = job ~= nil and job.trailer or nil,
        state = StorageAutoDriveSession.STATES.QUEUED,
        spawnedObjects = {},
        loadedObjects = {},
        pendingObjects = {},
        pendingKnownObjects = {},
        spawnedCount = 0,
        startedAt = g_currentMission ~= nil and g_currentMission.time or 0,
        lastStateChange = g_currentMission ~= nil and g_currentMission.time or 0,
        cleanupDone = false,
        persistenceDirty = true
    }
    StorageAutoDriveConfig:debug("SESSION", "NEW | RuntimeSession=" .. tostring(session.runtimeId) .. " | Job=" .. tostring(job and job.id) .. " | vehicle=" .. tostring(session.vehicle and session.vehicle.id) .. " | vehicleUID=" .. tostring(job and job.vehicleUniqueId) .. " | state=" .. tostring(session.state) .. " | time=" .. tostring(session.startedAt))
    return session
end

function StorageAutoDriveSession:setState(session, state, reason)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveSession:setState")
    if session == nil or session.state == state then return end
    local oldState = session.state
    StorageAutoDriveConfig:traceState("SESSION", "Job=" .. tostring(session.job and session.job.id) .. " | " .. tostring(session.state) .. " -> " .. tostring(state) .. " | reason=" .. tostring(reason))
    session.state = state
    session.lastStateChange = g_currentMission ~= nil and g_currentMission.time or 0
    session.lastReason = reason
    session.persistenceDirty = true
    StorageAutoDriveConfig:debug("SESSION",
        "Session-State: " .. tostring(oldState) .. " -> " .. tostring(state) .. " | Grund=" .. tostring(reason)
        .. " | Fahrzeug=" .. tostring(session.vehicle ~= nil and (session.vehicle.getUniqueId ~= nil and session.vehicle:getUniqueId() or session.vehicle.id) or "nil"))
end

function StorageAutoDriveSession:markDirty(session)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveSession:markDirty")
    if session ~= nil then session.persistenceDirty = true end
end

function StorageAutoDriveSession:markClean(session)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveSession:markClean")
    if session ~= nil then session.persistenceDirty = false end
end

function StorageAutoDriveSession:addSpawned(session, object)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveSession:addSpawned")
    if session == nil or object == nil then return end
    StorageAutoDriveConfig:debug("SESSION", "OWN SPAWNED | Job=" .. tostring(session.job and session.job.id) .. " | object=" .. tostring(object.id) .. " | file=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)))
    session.spawnedObjects[object] = {object=object, loaded=false, owned=true, spawnedAt=g_currentMission ~= nil and g_currentMission.time or 0}
    StorageAutoDriveConfig:debugRaw("SESSION", "OWN SPAWNED DETAILS | RuntimeSession=" .. tostring(session.runtimeId) .. " | objectRef=" .. tostring(object) .. " | objectId=" .. tostring(object.id) .. " | file=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)))
    session.persistenceDirty = true
end

function StorageAutoDriveSession:markLoaded(session, object)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveSession:markLoaded")
    if session == nil or object == nil then return false end
    StorageAutoDriveConfig:debug("SESSION", "MARK LOADED angefordert | Job=" .. tostring(session.job and session.job.id) .. " | object=" .. tostring(object.id))
    local entry = session.spawnedObjects[object]
    if entry == nil then
        return false
    end
    if not entry.loaded then
        entry.loaded = true
        session.loadedObjects[object] = entry
        session.persistenceDirty = true
        StorageAutoDriveConfig:debug("SESSION", "EIGENES OBJEKT VON UAL ALS GELADEN ERKANNT | RuntimeSession=" .. tostring(session.runtimeId) .. " | object=" .. tostring(object.id))
    end
    return true
end

function StorageAutoDriveSession:getOwnedUnloaded(session)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveSession:getOwnedUnloaded")
    local result = {}
    if session == nil then return result end
    for object, entry in pairs(session.spawnedObjects) do
        if entry ~= nil and entry.owned and not entry.loaded then
            result[#result+1] = object
        end
    end
    return result
end

function StorageAutoDriveSession:clearRuntimeReferences(session)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveSession:clearRuntimeReferences")
    if session == nil then return end
    StorageAutoDriveConfig:debug("SESSION", "CLEAR REFERENCES | RuntimeSession=" .. tostring(session.runtimeId) .. " | Job=" .. tostring(session.job and session.job.id) .. " | state=" .. tostring(session.state) .. " | spawned=" .. tostring(session.spawnedCount))
    session.vehicle = nil
    session.storage = nil
    session.trailer = nil
    session.pendingObject = nil
end
