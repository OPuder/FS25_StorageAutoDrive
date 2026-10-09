StorageAutoDriveVehicle = {}
StorageAutoDriveVehicle.sessions = {}
StorageAutoDriveVehicle.checks = {}

local function key(vehicle)
    if vehicle == nil then return nil end
    if vehicle.getUniqueId ~= nil then
        local ok,id=pcall(function() return vehicle:getUniqueId() end)
        if ok and id ~= nil then return tostring(id) end
    end
    return tostring(vehicle.id or vehicle)
end

function StorageAutoDriveVehicle:getSession(vehicle)
    StorageAutoDriveConfig:traceFunction("VEHICLE", "StorageAutoDriveVehicle:getSession")
    return self.sessions[key(vehicle)]
end

function StorageAutoDriveVehicle:getSessionForStorage(storage)
    StorageAutoDriveConfig:traceFunction("VEHICLE", "StorageAutoDriveVehicle:getSessionForStorage")
    for _, session in pairs(self.sessions) do
        if session.storage == storage then return session end
    end
    return nil
end

function StorageAutoDriveVehicle:registerJob(vehicle, storage)
    StorageAutoDriveConfig:traceFunction("VEHICLE", "StorageAutoDriveVehicle:registerJob")
    StorageAutoDriveConfig:debug("JOB", "registerJob | vehicle=" .. tostring(vehicle and vehicle.id) .. " | storage=" .. tostring(storage))
    if vehicle == nil or storage == nil then return end
    local k=key(vehicle)
    if self.sessions[k] ~= nil or StorageAutoDriveFIFO:contains(vehicle) then return end
    local job=StorageAutoDriveJobs:create(vehicle,storage)
    if job == nil then return end
    StorageAutoDriveFIFO:add(job)
end

