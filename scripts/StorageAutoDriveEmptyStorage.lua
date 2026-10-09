-- ============================================================================
-- STORAGEAUTODRIVE - SONDERFALL LEERES LAGER
-- Version 1.0.4.8
--
-- Dieser Handler behandelt ausschließlich den Fall, dass ein aktiver
-- StorageAutoDrive-Abholauftrag aktuell keine passende Palette aus dem
-- ObjectStorage bereitstellen kann.
--
-- Wichtig:
-- - AutoDrive wird nicht gesteuert.
-- - Universal Autoload wird nicht gesteuert.
-- - 30 Sekunden sind ausschließlich das Prüfintervall, kein Timeout.
-- - Solange das Fahrzeug am Lager wartet, bleibt der Sonderfall aktiv.
-- - Sobald wieder eine passende Palette vorhanden ist, geht die Session
--   zurück in den normalen EXTRACTING-Ablauf.
-- - Sobald das Fahrzeug den Standort verlässt bzw. AD den Pickup-Zustand
--   beendet, wird die Session abgeschlossen.
-- ============================================================================

StorageAutoDriveEmptyStorage = {}

StorageAutoDriveEmptyStorage.CHECK_INTERVAL_MS = 30000

function StorageAutoDriveEmptyStorage:begin(session, reason)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveEmptyStorage:begin")
    if session == nil then
        return false
    end

    if session.state == StorageAutoDriveSession.STATES.EMPTY_STORAGE then
        return true
    end

    session.emptyStorageLastCheck = nil
    session.emptyStorageActiveSince = g_currentMission ~= nil and g_currentMission.time or 0

    StorageAutoDriveSession:setState(
        session,
        StorageAutoDriveSession.STATES.EMPTY_STORAGE,
        reason or "Keine passende Palette im Lager"
    )

    StorageAutoDriveConfig:debug(
        "EMPTY_STORAGE",
        "Sonderfall LEERES LAGER aktiviert | Job=" .. tostring(session.job and session.job.id)
        .. " | spawned=" .. tostring(session.spawnedCount)
        .. " | Fahrzeug=" .. tostring(session.vehicle and session.vehicle.id)
        .. " | Prüfintervall=" .. tostring(self.CHECK_INTERVAL_MS) .. " ms"
    )

    return true
end

function StorageAutoDriveEmptyStorage:isVehicleStillAtStorage(session)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveEmptyStorage:isVehicleStillAtStorage")
    if session == nil or session.vehicle == nil then
        return false, "Fahrzeugreferenz fehlt"
    end

    -- Primär beobachten wir die tatsächliche Bewegung des Fahrzeugs.
    -- Der Sonderfall endet dadurch auch dann, wenn AD den Auftrag bereits
    -- intern anders behandelt und nur noch losfährt.
    local speed = tonumber(session.vehicle.lastSpeedReal) or 0
    local standingSpeed = tonumber(StorageAutoDriveConfig.VEHICLE_STANDING_SPEED) or 0.0005

    if speed >= standingSpeed then
        return false, "Fahrzeug fährt | speed=" .. tostring(speed)
    end

    -- Zusätzlich bleibt das vorhandene read-only AD-Signal eine saubere
    -- Absicherung: Pickup=false bedeutet, dass der bisherige Auftrag nicht
    -- mehr aktiv ist. Wir setzen dabei keinerlei AD-Zustand.
    if StorageAutoDriveAutoDrive:hasTaskFinished(session.vehicle) then
        return false, "AD-Pickup nicht mehr aktiv"
    end

    return true, "Fahrzeug wartet am Lager"
end

function StorageAutoDriveEmptyStorage:findAvailableObject(session)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveEmptyStorage:findAvailableObject")
    if session == nil or session.storage == nil or session.job == nil then
        return nil, nil
    end

    local info, index = StorageAutoDriveObjects:findObjectInfoForFillType(
        session.storage,
        session.job.fillType
    )

    return info, index
end

function StorageAutoDriveEmptyStorage:update(session)
    StorageAutoDriveConfig:traceFunction("GENERAL", "StorageAutoDriveEmptyStorage:update")
    if session == nil or session.state ~= StorageAutoDriveSession.STATES.EMPTY_STORAGE then
        return false
    end

    -- Bewegung / AD-Auftragsende wird bewusst unabhängig vom 30-Sekunden-
    -- Prüfintervall beobachtet. Dadurch fahren rotierende AD-Aufträge nicht
    -- unnötig weitere 30 Sekunden in den Sonderfall hinein.
    local stillAtStorage, reason = self:isVehicleStillAtStorage(session)
    if not stillAtStorage then
        StorageAutoDriveConfig:debug(
            "EMPTY_STORAGE",
            "Sonderfall beendet: Fahrzeug wartet nicht mehr | Job=" .. tostring(session.job and session.job.id)
            .. " | Grund=" .. tostring(reason)
        )
        StorageAutoDriveSession:setState(
            session,
            StorageAutoDriveSession.STATES.COMPLETED,
            "Leeres Lager: Fahrzeug fährt weiter / AD-Auftrag beendet"
        )
        return true
    end

    local now = g_currentMission ~= nil and g_currentMission.time or 0
    local lastCheck = session.emptyStorageLastCheck
    if lastCheck ~= nil and (now - lastCheck) < self.CHECK_INTERVAL_MS then
        return true
    end

    session.emptyStorageLastCheck = now

    StorageAutoDriveConfig:debug(
        "EMPTY_STORAGE",
        "30-Sekunden-Prüfung | Job=" .. tostring(session.job and session.job.id)
        .. " | spawned=" .. tostring(session.spawnedCount)
        .. " | time=" .. tostring(now)
    )

    local info, index = self:findAvailableObject(session)
    if info ~= nil and index ~= nil then
        StorageAutoDriveConfig:debug(
            "EMPTY_STORAGE",
            "Passende Palette wieder verfügbar | Job=" .. tostring(session.job and session.job.id)
            .. " | Gruppe=" .. tostring(index)
            .. " | Anzahl=" .. tostring(info.numObjects)
            .. " | zurück zu EXTRACTING"
        )
        StorageAutoDriveSession:setState(
            session,
            StorageAutoDriveSession.STATES.EXTRACTING,
            "Palette im zuvor leeren Lager wieder verfügbar"
        )
    else
        StorageAutoDriveConfig:debug(
            "EMPTY_STORAGE",
            "Lager weiterhin ohne passende Palette | Job=" .. tostring(session.job and session.job.id)
            .. " | nächste Prüfung in " .. tostring(self.CHECK_INTERVAL_MS) .. " ms"
        )
    end

    return true
end
