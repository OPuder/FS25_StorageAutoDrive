StorageAutoDrive = {}
StorageAutoDrive.VERSION = "1.0.4.16"
StorageAutoDrive.updateTimer = 0
StorageAutoDrive.restoreRetryTimer = 0
StorageAutoDrive.objectStorageSpawnHookInstalled = false
StorageAutoDrive.oldObjectStorageSpawned = nil

function StorageAutoDrive:check(name,message)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDrive:check")
    print("[StorageAutoDrive][CHECK] "..tostring(message))
end

function StorageAutoDrive:hookObjectStorageSpawnCallback()
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDrive:hookObjectStorageSpawnCallback")
    if self.objectStorageSpawnHookInstalled then return true end
    if PlaceableObjectStorage == nil or PlaceableObjectStorage.onObjectFromStorageSpawned == nil then return false end
    self.oldObjectStorageSpawned=PlaceableObjectStorage.onObjectFromStorageSpawned
    PlaceableObjectStorage.onObjectFromStorageSpawned=function(storage,spawnedObject,...)
        self.oldObjectStorageSpawned(storage,spawnedObject,...)
        if StorageAutoDriveVehicle ~= nil then StorageAutoDriveVehicle:onObjectStorageSpawned(storage,spawnedObject) end
    end
    self.objectStorageSpawnHookInstalled=true
    StorageAutoDriveConfig:debug("CALLBACK", "ObjectStorage-Spawn-Hook installiert (nur STORAGEAUTODRIVE).")
    return true
end

function StorageAutoDrive:loadMap()
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDrive:loadMap")
    StorageAutoDriveConfig:debug("GENERAL", "LIFECYCLE loadMap START | mission=" .. tostring(g_currentMission) .. " | time=" .. tostring(g_currentMission ~= nil and g_currentMission.time))
    StorageAutoDrivePersistence:installSaveHook()
    StorageAutoDriveStorage:scan()
    StorageAutoDrivePersistence:load()
    self:hookObjectStorageSpawnCallback()
    StorageAutoDriveConfig:debug("GENERAL", "StorageAutoDrive 1.0.4.16 geladen | AD/UAL read-only | LOGGING_ENABLED=" .. tostring(StorageAutoDriveConfig.LOGGING_ENABLED) .. " | VERBOSE=" .. tostring(StorageAutoDriveConfig.VERBOSE))
    StorageAutoDriveConfig:debug("GENERAL", "Diagnose-Kategorien aktiv: " .. tostring(StorageAutoDriveConfig.LOGGING_ENABLED and "siehe Config.LOG" or "ALLE AUS"))
    StorageAutoDriveConfig:debugRaw("GENERAL", "LIFECYCLE loadMap END | version=" .. tostring(self.VERSION) .. " | time=" .. tostring(g_currentMission ~= nil and g_currentMission.time))
end

function StorageAutoDrive:onSavegameLoaded()
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDrive:onSavegameLoaded")
    StorageAutoDriveConfig:debug("GENERAL", "LIFECYCLE onSavegameLoaded START | time=" .. tostring(g_currentMission ~= nil and g_currentMission.time))
    StorageAutoDriveConfig:debug("GENERAL", "onSavegameLoaded() -> Storage scan + Persistence restore")
    StorageAutoDriveStorage:scan()
    StorageAutoDrivePersistence:restore()
    StorageAutoDriveConfig:debugRaw("GENERAL", "LIFECYCLE onSavegameLoaded END | time=" .. tostring(g_currentMission ~= nil and g_currentMission.time))
end

function StorageAutoDrive:update(dt)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDrive:update")
    StorageAutoDriveConfig:trace("TRACE_UPDATE_LOOP", "UPDATE", "LOOP | dt=" .. tostring(dt) .. " | time=" .. tostring(g_currentMission and g_currentMission.time))
    self.updateTimer=self.updateTimer+(dt or 0)
    if self.updateTimer < StorageAutoDriveConfig.CHECK_INTERVAL then return end
    self.updateTimer=0
    StorageAutoDriveStorage:scan()

    -- Fallback, falls der Savegame-Loaded-Lifecycle-Callback in diesem Ladepfad
    -- nicht ausgelöst wird. Restore bleibt auf gespeicherte STORAGEAUTODRIVE-Daten
    -- begrenzt und baut Jobs nur aus dem aktuellen Fahrzeug-/AD-Zustand neu auf.
    if StorageAutoDrivePersistence ~= nil and #StorageAutoDrivePersistence.pending > 0 then
        self.restoreRetryTimer = self.restoreRetryTimer + StorageAutoDriveConfig.CHECK_INTERVAL
        if self.restoreRetryTimer >= 1000 then
            self.restoreRetryTimer = 0
            StorageAutoDriveConfig:debug("PERSISTENCE", "RESTORE RETRY | pending=" .. tostring(#StorageAutoDrivePersistence.pending))
            StorageAutoDrivePersistence:restore()
        end
    else
        self.restoreRetryTimer = 0
    end

    StorageAutoDriveVehicle:update(StorageAutoDriveConfig.CHECK_INTERVAL)
end

function StorageAutoDrive:deleteMap()
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDrive:deleteMap")
    if self.objectStorageSpawnHookInstalled and PlaceableObjectStorage ~= nil then
        PlaceableObjectStorage.onObjectFromStorageSpawned=self.oldObjectStorageSpawned
    end
    self.objectStorageSpawnHookInstalled=false
    self.oldObjectStorageSpawned=nil
    StorageAutoDriveVehicle:reset()
    StorageAutoDriveStorage:cleanup()
    StorageAutoDrivePersistence.hookInstalled=false
    StorageAutoDrivePersistence.pending={}
    self.restoreRetryTimer=0
end

addModEventListener(StorageAutoDrive)
