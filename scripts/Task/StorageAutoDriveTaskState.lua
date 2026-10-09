StorageAutoDriveTaskState = {}

function StorageAutoDriveTaskState:isADFinished(session)
    StorageAutoDriveConfig:traceFunction("TASK", "StorageAutoDriveTaskState:isADFinished")
    if session == nil or session.vehicle == nil then return true end
    return StorageAutoDriveAutoDrive:hasTaskFinished(session.vehicle)
end

function StorageAutoDriveTaskState:update(session)
    StorageAutoDriveConfig:traceFunction("TASK", "StorageAutoDriveTaskState:update")
    if session == nil then return end

    -- AD-Fuellstand, AD-Zielprozente und eine selbst berechnete Ladequote
    -- sind kein Abschlusskriterium von STORAGEAUTODRIVE.
    -- AD/UAL bleiben fuer ihren eigenen Lade-/Fahrzustand verantwortlich.
    StorageAutoDriveConfig:debug(
        "TASK",
        "TaskState:update | Job=" .. tostring(session.job and session.job.id)
        .. " | state=" .. tostring(session.state)
        .. " | ADfinished=" .. tostring(self:isADFinished(session))
    )

    if session.state == StorageAutoDriveSession.STATES.WAITING_FOR_LOAD then
        return
    end

    if session.state == StorageAutoDriveSession.STATES.WAITING_FOR_AD_FINISH
        and self:isADFinished(session) then
        StorageAutoDriveSession:setState(
            session,
            StorageAutoDriveSession.STATES.COMPLETED,
            "AD-Auftrag beendet"
        )
    end
end
