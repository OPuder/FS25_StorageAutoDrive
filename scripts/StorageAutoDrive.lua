StorageAutoDrive = {}
StorageAutoDrive.VERSION = "1.0.4.28"
StorageAutoDrive.updateTimer = 0
StorageAutoDrive.restoreRetryTimer = 0
StorageAutoDrive.objectStorageSpawnHookInstalled = false
StorageAutoDrive.loggingHotkeyPressed = false
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

-- Registriert die benannte FS25-Aktion aus modDesc.xml. Dadurch bleibt die
-- Standardbelegung STRG+ALT+F in den Spieleinstellungen frei konfigurierbar.
function StorageAutoDrive:registerLoggingAction()
    if self.loggingActionEventId ~= nil or g_inputBinding == nil or InputAction == nil then
        return false
    end

    local action = InputAction.SAD_TOGGLE_LOGGING
    if action == nil then
        if not self.loggingActionWarningShown then
            print("[StorageAutoDrive][LOGGING] FEHLER: InputAction.SAD_TOGGLE_LOGGING fehlt; Eingabeaktion nicht registriert.")
            self.loggingActionWarningShown = true
        end
        return false
    end

    local _, eventId = g_inputBinding:registerActionEvent(
        action, self, self.onToggleLoggingAction, false, true, false, true
    )
    if eventId == nil then
        if not self.loggingActionWarningShown then
            print("[StorageAutoDrive][LOGGING] FEHLER: SAD_TOGGLE_LOGGING konnte nicht registriert werden.")
            self.loggingActionWarningShown = true
        end
        return false
    end

    self.loggingActionEventId = eventId
    self.loggingActionWarningShown = false

    if g_inputBinding.setActionEventText ~= nil and g_i18n ~= nil then
        local text = g_i18n:getText("input_SAD_TOGGLE_LOGGING")
        g_inputBinding:setActionEventText(eventId, text)
    end
    if g_inputBinding.setActionEventTextVisibility ~= nil then
        g_inputBinding:setActionEventTextVisibility(eventId, true)
    end
    if g_inputBinding.setActionEventTextPriority ~= nil and GS_PRIO_HIGH ~= nil then
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
    end

    print("[StorageAutoDrive][LOGGING] Konfigurierbare Eingabeaktion registriert (Standard: STRG+ALT+F).")
    return true
end

function StorageAutoDrive:onToggleLoggingAction(actionName, inputValue)
    -- Reguläre FS25-Aktion: funktioniert auch mit einer in den Einstellungen
    -- neu belegten Taste.
    self:toggleLogging("action")
end

-- Fallback für die nachweislich funktionierende Standardkombination.
-- Falls FS25 sowohl ActionBinding als auch keyEvent für dieselbe Taste auslöst,
-- verhindert toggleLogging() eine doppelte Umschaltung.
function StorageAutoDrive:keyEvent(unicode, sym, modifier, isDown)
    if Input == nil or bitAND == nil or modifier == nil or sym ~= Input.KEY_f then
        return
    end

    if not isDown then
        self.loggingHotkeyPressed = false
        return
    end

    if self.loggingHotkeyPressed then
        return
    end

    local hasCtrl = bitAND(modifier, Input.MOD_CTRL) ~= 0
    local hasAlt = bitAND(modifier, Input.MOD_ALT) ~= 0
    if hasCtrl and hasAlt then
        self.loggingHotkeyPressed = true
        self:toggleLogging("keyEvent")
    end
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
    self:registerLoggingAction()
    StorageAutoDriveConfig:debug("GENERAL", "StorageAutoDrive 1.0.4.28 geladen | Diagnose-Logs starten AUS; konfigurierbare Eingabeaktion plus Standardtasten-Fallback STRG+ALT+F | AD/UAL read-only | LOGGING_ENABLED=" .. tostring(StorageAutoDriveConfig.LOGGING_ENABLED) .. " | VERBOSE=" .. tostring(StorageAutoDriveConfig.VERBOSE))
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
