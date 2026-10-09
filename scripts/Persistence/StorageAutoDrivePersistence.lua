StorageAutoDrivePersistence = {}
StorageAutoDrivePersistence.FILE_NAME = "StorageAutoDriveSessions.xml"
StorageAutoDrivePersistence.pending = {}
StorageAutoDrivePersistence.hookInstalled = false

-- Eigene Schema-Definition ist erforderlich, damit XMLFile.load() die
-- gespeicherten Sessiondaten nach einem Savegame-Neuladen lesen kann.
StorageAutoDrivePersistence.xmlSchema = XMLSchema.new("storageAutoDriveSessions")
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.INT, "storageAutoDrive#sessionCount", "Number of persisted sessions", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.STRING, "storageAutoDrive.session(?)#vehicleUniqueId", "Unique vehicle identifier")
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.INT, "storageAutoDrive.session(?)#jobId", "Stored job identifier", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.STRING, "storageAutoDrive.session(?)#state", "Stored session state", "QUEUED")
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.INT, "storageAutoDrive.session(?)#fillType", "Stored fill type", FillType.UNKNOWN)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.INT, "storageAutoDrive.session(?)#requestedFillType", "Requested fill type", FillType.UNKNOWN)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.BOOL, "storageAutoDrive.session(?)#allFillType", "Whether the order accepts all fill types", false)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.INT, "storageAutoDrive.session(?)#spawned", "Number of initiated spawns", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.INT, "storageAutoDrive.session(?)#loaded", "Legacy loaded-object count", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.STRING, "storageAutoDrive.session(?)#pendingFilename", "Legacy pending object filename", "")
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.FLOAT, "storageAutoDrive.session(?)#pendingSince", "Legacy pending timestamp", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.STRING, "storageAutoDrive.session(?)#storageName", "Storage name", "")
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.FLOAT, "storageAutoDrive.session(?)#startedAt", "Session start time", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.FLOAT, "storageAutoDrive.session(?)#lastStateChange", "Last state change time", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.STRING, "storageAutoDrive.session(?)#jobState", "Stored job state", "")
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.FLOAT, "storageAutoDrive.session(?)#jobQueuedAt", "Job queue time", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.FLOAT, "storageAutoDrive.session(?)#jobStartedAt", "Job start time", 0)
StorageAutoDrivePersistence.xmlSchema:register(XMLValueType.BOOL, "storageAutoDrive.session(?)#jobRestored", "Whether the job was restored", false)

local function getSaveDir()
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        return g_currentMission.missionInfo.savegameDirectory
    end
    return nil
end


local function findUniqueStorageByName(name)
    if name == nil or tostring(name) == "" then return nil, false end
    local match = nil
    for storage in pairs(StorageAutoDriveStorage.registeredStorages or {}) do
        if storage ~= nil and StorageAutoDriveUtils:getStorageName(storage) == tostring(name) then
            if match ~= nil then
                return nil, true
            end
            match = storage
        end
    end
    return match, false
end

local function getVehicleUniqueId(vehicle)
    if vehicle == nil then return nil end
    if vehicle.getUniqueId ~= nil then
        local ok,id=pcall(function() return vehicle:getUniqueId() end)
        if ok then return id end
    end
    return nil
end

