StorageAutoDriveConfig = {
    CHECK_DISTANCE = 8,
    CHECK_INTERVAL = 250,
    VEHICLE_STANDING_SPEED = 0.0089,
    VEHICLE_LOG_INTERVAL = 2000,
    SPAWN_INTERVAL_MS = 1000, -- Mindestabstand zwischen zwei Storage-Spawns
    PENDING_LOAD_DELAY_MS = 500, -- Nach echtem Storage-Spawn 500 ms warten, bevor UAL-Bindung geprüft wird
    POST_LOAD_SETTLE_MS = 1000, -- Nach bestätigter UAL-Übernahme warten, damit UAL seine räumliche Full-Berechnung abschließen kann
    PENDING_EXTRACTION_TIMEOUT_MS = 15000, -- Schutz gegen endloses Warten auf UAL-Übernahme
    PENDING_EXTRACTION_MAX_RETRIES = 3, -- UAL-Bindungs-Retries ohne neuen Storage-Spawn
    -- Hauptschalter für alle normalen Diagnose-Logs.
    -- FALSE = normale Diagnose komplett aus. ERROR_LOG bleibt separat.
    LOGGING_ENABLED = false,
    DEBUG = false,
    ERROR_LOG = true, -- Fehler-Log immer aktivieren, auch wenn LOGGING_ENABLED=false
    HEARTBEAT = false,              -- Alive-Heartbeat ein/aus
    HEARTBEAT_INTERVAL_TICKS = 4,  -- 4 x 250 ms = ca. 1 Sekunde
    LOG = {
        CHECK = false,
        GENERAL = false,
        STORAGE = false,
        VEHICLE = false,
        AUTODRIVE = false,
        UAL = false,
        OBJECTS = false,
        SPAWN = false,
        TRACKING = false,
        SESSION = false,
        JOB = false,
        FIFO = false,
        PERSISTENCE = false,
        TASK = false,
        CLEANUP = false,
        CALLBACK = false,
        PHASE2 = false,
        UPDATE = false,
        EMPTY_STORAGE = false,
        ADSTATION = false
    },
    -- VERBOSE=true schreibt zusätzlich zyklische Zustands-Snapshots.
    VERBOSE = false,
    DIAGNOSTIC_RAW = false, -- RAW-Diagnose für UAL/Storage-Objekte aktivieren

    -- Feindiagnose. DEBUG muss zusätzlich aktiv sein.
    -- TRACE_ALL=true aktiviert alle Feindiagnose-Schalter gleichzeitig.
    -- Für normale Tests bleibt TRACE_ALL=false und einzelne Bereiche können gezielt
    -- eingeschaltet werden.
    -- TRACE_FUNCTIONS: jeden Eintritt in eine STORAGEAUTODRIVE-Funktion loggen.
    -- TRACE_DECISIONS: wichtige Verzweigungen/Entscheidungen loggen.
    -- TRACE_STATE: Zustandswechsel und Session-Zustandsdetails loggen.
    -- TRACE_VALUES: zusätzliche Eingangs-/Ausgangswerte loggen.
    -- TRACE_COLLECTIONS: UAL/ObjectStorage-Sammlungen vollständig auflisten.
    -- TRACE_STORAGE_CALLS: ObjectStorage-Aufrufe und deren Rückgaben ausführlich loggen.
    -- TRACE_UPDATE_LOOP: jeden Update-Durchlauf loggen (sehr laut!).
    -- TRACE_VEHICLE_SCAN: jeden Fahrzeug-Scan loggen (sehr laut!).
    -- TRACE_UAL_SCAN: jede UAL-Abfrage und deren Rohwerte loggen.
    -- TRACE_SESSION: Session-Erzeugung/-Änderung/-Cleanup detailliert loggen.
    -- TRACE_PERSISTENCE: Save/Load/Restore detailliert loggen.
    -- TRACE_CALLBACKS: alle Callback-Eingänge/-Zuordnungen loggen.
    TRACE_ALL = false,
    TRACE_FUNCTIONS = false,
    TRACE_DECISIONS = false,
    TRACE_STATE = false,
    TRACE_VALUES = false,
    TRACE_COLLECTIONS = false,
    TRACE_STORAGE_CALLS = false,
    TRACE_UPDATE_LOOP = false,
    TRACE_VEHICLE_SCAN = false,
    TRACE_UAL_SCAN = false,
    TRACE_SESSION = false,
    TRACE_PERSISTENCE = false,
    TRACE_CALLBACKS = false
}

function StorageAutoDriveConfig:debug(category, message)
    if not self.LOGGING_ENABLED or not self.DEBUG or self.LOG[category] ~= true then
        return
    end
    print("[StorageAutoDrive][" .. tostring(category) .. "] " .. tostring(message))
end

function StorageAutoDriveConfig:debugState(key, category, message)
    if not self.LOGGING_ENABLED or not self.DEBUG or self.LOG[category] ~= true then
        return
    end

    self.debugStateCache = self.debugStateCache or {}
    local value = tostring(message)
    if self.debugStateCache[key] == value then
        return
    end

    self.debugStateCache[key] = value
    print("[StorageAutoDrive][" .. tostring(category) .. "] " .. value)