function StorageAutoDriveVehicle:activateNext()
    StorageAutoDriveConfig:traceFunction("VEHICLE", "StorageAutoDriveVehicle:activateNext")
    StorageAutoDriveConfig:debug("FIFO", "activateNext() | active=" .. tostring(StorageAutoDriveFIFO.active ~= nil) .. " | queue=" .. tostring(#StorageAutoDriveFIFO.queue))
    local job=StorageAutoDriveFIFO:promote()
    if job == nil then return end
    local session=StorageAutoDriveSession:new(job)
    session.state=StorageAutoDriveSession.STATES.EXTRACTING
    session.trailer=job.trailer or StorageAutoDriveUAL:findTrailer(job.vehicle)
    session.spawnedCount = tonumber(job.spawned) or 0
    -- Savegame-Runtimezustände werden nicht blind übernommen. Die Session
    -- startet aus dem aktuell von AD/UAL beobachtbaren Zustand neu.
    session.state = StorageAutoDriveSession.STATES.EXTRACTING
    self.sessions[key(job.vehicle)]=session
    StorageAutoDriveConfig:debug("SESSION", "Session aktiviert | Job #"..tostring(job.id))
end

function StorageAutoDriveVehicle:updateSession(session)
    StorageAutoDriveConfig:traceFunction("VEHICLE", "StorageAutoDriveVehicle:updateSession")
    if session == nil or session.vehicle == nil then return end

    if session.job ~= nil and session.job.restoreWaitingForStorage then
        if StorageAutoDriveTaskState:isADFinished(session) then
            session.job.restoreWaitingForStorage = false
            StorageAutoDriveSession:setState(session, StorageAutoDriveSession.STATES.COMPLETED,
                "AD-Auftrag beendet, bevor das gespeicherte Lager erneut erreicht wurde")
        else
            local currentStorage = StorageAutoDriveStorage:getNearest(session.vehicle)
            if currentStorage ~= session.storage then
                StorageAutoDriveConfig:debugState("restoreStorage:" .. tostring(session.job.id), "PERSISTENCE",
                    "Wiederhergestellter Auftrag wartet auf gespeichertes Lager | Job=" .. tostring(session.job.id)
                    .. " | target=" .. tostring(StorageAutoDriveUtils:getStorageName(session.storage))
                    .. " | current=" .. tostring(currentStorage and StorageAutoDriveUtils:getStorageName(currentStorage)))
                return
            end
            session.job.restoreWaitingForStorage = false
            StorageAutoDriveConfig:debug("PERSISTENCE", "Gespeichertes Lager erneut erreicht; Auftrag wird fortgesetzt | Job=" .. tostring(session.job.id))
        end
    end

    if session.state == StorageAutoDriveSession.STATES.EMPTY_STORAGE then
        StorageAutoDriveEmptyStorage:update(session)
        if session.state ~= StorageAutoDriveSession.STATES.COMPLETED then
            if StorageAutoDriveConfig.VERBOSE then
                StorageAutoDriveAutoDrive:debug(session.vehicle)
            end
            return
        end
    end
    StorageAutoDriveConfig:debugState("session:" .. tostring(session.job and session.job.id), "SESSION",
        "Tick | Job=" .. tostring(session.job and session.job.id) .. " | state=" .. tostring(session.state) .. " | spawned=" .. tostring(session.spawnedCount) .. " | pending=" .. tostring(session.pendingObject and session.pendingObject.id) .. " | file=" .. tostring(session.pendingFilename))
    if session.state == StorageAutoDriveSession.STATES.EXTRACTING then
        if session.pendingObject == nil then
            if StorageAutoDriveSpawn:startNext(session) then return end
        end
    elseif session.state == StorageAutoDriveSession.STATES.WAITING_FOR_LOAD then
        StorageAutoDriveUAL:debug(session.trailer)
        StorageAutoDriveUAL:debugCollections(session.trailer, "vor Tracking:update")
        -- GIANTS ObjectStorage liefert das Objekt asynchron.
        -- pendingObject == nil bedeutet hier NICHT, dass der Spawn abgeschlossen ist.
        -- Solange der Callback noch nicht eingetroffen ist, bleibt die Session
        -- bewusst in WAITING_FOR_LOAD und darf keinen weiteren Spawn anfordern.
        StorageAutoDriveTracking:update(session)

        -- AD kann den Auftrag bereits beendet haben, obwohl die von uns
        -- zusaetzlich angeforderte letzte Storage-Palette noch nicht geladen
        -- wurde. Diese Palette gehoert trotzdem eindeutig zu unserer Session
        -- und muss beim Cleanup ueber die GIANTS-ObjectStorage-Logik
        -- zurueckgefuehrt werden. Wir warten in diesem Fall nicht auf einen
        -- UAL-Load-Callback, der fuer diese Ueberhangspalette nicht mehr kommt.
        if StorageAutoDriveTaskState:isADFinished(session) then
            StorageAutoDriveSession:setState(session, StorageAutoDriveSession.STATES.COMPLETED,
                "AD-Auftrag beendet waehrend WAITING_FOR_LOAD; offene eigene Ueberhangspalette wird zurueckgefuehrt")
        end
    end
    StorageAutoDriveTaskState:update(session)
    if StorageAutoDriveConfig.VERBOSE then
        StorageAutoDriveAutoDrive:debug(session.vehicle)
    end

    if session.state == StorageAutoDriveSession.STATES.WAITING_FOR_AD_FINISH then
        if StorageAutoDriveTaskState:isADFinished(session) then
            StorageAutoDriveSession:setState(session, StorageAutoDriveSession.STATES.COMPLETED, "AD hat Auftrag beendet")
        end
    end

    if session.state == StorageAutoDriveSession.STATES.COMPLETED then
        local sessionKey = key(session.vehicle)
        local job = session.job
        local reason = session.lastReason or "Auftrag abgeschlossen"

        -- Cleanup zuerst: eigene, noch nicht geladene Objekte werden ueber
        -- die GIANTS-ObjectStorage-Logik zurueckgefuehrt. Erst danach gilt
        -- die Session als beendet. AD und UAL werden dabei nicht gesteuert.
        StorageAutoDriveCleanup:finish(session, reason)

        StorageAutoDriveJobs:finish(job, reason)
        StorageAutoDriveJobs:log(job, "COMPLETED")
        StorageAutoDriveFIFO:release(job)
        StorageAutoDriveJobs:remove(job)

        -- Erst ganz am Ende alle Session-Referenzen freigeben, damit Cleanup
        -- noch auf Fahrzeug, Storage und Trailer zugreifen kann.
        StorageAutoDriveSession:clearRuntimeReferences(session)
        session.job = nil
        self.sessions[sessionKey] = nil
    end
end

function StorageAutoDriveVehicle:update(dt)
    StorageAutoDriveConfig:traceFunction("VEHICLE", "StorageAutoDriveVehicle:update")
    StorageAutoDriveConfig:trace("TRACE_VEHICLE_SCAN", "VEHICLE", "UPDATE | dt=" .. tostring(dt) .. " | vehicles=" .. tostring(g_currentMission and g_currentMission.vehicleSystem and #g_currentMission.vehicleSystem.vehicles or 0))
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then return end
    if StorageAutoDriveFIFO.active == nil then self:activateNext() end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles or {}) do
        local root=StorageAutoDriveUtils:getRootVehicle(vehicle)
        if root == vehicle and root.ad ~= nil then
            local storage=StorageAutoDriveStorage:getNearest(root)
            local session=self:getSession(root)
            local standing=(tonumber(root.lastSpeedReal) or 0) < StorageAutoDriveConfig.VEHICLE_STANDING_SPEED
            local pickup=StorageAutoDriveAutoDrive:isPickup(root)
            StorageAutoDriveConfig:debugRaw("UPDATE", "VEHICLE SCAN | id=" .. tostring(root.id) .. " | uid=" .. tostring(key(root)) .. " | speed=" .. tostring(root.lastSpeedReal) .. " | standing=" .. tostring(standing) .. " | pickup=" .. tostring(pickup) .. " | mode=" .. tostring(StorageAutoDriveAutoDrive:getTaskModeName(root)) .. " | storage=" .. tostring(storage and StorageAutoDriveUtils:getStorageName(storage)) .. " | session=" .. tostring(session and session.job and session.job.id) .. " | FIFOqueued=" .. tostring(StorageAutoDriveFIFO:contains(root)) .. " | time=" .. tostring(g_currentMission.time))
            if session ~= nil then
                if session.storage ~= nil then storage=session.storage end
                self:updateSession(session)
            elseif storage ~= nil then
                if standing and pickup then self:registerJob(root,storage) end
            end
        end
    end
    if StorageAutoDriveFIFO.active == nil then self:activateNext() end
    StorageAutoDriveConfig:debugRaw("UPDATE", "VEHICLE UPDATE END | activeJob=" .. tostring(StorageAutoDriveFIFO.active and StorageAutoDriveFIFO.active.id) .. " | queue=" .. tostring(#StorageAutoDriveFIFO.queue) .. " | sessions=" .. tostring(StorageAutoDriveUtils:getTableCount(self.sessions)) .. " | time=" .. tostring(g_currentMission.time))
end

function StorageAutoDriveVehicle:onObjectStorageSpawned(storage,object)
    StorageAutoDriveConfig:traceFunction("VEHICLE", "StorageAutoDriveVehicle:onObjectStorageSpawned")
    StorageAutoDriveSpawn:onObjectStorageSpawned(storage,object)
end

function StorageAutoDriveVehicle:reset()
    StorageAutoDriveConfig:traceFunction("VEHICLE", "StorageAutoDriveVehicle:reset")
    self.sessions={}
    StorageAutoDriveFIFO.queue={}
    StorageAutoDriveFIFO.queued={}
    StorageAutoDriveFIFO.active=nil
    StorageAutoDriveJobs.jobsByVehicle={}
end