function StorageAutoDrivePersistence:installSaveHook()
    StorageAutoDriveConfig:traceFunction("PERSISTENCE", "StorageAutoDrivePersistence:installSaveHook")
    StorageAutoDriveConfig:debug("PERSISTENCE", "installSaveHook() | installiert=" .. tostring(self.hookInstalled) .. " | FSCareerMissionInfo=" .. tostring(FSCareerMissionInfo ~= nil) .. " | saveToXMLFile=" .. tostring(FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil))
    if self.hookInstalled then return end
    if FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil then
        FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(missionInfo, xmlFile, ...)
            StorageAutoDriveConfig:debug("PERSISTENCE", "SAVE HOOK CALLBACK | missionInfo=" .. tostring(missionInfo) .. " | xmlFile=" .. tostring(xmlFile) .. " | savegameDirectory=" .. tostring(missionInfo ~= nil and missionInfo.savegameDirectory) .. " | isValid=" .. tostring(missionInfo ~= nil and missionInfo.isValid) .. " | runtimeSessions=" .. tostring(StorageAutoDriveUtils:getTableCount(StorageAutoDriveVehicle.sessions or {})) .. " | activeJob=" .. tostring(StorageAutoDriveFIFO.active and StorageAutoDriveFIFO.active.id) .. " | queuedJobs=" .. tostring(StorageAutoDriveFIFO.queue and #StorageAutoDriveFIFO.queue or 0))
            StorageAutoDrivePersistence:save(missionInfo)
        end)
        self.hookInstalled = true
        StorageAutoDriveConfig:debug("PERSISTENCE", "Savegame-Hook installiert.")
    end
end

function StorageAutoDrivePersistence:save(missionInfo)
    StorageAutoDriveConfig:traceFunction("PERSISTENCE", "StorageAutoDrivePersistence:save")
    StorageAutoDriveConfig:debug("PERSISTENCE", "SAVE START | missionInfo=" .. tostring(missionInfo) .. " | valid=" .. tostring(missionInfo ~= nil and missionInfo.isValid) .. " | time=" .. tostring(g_currentMission ~= nil and g_currentMission.time))
    if missionInfo == nil or missionInfo.isValid == false then
        StorageAutoDriveConfig:debug("PERSISTENCE", "SAVE ABORT | missionInfo fehlt/ungueltig")
        return
    end
    local dir = missionInfo.savegameDirectory or getSaveDir()
    if dir == nil then
        StorageAutoDriveConfig:debug("PERSISTENCE", "SAVE ABORT | savegameDirectory=nil")
        return
    end
    local path = dir .. "/" .. self.FILE_NAME
    StorageAutoDriveConfig:debug("PERSISTENCE", "SAVE PATH | " .. tostring(path))
    local xml = XMLFile.create("storageAutoDriveSessions", path, "storageAutoDrive", self.xmlSchema)
    if xml == nil then
        StorageAutoDriveConfig:error("Persistence konnte XML nicht erstellen: " .. tostring(path))
        return
    end
    local index = 0
    local runtimeSessionCount = 0
    for _, session in pairs(StorageAutoDriveVehicle.sessions or {}) do
        runtimeSessionCount = runtimeSessionCount + 1
        if session ~= nil and session.vehicle ~= nil and session.state ~= "DONE" and session.state ~= "CANCELLED" then
            local key = string.format("storageAutoDrive.session(%d)", index)
            xml:setValue(key .. "#vehicleUniqueId", getVehicleUniqueId(session.vehicle))
            xml:setValue(key .. "#jobId", session.job ~= nil and session.job.id or 0)
            xml:setValue(key .. "#state", session.state)
            xml:setValue(key .. "#fillType", session.job ~= nil and session.job.fillType or FillType.UNKNOWN)
            xml:setValue(key .. "#requestedFillType", session.job ~= nil and session.job.requestedFillType or FillType.UNKNOWN)
            xml:setValue(key .. "#allFillType", session.job ~= nil and session.job.isAllOrder == true or false)
            xml:setValue(key .. "#spawned", session.spawnedCount or 0)
            xml:setValue(key .. "#storageName", session.storage ~= nil and StorageAutoDriveUtils:getStorageName(session.storage) or "")
            xml:setValue(key .. "#startedAt", session.startedAt or 0)
            xml:setValue(key .. "#lastStateChange", session.lastStateChange or 0)
            xml:setValue(key .. "#jobState", session.job ~= nil and session.job.state or "")
            xml:setValue(key .. "#jobQueuedAt", session.job ~= nil and session.job.queuedAt or 0)
            xml:setValue(key .. "#jobStartedAt", session.job ~= nil and session.job.startedAt or 0)
            xml:setValue(key .. "#jobRestored", session.job ~= nil and session.job.restored == true or false)
            StorageAutoDriveConfig:debugRaw("PERSISTENCE", "SAVE SESSION | index=" .. tostring(index) .. " | runtimeSession=" .. tostring(session.runtimeId) .. " | job=" .. tostring(session.job and session.job.id) .. " | vehicleUID=" .. tostring(getVehicleUniqueId(session.vehicle)) .. " | state=" .. tostring(session.state) .. " | jobState=" .. tostring(session.job and session.job.state) .. " | spawned=" .. tostring(session.spawnedCount) .. " | pendingObjectRuntimeOnly=" .. tostring(session.pendingObject ~= nil) .. " | dirty=" .. tostring(session.persistenceDirty))
            index = index + 1
        end
    end
    xml:setValue("storageAutoDrive#sessionCount", index)
    xml:save()
    xml:delete()
    StorageAutoDriveConfig:debug("PERSISTENCE", "SAVE END | Sessions gespeichert=" .. tostring(index) .. " | RuntimeSessions=" .. tostring(runtimeSessionCount) .. " | path=" .. tostring(path))
end

function StorageAutoDrivePersistence:load()
    StorageAutoDriveConfig:traceFunction("PERSISTENCE", "StorageAutoDrivePersistence:load")
    StorageAutoDriveConfig:debug("PERSISTENCE", "LOAD START | time=" .. tostring(g_currentMission ~= nil and g_currentMission.time))
    self.pending = {}
    StorageAutoDriveConfig:debug("PERSISTENCE", "Persistence load() gestartet")
    local dir = getSaveDir()
    if dir == nil then
        StorageAutoDriveConfig:debug("PERSISTENCE", "LOAD ABORT | savegameDirectory=nil")
        return
    end
    local path = dir .. "/" .. self.FILE_NAME
    local exists = fileExists(path)
    StorageAutoDriveConfig:debug("PERSISTENCE", "LOAD PATH | " .. tostring(path) .. " | exists=" .. tostring(exists))
    if not exists then
        StorageAutoDriveConfig:debug("PERSISTENCE", "LOAD END | keine Persistence-Datei vorhanden")
        return
    end

    local xml = XMLFile.load("storageAutoDriveSessions", path, self.xmlSchema)
    if xml == nil then
        StorageAutoDriveConfig:debug("PERSISTENCE", "LOAD ABORT | XML konnte nicht geladen werden | path=" .. tostring(path))
        return
    end
    local count = tonumber(xml:getValue("storageAutoDrive#sessionCount", 0)) or 0

    StorageAutoDriveConfig:debug("PERSISTENCE", "LOAD SOURCE | path=" .. tostring(path) .. " | sessions=" .. tostring(count))
    for i=0,count-1 do
        local key=string.format("storageAutoDrive.session(%d)",i)
        self.pending[#self.pending+1]={
            vehicleUniqueId=xml:getValue(key.."#vehicleUniqueId"),
            jobId=xml:getValue(key.."#jobId",0),
            state=xml:getValue(key.."#state","QUEUED"),
            fillType=xml:getValue(key.."#fillType",FillType.UNKNOWN),
            requestedFillType=xml:getValue(key.."#requestedFillType",FillType.UNKNOWN),
            isAllOrder=xml:getValue(key.."#allFillType",false),
            spawned=xml:getValue(key.."#spawned",0),
            loaded=xml:getValue(key.."#loaded",0),
            storageName=xml:getValue(key.."#storageName",""),
            pendingFilename=xml:getValue(key.."#pendingFilename",""),
            pendingSince=xml:getValue(key.."#pendingSince",0),
            startedAt=xml:getValue(key.."#startedAt",0),
            lastStateChange=xml:getValue(key.."#lastStateChange",0),
            jobState=xml:getValue(key.."#jobState",""),
            jobQueuedAt=xml:getValue(key.."#jobQueuedAt",0),
            jobStartedAt=xml:getValue(key.."#jobStartedAt",0),
            jobRestored=xml:getValue(key.."#jobRestored",false)
        }
        local loadedData = self.pending[#self.pending]
        StorageAutoDriveConfig:debugRaw("PERSISTENCE", "LOAD SESSION | index=" .. tostring(i) .. " | job=" .. tostring(loadedData.jobId) .. " | vehicleUID=" .. tostring(loadedData.vehicleUniqueId) .. " | state=" .. tostring(loadedData.state) .. " | jobState=" .. tostring(loadedData.jobState) .. " | spawned=" .. tostring(loadedData.spawned) .. " | loaded=" .. tostring(loadedData.loaded) .. " | pendingFile=" .. tostring(loadedData.pendingFilename) .. " | pendingSince=" .. tostring(loadedData.pendingSince))
    end
    xml:delete()
    StorageAutoDriveConfig:debug("PERSISTENCE", "LOAD END | Gespeicherte Sessions gefunden=" .. tostring(#self.pending))
end

function StorageAutoDrivePersistence:restore()
    StorageAutoDriveConfig:traceFunction("PERSISTENCE", "StorageAutoDrivePersistence:restore")
    StorageAutoDriveConfig:debug("PERSISTENCE", "RESTORE START | pending=" .. tostring(#self.pending) .. " | mission=" .. tostring(g_currentMission) .. " | vehicleSystem=" .. tostring(g_currentMission ~= nil and g_currentMission.vehicleSystem))
    if #self.pending == 0 or g_currentMission == nil or g_currentMission.vehicleSystem == nil then return end
    local remaining = {}
    for _, data in ipairs(self.pending) do
        local vehicle = nil
        StorageAutoDriveConfig:debugRaw("PERSISTENCE", "RESTORE DATA | job=" .. tostring(data.jobId) .. " | vehicleUID=" .. tostring(data.vehicleUniqueId) .. " | state=" .. tostring(data.state) .. " | spawned=" .. tostring(data.spawned) .. " | loaded=" .. tostring(data.loaded) .. " | pendingFile=" .. tostring(data.pendingFilename))
        for _, candidate in pairs(g_currentMission.vehicleSystem.vehicles or {}) do
            StorageAutoDriveConfig:debugRaw("PERSISTENCE", "RESTORE VEHICLE CANDIDATE | targetUID=" .. tostring(data.vehicleUniqueId) .. " | candidateId=" .. tostring(candidate and candidate.id) .. " | candidateUID=" .. tostring(getVehicleUniqueId(candidate)))
            if getVehicleUniqueId(candidate) == data.vehicleUniqueId then vehicle = StorageAutoDriveUtils:getRootVehicle(candidate); break end
        end
        if vehicle ~= nil then
            StorageAutoDriveConfig:debug("PERSISTENCE", "RESTORE VEHICLE MATCH | job=" .. tostring(data.jobId) .. " | vehicle=" .. tostring(vehicle.id) .. " | uid=" .. tostring(data.vehicleUniqueId))
            local nearestStorage = StorageAutoDriveStorage:getNearest(vehicle)
            local storage = nearestStorage
            local savedStorage, ambiguousStorage = findUniqueStorageByName(data.storageName)
            if savedStorage ~= nil then
                storage = savedStorage
            elseif data.storageName ~= nil and tostring(data.storageName) ~= "" then
                -- Ein gespeicherter Auftrag darf nicht versehentlich einem anderen
                -- Lager zugeordnet werden, wenn sein Lagername nicht eindeutig ist.
                storage = nil
            end
            local pickup = StorageAutoDriveAutoDrive:isPickup(vehicle)
            StorageAutoDriveConfig:debugRaw("PERSISTENCE", "RESTORE VEHICLE STATE | job=" .. tostring(data.jobId) .. " | nearestStorage=" .. tostring(nearestStorage and StorageAutoDriveUtils:getStorageName(nearestStorage)) .. " | savedStorage=" .. tostring(data.storageName) .. " | resolvedStorage=" .. tostring(storage and StorageAutoDriveUtils:getStorageName(storage)) .. " | ambiguousStorage=" .. tostring(ambiguousStorage) .. " | pickup=" .. tostring(pickup) .. " | mode=" .. tostring(StorageAutoDriveAutoDrive:getTaskModeName(vehicle)))
            if storage ~= nil and pickup then
                local job = StorageAutoDriveJobs:create(vehicle, storage)
                if job ~= nil then
                    -- Nach einem Savegame werden keine alten Runtime-Referenzen,
                    -- Pending-Spawns, Zähler oder alten Sessionzustände übernommen.
                    -- Falls das Fahrzeug noch nicht am gespeicherten Lager steht,
                    -- wird der Auftrag erst dort fortgesetzt.
                    job.restored = true
                    job.restoreWaitingForStorage = nearestStorage ~= nil and nearestStorage ~= storage
                    StorageAutoDriveFIFO:add(job)
                    StorageAutoDriveConfig:debug("PERSISTENCE",
                        "Session aus Savegame neu aufgebaut | Fahrzeug="
                        .. tostring(data.vehicleUniqueId)
                        .. " | Lager=" .. tostring(StorageAutoDriveUtils:getStorageName(storage))
                        .. " | wartetAufLager=" .. tostring(job.restoreWaitingForStorage)
                        .. " | alterState=" .. tostring(data.state)
                        .. " | alte Runtime-Daten verworfen")
                else
                    remaining[#remaining+1]=data
                end
            else
                StorageAutoDriveConfig:debug("PERSISTENCE", "RESTORE ABGELEHNT | Lager nicht eindeutig/verfügbar oder kein aktiver AD-Abholauftrag | job=" .. tostring(data.jobId) .. " | vehicleUID=" .. tostring(data.vehicleUniqueId))
                remaining[#remaining+1]=data
            end
        else
            StorageAutoDriveConfig:debug("PERSISTENCE", "RESTORE ABGELEHNT | Fahrzeug nicht gefunden | job=" .. tostring(data.jobId) .. " | vehicleUID=" .. tostring(data.vehicleUniqueId))
            remaining[#remaining+1]=data
        end
    end
    self.pending=remaining
    StorageAutoDriveConfig:debug("PERSISTENCE", "RESTORE END | nicht wiederhergestellt=" .. tostring(#remaining))
end
