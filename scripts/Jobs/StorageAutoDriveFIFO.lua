StorageAutoDriveFIFO = {}
StorageAutoDriveFIFO.queue = {}
StorageAutoDriveFIFO.queued = {}
StorageAutoDriveFIFO.active = nil

function StorageAutoDriveFIFO:add(job)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveFIFO:add")
    StorageAutoDriveConfig:debug("FIFO", "ADD | Job=" .. tostring(job and job.id) .. " | vehicle=" .. tostring(job and job.vehicle and job.vehicle.id))
    if job == nil or job.vehicle == nil then return false end
    local key = job.vehicleUniqueId
    if self.queued[key] ~= nil or self.active == job then return false end
    self.queued[key] = job
    table.insert(self.queue, job)
    StorageAutoDriveConfig:debugRaw("FIFO", "QUEUE AFTER ADD | count=" .. tostring(#self.queue) .. " | active=" .. tostring(self.active and self.active.id) .. " | addedJob=" .. tostring(job.id) .. " | vehicleUID=" .. tostring(key))
    job.state = "QUEUED"
    StorageAutoDriveJobs:log(job, "FIFO_ADD")
    return true
end

function StorageAutoDriveFIFO:remove(vehicle)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveFIFO:remove")
    if vehicle == nil then return end
    local key = vehicle.getUniqueId ~= nil and vehicle:getUniqueId() or tostring(vehicle.id or vehicle)
    local job = self.queued[key]
    self.queued[key] = nil
    if job ~= nil then
        for i=#self.queue,1,-1 do
            if self.queue[i] == job then table.remove(self.queue,i) end
        end
        StorageAutoDriveJobs:cancel(job, "FIFO_REMOVE")
        StorageAutoDriveJobs:log(job, "FIFO_REMOVE")
    end
end

function StorageAutoDriveFIFO:promote()
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveFIFO:promote")
    StorageAutoDriveConfig:debug("FIFO", "PROMOTE | active=" .. tostring(self.active ~= nil) .. " | queue=" .. tostring(#self.queue))
    if self.active ~= nil then return self.active end
    StorageAutoDriveConfig:debugRaw("FIFO", "PROMOTE QUEUE CONTENTS | count=" .. tostring(#self.queue) .. " | active=" .. tostring(self.active and self.active.id))
    while #self.queue > 0 do
        local job = table.remove(self.queue, 1)
        self.queued[job.vehicleUniqueId] = nil
        if job.vehicle ~= nil and job.vehicle.ad ~= nil then
            self.active = job
            job.state = "EXTRACTING"
            job.startedAt = g_currentMission ~= nil and g_currentMission.time or 0
            StorageAutoDriveJobs:log(job, "FIFO_ACTIVE")
            return job
        else
            StorageAutoDriveJobs:cancel(job, "Fahrzeug nicht mehr vorhanden")
        end
    end
    return nil
end

function StorageAutoDriveFIFO:release(job)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveFIFO:release")
    StorageAutoDriveConfig:debug("FIFO", "RELEASE | Job=" .. tostring(job and job.id))
    if self.active == job then self.active = nil end
    StorageAutoDriveConfig:debugRaw("FIFO", "QUEUE AFTER RELEASE | count=" .. tostring(#self.queue) .. " | active=" .. tostring(self.active and self.active.id))
end

function StorageAutoDriveFIFO:contains(vehicle)
    StorageAutoDriveConfig:traceFunction("JOB", "StorageAutoDriveFIFO:contains")
    if vehicle == nil then return false end
    local key = vehicle.getUniqueId ~= nil and vehicle:getUniqueId() or tostring(vehicle.id or vehicle)
    return self.queued[key] ~= nil or (self.active ~= nil and self.active.vehicleUniqueId == key)
end