end

function StorageAutoDriveConfig:debugRaw(category, message)
    if not self.LOGGING_ENABLED or not self.DEBUG or self.LOG[category] ~= true or not self.DIAGNOSTIC_RAW then
        return
    end
    print("[StorageAutoDrive][" .. tostring(category) .. "][RAW] " .. tostring(message))
end

function StorageAutoDriveConfig:trace(flag, category, message)
    if not self.LOGGING_ENABLED or not self.DEBUG or (self.TRACE_ALL ~= true and self[flag] ~= true) then
        return
    end
    if self.LOG[category] ~= true and category ~= "FUNCTION" and category ~= "DECISION" and category ~= "STATE" then
        return
    end
    print("[StorageAutoDrive][" .. tostring(category) .. "][TRACE] " .. tostring(message))
end

function StorageAutoDriveConfig:traceFunction(moduleName, functionName, detail)
    local flag = "TRACE_FUNCTIONS"
    local name = tostring(functionName)
    if moduleName == "UAL" then
        flag = "TRACE_UAL_SCAN"
    elseif moduleName == "VEHICLE" then
        flag = "TRACE_VEHICLE_SCAN"
    elseif moduleName == "PERSISTENCE" then
        flag = "TRACE_PERSISTENCE"
    elseif string.find(name, "StorageAutoDriveSession:", 1, true) ~= nil then
        flag = "TRACE_SESSION"
    elseif string.find(name, "onObjectStorageSpawned", 1, true) ~= nil then
        flag = "TRACE_CALLBACKS"
    elseif string.find(name, ":update", 1, true) ~= nil then
        flag = "TRACE_UPDATE_LOOP"
    end
    local suffix = detail ~= nil and (" | " .. tostring(detail)) or ""
    self:trace(flag, "FUNCTION", "ENTER | " .. tostring(moduleName) .. ":" .. name .. suffix)
end

function StorageAutoDriveConfig:traceStorage(message)
    self:trace("TRACE_STORAGE_CALLS", "OBJECTS", tostring(message))
end

function StorageAutoDriveConfig:traceCollections(message)
    self:trace("TRACE_COLLECTIONS", "UAL", tostring(message))
end

function StorageAutoDriveConfig:traceDecision(moduleName, decision, detail)
    local suffix = detail ~= nil and (" | " .. tostring(detail)) or ""
    self:trace("TRACE_DECISIONS", "DECISION", tostring(moduleName) .. " | " .. tostring(decision) .. suffix)
end

function StorageAutoDriveConfig:traceState(moduleName, detail)
    self:trace("TRACE_STATE", "STATE", tostring(moduleName) .. " | " .. tostring(detail))
end

function StorageAutoDriveConfig:traceValue(moduleName, detail)
    self:trace("TRACE_VALUES", "GENERAL", tostring(moduleName) .. " | " .. tostring(detail))
end


function StorageAutoDriveConfig:error(message)
    if self.ERROR_LOG then
        print("[StorageAutoDrive][ERROR] " .. tostring(message))
    end
end


function StorageAutoDriveConfig:heartbeatTick()
    if not self.HEARTBEAT then
        return
    end

    self.heartbeatCounter = (self.heartbeatCounter or 0) + 1
    self.heartbeatState = self.heartbeatState or {}
end

function StorageAutoDriveConfig:heartbeat(moduleName, detail)
    if not self.HEARTBEAT then
        return
    end
    self.heartbeatState = self.heartbeatState or {}
    self.heartbeatState[moduleName] = {
        tick = self.heartbeatCounter or 0,
        detail = detail
    }
end

function StorageAutoDriveConfig:heartbeatSummary()
    if not self.HEARTBEAT then
        return
    end
    local counter = self.heartbeatCounter or 0
    if counter - (self.heartbeatLastSummary or 0) < (self.HEARTBEAT_INTERVAL_TICKS or 8) then
        return
    end
    self.heartbeatLastSummary = counter

    local modules = {
        "MANAGER",
        "STORAGE",
        "VEHICLE",
        "AUTODRIVE",
        "UAL",
        "OBJECTS"
    }

    local parts = {}
    for _, moduleName in ipairs(modules) do
        local state = self.heartbeatState[moduleName]
        local age = state ~= nil and (counter - state.tick) or nil
        local status
        if state == nil then
            status = "NICHT ERREICHT"
        elseif age == 0 then
            status = "OK"
        elseif age <= 2 then
            status = "AKTIV"
        else
            status = "ALT-" .. tostring(age)
        end
        local detail = state ~= nil and state.detail ~= nil and (" | " .. tostring(state.detail)) or ""
        table.insert(parts, moduleName .. "=" .. status .. detail)
    end

    print("[StorageAutoDrive][ALIVE] " .. table.concat(parts, " || "))
end
