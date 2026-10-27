StorageAutoDrive = {}
StorageAutoDrive.VERSION = "1.0.4.50"
StorageAutoDrive.updateTimer = 0
StorageAutoDrive.restoreRetryTimer = 0
StorageAutoDrive.objectStorageSpawnHookInstalled = false
StorageAutoDrive.lastLoggingToggleTime = -10000
StorageAutoDrive.oldObjectStorageSpawned = nil

function StorageAutoDrive:check(name,message)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDrive:check")
    StorageAutoDriveConfig:debug("CHECK", tostring(message))
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

-- Registriert ausschließlich die benannte FS25-Aktion aus modDesc.xml.
-- Die aktive Tastenbelegung kommt vollständig aus den Spieleinstellungen.
-- Es gibt keinen zusätzlichen, fest codierten Tastatur-Fallback.
function StorageAutoDrive:registerLoggingAction()
    if self.loggingActionEventId ~= nil then
        return true
    end

    local input = g_inputBinding
    if input == nil or input.registerActionEvent == nil then
        return false
    end

    -- Gleicher Registrierungsweg wie im UniversalConveyorHelper:
    -- Der Aktionsname aus modDesc.xml wird direkt übergeben.
    local ok, registered, eventId, collisionAction = pcall(
        input.registerActionEvent, input, "SAD_TOGGLE_LOGGING", self,
        StorageAutoDrive.onToggleLoggingAction, false, true, false, true
    )

    if ok and registered and eventId ~= nil and eventId ~= "" then
        self.loggingActionEventId = eventId
        self.loggingActionWarningShown = false

        if input.setActionEventTextVisibility ~= nil then
            pcall(input.setActionEventTextVisibility, input, eventId, false)
        end

        print("[StorageAutoDrive][LOGGING] Log-Umschaltung registriert | Tastenbelegung aus Spieleinstellungen")
        return true
    end

    if not self.loggingActionWarningShown then
        print("[StorageAutoDrive][LOGGING] Registrierung fehlgeschlagen"
            .. " | pcallOk=" .. tostring(ok)
            .. " | registered=" .. tostring(registered)
            .. " | eventId=" .. tostring(eventId)
            .. " | collisionAction=" .. tostring(collisionAction))
        self.loggingActionWarningShown = true
    end
    return false
end

function StorageAutoDrive:onToggleLoggingAction(actionName, inputValue)
    -- Nur auf den aktiven Tastendruck reagieren. Einige Input-Aktionen können
    -- zusätzlich einen Nullwert beim Loslassen melden.
    if inputValue ~= nil and tonumber(inputValue) ~= nil and tonumber(inputValue) <= 0 then
        return
    end
    -- Reguläre FS25-Aktion: funktioniert auch mit einer in den Einstellungen
    -- neu belegten Taste.
    self:toggleLogging("action")
end

function StorageAutoDrive:toggleLogging(source)
    local now = g_currentMission ~= nil and g_currentMission.time or 0
    if now - (self.lastLoggingToggleTime or -10000) < 250 then
        print("[StorageAutoDrive][LOGGING] Doppelte Auslösung unterdrückt | source=" .. tostring(source))
        return
    end
    self.lastLoggingToggleTime = now

    StorageAutoDriveConfig.LOGGING_ENABLED = not StorageAutoDriveConfig.LOGGING_ENABLED
    local state = StorageAutoDriveConfig.LOGGING_ENABLED and "EIN" or "AUS"
    local message = "StorageAutoDrive Diagnose-Logs " .. state .. " (Fehler-Logs bleiben separat aktiv)."

    -- Diese Statusmeldung muss auch beim Ausschalten der Diagnose sichtbar bleiben.
    print("[StorageAutoDrive][LOGGING] " .. message)
    if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
        g_currentMission:showBlinkingWarning(message, 3000)
    end
end

function StorageAutoDrive:loadMap()
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDrive:loadMap")
    StorageAutoDriveConfig:debug("GENERAL", "LIFECYCLE loadMap START | mission=" .. tostring(g_currentMission) .. " | time=" .. tostring(g_currentMission ~= nil and g_currentMission.time))
    StorageAutoDrivePersistence:installSaveHook()
    StorageAutoDriveStorage:scan()
    StorageAutoDrivePersistence:load()
    self:hookObjectStorageSpawnCallback()
    -- Eingabeaktion erst in update() registrieren. loadMap() läuft während des
    -- Kartenaufbaus; zu diesem Zeitpunkt kann die InputBinding noch nicht final sein.
    StorageAutoDriveConfig:debug("GENERAL", "StorageAutoDrive " .. tostring(self.VERSION) .. " geladen | Diagnose-Logs starten AUS; konfigurierbare Eingabeaktion wird nach dem Kartenaufbau registriert | AD/UAL read-only | LOGGING_ENABLED=" .. tostring(StorageAutoDriveConfig.LOGGING_ENABLED) .. " | VERBOSE=" .. tostring(StorageAutoDriveConfig.VERBOSE))
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
    -- Retry the narrowly scoped AD dropdown integration until the real AD environment is available.
    if StorageAutoDriveADBaleIntegration ~= nil then StorageAutoDriveADBaleIntegration:update(dt) end

    if self.loggingActionEventId == nil then
        self:registerLoggingAction()
    end
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
    self.loggingHotkeyPressed = false
    self.lastLoggingToggleTime = -10000
    if self.loggingActionEventId ~= nil and g_inputBinding ~= nil then
        g_inputBinding:removeActionEvent(self.loggingActionEventId)
        self.loggingActionEventId = nil
    end
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
