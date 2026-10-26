StorageAutoDriveCleanup = {}

function StorageAutoDriveCleanup:finish(session, reason)
    StorageAutoDriveConfig:traceFunction("CLEANUP", "StorageAutoDriveCleanup:finish")
    if session == nil or session.cleanupDone then return end
    StorageAutoDriveConfig:debug("CLEANUP", "Cleanup gestartet | Grund=" .. tostring(reason))
    session.state = StorageAutoDriveSession.STATES.CLEANUP
    session.lastReason = reason

    -- Nur eindeutig diesem Auftrag zugeordnete, noch nicht geladene Objekte
    -- werden zurueckgefuehrt. Das gilt auch fuer eine noch ausstehende
    -- Pending-Palette: sie darf beim Cleanup nicht einfach als Referenz
    -- verloren gehen und physisch liegen bleiben.
    local returned = 0
    local failed = 0
    local ownUnloaded = StorageAutoDriveSession:getOwnedUnloaded(session)
    StorageAutoDriveConfig:debug("CLEANUP", "Eigene offene Objekte vor Cleanup=" .. tostring(#ownUnloaded))
    for _, object in ipairs(ownUnloaded) do
        StorageAutoDriveConfig:debug("CLEANUP", "Prüfe eigenes offenes Objekt | object=" .. tostring(object and object.id) .. " | file=" .. tostring(StorageAutoDriveUtils:getObjectFilename(object)))
        if StorageAutoDriveObjects:returnObjectToStorage(session.storage, object) then
            returned = returned + 1
            local entry = session.spawnedObjects[object]
            if entry ~= nil then
                entry.returned = true
            end
        else
            failed = failed + 1
        end
    end

    StorageAutoDriveConfig:debug("CLEANUP",
        "Session-Cleanup | eigene Ueberhaenge zurueckgefuehrt=" .. tostring(returned)
        .. " | fehlgeschlagen=" .. tostring(failed))

    -- GIANTS aktualisiert objectInfos und die Lager-Visuals zeitversetzt,
    -- wenn setObjectStorageObjectInfosDirty() aufgerufen wird. Nach mehreren
    -- Rueckfuehrungen reicht eine Anforderung am Ende des Cleanup.
    if returned > 0 then
        StorageAutoDriveObjects:markObjectStorageInfosDirty(session.storage,
            "Cleanup Job=" .. tostring(session.job and session.job.id) .. " returned=" .. tostring(returned))
    end

    -- Erst nachdem die eigenen Objekte verarbeitet wurden, werden die
    -- Runtime-Referenzen der Session freigegeben.
    session.pendingObject = nil
    session.pendingFilename = nil
    session.pendingSince = nil
    session.cleanupDone = true
    session.state = StorageAutoDriveSession.STATES.DONE
    StorageAutoDriveSession:markDirty(session)
end
