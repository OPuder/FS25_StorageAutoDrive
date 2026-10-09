StorageAutoDriveJobs = {}
StorageAutoDriveJobs.jobsByVehicle = {}
StorageAutoDriveJobs.nextId = 0

local function vehicleKey(vehicle)
    if vehicle == nil then return nil end
    if vehicle.getUniqueId ~= nil then
        local ok, id = pcall(function() return vehicle:getUniqueId() end)
        if ok and id ~= nil then return tostring(id) end
    end
    return tostring(vehicle.id or vehicle)
end

function StorageAutoDriveJobs:create(vehicle, storage)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveJobs:create")
    StorageAutoDriveConfig:debug("JOB", "create | vehicle=" .. tostring(vehicle and vehicle.id) .. " | storage=" .. tostring(storage))
    if vehicle == nil or storage == nil then return nil end
    local existing = self.jobsByVehicle[vehicleKey(vehicle)]
    if existing ~= nil and existing.state ~= "FINISHED" and existing.state ~= "CANCELLED" then
        return existing
    end
    self.nextId = self.nextId + 1
    local trailer = StorageAutoDriveUAL:findTrailer(vehicle)
    local orderFillType, rawFillType, isAllOrder = StorageAutoDriveAutoDrive:getOrderFillType(vehicle)
    StorageAutoDriveConfig:debugRaw("JOB", "CREATE DETAILS | vehicle=" .. tostring(vehicle.id) .. " | uid=" .. tostring(vehicleKey(vehicle)) .. " | storage=" .. tostring(StorageAutoDriveUtils:getStorageName(storage)) .. " | trailer=" .. tostring(trailer and trailer.id) .. " | rawFillType=" .. tostring(rawFillType) .. " | orderFillType=" .. tostring(orderFillType) .. " | orderMode=" .. tostring(isAllOrder and "ALL" or "SPECIFIC") .. " | mode=" .. tostring(StorageAutoDriveAutoDrive:getTaskModeName(vehicle)))
    local job = {
        id=self.nextId,
        vehicle=vehicle,
        vehicleUniqueId=vehicleKey(vehicle),
        storage=storage,
        trailer=trailer,
        fillType=orderFillType,
        requestedFillType=rawFillType,
        isAllOrder=isAllOrder,
        state="QUEUED",
        spawned=0,
        queuedAt=g_currentMission ~= nil and g_currentMission.time or 0,
        startedAt=nil,
        finishedAt=nil,
        finishReason=nil,
        restored=false
    }
    self.jobsByVehicle[job.vehicleUniqueId] = job
    return job
end

function StorageAutoDriveJobs:get(vehicle)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveJobs:get")
    if vehicle == nil then return nil end
    return self.jobsByVehicle[vehicleKey(vehicle)]
end

function StorageAutoDriveJobs:finish(job, reason)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveJobs:finish")
    if job == nil then return end
    StorageAutoDriveConfig:debug(
        "JOB",
        "finish | Job=" .. tostring(job.id)
        .. " | reason=" .. tostring(reason)
        .. " | spawned=" .. tostring(job.spawned)
    )
    job.state = "FINISHED"
    job.finishedAt = g_currentMission ~= nil and g_currentMission.time or 0
    job.finishReason = reason
end

function StorageAutoDriveJobs:cancel(job, reason)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveJobs:cancel")
    if job == nil then return end
    job.state = "CANCELLED"
    job.finishedAt = g_currentMission ~= nil and g_currentMission.time or 0
    job.finishReason = reason
end

function StorageAutoDriveJobs:remove(job)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveJobs:remove")
    if job == nil then return end
    if job.vehicleUniqueId ~= nil and self.jobsByVehicle[job.vehicleUniqueId] == job then
        self.jobsByVehicle[job.vehicleUniqueId] = nil
    end
end

function StorageAutoDriveJobs:log(job, reason)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveJobs:log")
    if job == nil then return end
    StorageAutoDriveConfig:debug("JOB",
        "Job #" .. tostring(job.id)
        .. " | state=" .. tostring(job.state)
        .. " | vehicle=" .. tostring(job.vehicleUniqueId)
        .. " | fillType=" .. tostring(job.fillType)
        .. " | requestedFillType=" .. tostring(job.requestedFillType)
        .. " | orderMode=" .. tostring(job.isAllOrder == true and "ALL" or "SPECIFIC")
        .. " | spawned=" .. tostring(job.spawned)
        .. " | reason=" .. tostring(reason))
end
