-- Ballen-/Objekttyp-Erkennung fuer StorageAutoDrive.
-- Die Funktion liegt separat, damit die allgemeine Utils-Datei uebersichtlich bleibt.
-- Keine Aenderungen an AutoDrive oder Universal Autoload.

StorageAutoDriveBaleObjects = {}

function StorageAutoDriveBaleObjects:getObjectType(object)
    StorageAutoDriveConfig:traceFunction("BALES", "StorageAutoDriveBaleObjects:getObjectType")
    if object == nil then
        return "UNKNOWN"
    end

    local realObject = StorageAutoDriveUtils:getRealObject(object)
    if realObject == nil then
        realObject = object
    end

    -- Zuerst konkrete Laufzeitmerkmale pruefen.
    if realObject.isBale == true then
        return "BALE"
    end
    if realObject.getIsBale ~= nil then
        local ok, result = pcall(function()
            return realObject:getIsBale()
        end)
        if ok and result == true then
            return "BALE"
        end
    end

    if realObject.isPallet == true then
        return "PALLET"
    end
    if realObject.getIsPallet ~= nil then
        local ok, result = pcall(function()
            return realObject:getIsPallet()
        end)
        if ok and result == true then
            return "PALLET"
        end
    end

    -- Fallback auf Dateiinformationen nur dann, wenn Laufzeitmerkmale
    -- den Objekttyp nicht eindeutig bestaetigt haben.
    local filename = StorageAutoDriveUtils:getObjectFilename(realObject)
    if filename ~= nil then
        local lower = string.lower(tostring(filename))
        if string.find(lower, "bale", 1, true) ~= nil then
            return "BALE"
        end
        if string.find(lower, "pallet", 1, true) ~= nil then
            return "PALLET"
        end
    end

    return "UNKNOWN"
end


local function safeCall(object, method, ...)
    if object == nil or type(object[method]) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(object[method], object, ...)
    if ok then return a, b, c, d, e, f, g end
    return nil
end

function StorageAutoDriveBaleObjects:getRegisteredBaleInfo(object)
    local filename = StorageAutoDriveUtils:getObjectFilename(object)
    if filename == nil or g_baleManager == nil then return nil, nil end
    local index = safeCall(g_baleManager, "getBaleTypeIndexByXMLFilename", filename)
    if index == nil then
        local lower = string.lower(tostring(filename))
        local bales = g_baleManager.bales or {}
        for i, bale in ipairs(bales) do
            local registered = bale ~= nil and bale.xmlFilename or nil
            if registered ~= nil then
                local lowerRegistered = string.lower(tostring(registered))
                if lower == lowerRegistered or string.sub(lower, -#lowerRegistered) == lowerRegistered
                    or string.sub(lowerRegistered, -#lower) == lower then
                    index = i
                    break
                end
            end
        end
    end
    local baleInfo = index ~= nil and g_baleManager.bales ~= nil and g_baleManager.bales[index] or nil
    return baleInfo, filename
end

function StorageAutoDriveBaleObjects:matchesSelection(abstractObject, selection)
    if abstractObject == nil or selection == nil then return false, "missing object/selection" end
    local baleInfo, filename = self:getRegisteredBaleInfo(abstractObject)
    if baleInfo == nil then return false, "unregistered bale XML=" .. tostring(filename) end
    local expectedRound = selection.shape == "ROUND"
    if (baleInfo.isRoundbale == true) ~= expectedRound then
        return false, "shape mismatch"
    end
    local fillTypeFound = false
    for _, ft in ipairs(baleInfo.fillTypes or {}) do
        if ft ~= nil and ft.fillTypeIndex == selection.fillTypeIndex then
            fillTypeFound = true
            break
        end
    end
    if not fillTypeFound then return false, "fillType mismatch" end

    if selection.wrapRequirement ~= nil then
        local wrapState = nil
        local realObject = StorageAutoDriveUtils:getRealObject(abstractObject)
        local candidates = {abstractObject, realObject}
        for _, candidate in ipairs(candidates) do
            if candidate ~= nil then
                if type(candidate.getWrappingState) == "function" then
                    wrapState = safeCall(candidate, "getWrappingState")
                end
                if wrapState == nil then wrapState = candidate.wrappingState end
                if wrapState == nil and type(candidate.attributes) == "table" then wrapState = candidate.attributes.wrappingState end
                if wrapState == nil and type(candidate.baleAttributes) == "table" then wrapState = candidate.baleAttributes.wrappingState end
                if wrapState ~= nil then break end
            end
        end
        if wrapState == nil then return false, "wrapping state unavailable" end
        local isWrapped = tonumber(wrapState) ~= nil and tonumber(wrapState) > 0.001
        if isWrapped ~= selection.wrapRequirement then return false, "wrap mismatch" end
    end
    return true, "match"
end
