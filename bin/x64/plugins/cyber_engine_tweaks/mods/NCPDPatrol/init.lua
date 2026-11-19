-- NCPD Patrol v0.17d CET refactor r2 | separated menu and live session
-- Upgrades the working v0.2 CET UI. No Equipment-EX dependency.
-- Start Shift gives the vanilla Police Uniform only when it is not owned.
-- No automatic equipping: player uses the game's Special Outfit slot.
-- The optional backup key has no default binding; the trunk needs none.

local Partner = require("partner")
local Dispatch = require("dispatch")
local VehicleRadio = require("vehicle_radio")
local Backup = require("backup")
local Arrest = require("arrest")
local Trunk = require("trunk")
local onDuty = false
local overlayOpen = false
local lastMessage = "Ready. Load a save and start a shift."
local dutyPoll, bonusPoll = 0, 0
local bridgeErrorReported = false
local scannerLogElapsed, scannerLogJobs, scannerLogTotal = 0, 0, 0
local scannerLogState = nil
local lastVoiceRevision = 0
-- The optional vcd_* record belongs to external vehicle mods,
-- so we must test for its existence before trying to unlock it.
local MODDED_POLICE_HELLA = "Vehicle.vcd_archer_hella_ncpd"
local VANILLA_POLICE_HELLA = "Vehicle.v_standard2_archer_hella_police"
local POLICE_OUTFIT_RECORD = "Items.SQ029_Police_Suit"

local function status(message)
    lastMessage = message
    print("[NCPD Patrol] " .. message)
end

local function isInGame()
    return Game ~= nil and Game.GetPlayer ~= nil and Game.GetPlayer() ~= nil
end

local function getPatrolSystem()
    local ok, system = pcall(function()
        return Game.GetScriptableSystemsContainer():Get("NCPDPatrolSystem")
    end)
    if ok and system then return system end
    return nil
end

local function getSupportSystem()
    local ok, system = pcall(function()
        return Game.GetScriptableSystemsContainer():Get("NCPDPatrolSupportSystem")
    end)
    if ok and system then return system end
    return nil
end

local function careerAction(method, value)
    local ok, result = pcall(function()
        local career = Game.GetScriptableSystemsContainer():Get("NCPDPatrolCareerSystem")
        if not career or career:Version() ~= 3 then error("Install the complete v0.17d package and restart") end
        if method == "test" then
            if not career:SetTestUnlocks(value) then return "Test unlock unavailable during combat, wanted status or an unloaded game." end
        elseif method == "claim" then
            career:ClaimNextReward()
        elseif method == "partner" then
            career:SelectPartner(value)
        elseif method == "weapons" then
            career:TestGiveTieredWeapons()
        elseif method == "beanbagger" then
            career:TestGiveBeanBagger()
        end
        return career:GetLastStatus()
    end)
    status("Career | " .. tostring(result))
end

local function requestBackup()
    local support = getSupportSystem()
    local ok, accepted = pcall(function()
        return support and support:Version() == 17 and support:RequestBackup()
    end)
    if not ok or not accepted then
        status("Backup request unavailable. Start a shift; only one patrol may be assigned.")
    end
end

local function logScanner(patrol, force)
    local ok, state, jobs, total, info = pcall(function()
        return patrol:GetMonitorState(), patrol:GetShiftJobs(), patrol:GetShiftBonus(), patrol:GetMonitorDiagnostics()
    end)
    if not ok then
        if not bridgeErrorReported then
            bridgeErrorReported = true
            status("Scanner diagnostics failed: " .. tostring(state))
        end
        return
    end
    if jobs > scannerLogJobs then
        status("BONUS PAID: +EUR$" .. tostring(total - scannerLogTotal)
            .. " | Paid this shift: " .. tostring(jobs) .. " | Total bonus: EUR$" .. tostring(total))
        force = true
    end
    if force or state ~= scannerLogState or scannerLogElapsed >= 15 then
        print("[NCPD Patrol] Scanner | " .. tostring(info))
        scannerLogElapsed = 0
        scannerLogState = state
    end
    scannerLogJobs, scannerLogTotal = jobs, total
end

-- Read-only record availability check; avoids reporting success for unknown vehicle IDs.
local function getVehicleRecordInfo(vehicleId)
    local ok, recordOrErr = pcall(function()
        return TweakDB:GetRecord(vehicleId)
    end)
    if not ok then return false, "TweakDB lookup failed: " .. tostring(recordOrErr) end
    if recordOrErr == nil then return false, "Vehicle record missing" end
    return true, "Vehicle record available"
end

local function assignVehicleById(vehicleId, label)
    if not isInGame() then
        status("Load a save before assigning a patrol car.")
        return false
    end
    local present, info = getVehicleRecordInfo(vehicleId)
    if not present then
        status(label .. ": " .. info .. ". No unlock attempted.")
        return false
    end

    local ok, resultOrErr = pcall(function()
        local system = Game.GetVehicleSystem()
        if system == nil then error("VehicleSystem unavailable") end
        system:EnablePlayerVehicle(vehicleId, true, false)
        return system:IsVehiclePlayerUnlocked(vehicleId)
    end)
    if not ok then
        status(label .. ": unlock failed: " .. tostring(resultOrErr))
        return false
    end
    if resultOrErr then
        status(label .. ": unlock confirmed by VehicleSystem. Check vehicle summon menu; some police records need an extra UI/summon tweak.")
        return true
    end
    status(label .. ": unlock sent but ownership not confirmed. Verify TweakXL is active, restart after installing the YAML, then use Check vehicle records and ownership.")
    return false
end

local function assignPatrolCar()
    -- v0.2.3 deliberately prefers the stock NCPD Hella, which the bundled
    -- TweakXL YAML appends to the player's garage-eligible vehicle list.
    -- Do not depend on an optional Virtual Car Dealer vehicle record.
    return assignVehicleById(VANILLA_POLICE_HELLA, "NCPD Hella (vanilla police variant)")
end

local function showVehicleDiagnostics()
    if not isInGame() then
        status("Load a save to check police vehicle records.")
        return
    end
    local modPresent, modInfo = getVehicleRecordInfo(MODDED_POLICE_HELLA)
    local vanillaPresent, vanillaInfo = getVehicleRecordInfo(VANILLA_POLICE_HELLA)
    local function ownership(id, present)
        if not present then return "n/a" end
        local ok, unlocked = pcall(function() return Game.GetVehicleSystem():IsVehiclePlayerUnlocked(id) end)
        return ok and (unlocked and "yes" or "no") or "unavailable"
    end
    status("Fleet Hella: " .. (modPresent and "exists" or "missing") .. ", owned=" .. ownership(MODDED_POLICE_HELLA, modPresent)
        .. " | Vanilla police Hella: " .. (vanillaPresent and "exists" or "missing")
        .. ", owned=" .. ownership(VANILLA_POLICE_HELLA, vanillaPresent))
end

-- Uses the same item-ownership query as other CET inventory mods.
-- If ownership cannot be read, do not risk giving duplicate outfits.
local function getPoliceOutfitCount()
    if not isInGame() then return nil, "No loaded save" end
    local ok, result = pcall(function()
        local transaction = Game.GetTransactionSystem()
        if transaction == nil then error("TransactionSystem unavailable") end
        local query = ItemID.CreateQuery(TweakDBID.new(POLICE_OUTFIT_RECORD))
        return transaction:GetItemQuantity(Game.GetPlayer(), query)
    end)
    if not ok then return nil, tostring(result) end
    if type(result) ~= "number" then
        return nil, "Unexpected inventory quantity: " .. tostring(result)
    end
    return result
end

local function ensurePoliceOutfit()
    if not isInGame() then
        status("Load a save before requesting the police outfit.")
        return false
    end

    local count, err = getPoliceOutfitCount()
    if count == nil then
        status("Cannot verify police outfit ownership: " .. tostring(err) .. ". No item added.")
        return false
    end
    if count > 0 then
        status("Police Uniform already owned. Equip it in Inventory > Special Outfit.")
        return true
    end

    local ok, grantErr = pcall(function()
        Game.AddToInventory(POLICE_OUTFIT_RECORD, 1)
    end)
    if not ok then
        status("Unable to add Police Uniform: " .. tostring(grantErr))
        return false
    end

    local after, checkErr = getPoliceOutfitCount()
    if after ~= nil and after > 0 then
        status("Police Uniform added! Equip in Inventory > Special Outfit. Save if it appears.")
        return true
    end
    status("Item command sent, but ownership was not confirmed (" .. tostring(checkErr or "not in inventory") .. "). Check Special Outfit; this quest item may be restricted.")
    return false
end

local function startShift()
    if not isInGame() then
        status("Load a save before starting a shift.")
        return
    end
    if onDuty then
        status("Already on duty.")
        return
    end
    local patrol = getPatrolSystem()
    if not patrol then
        status("NCPD Patrol redscript module unavailable. Install r6/scripts/NCPDPatrol and restart the game.")
        return
    end
    local ok, err = pcall(function()
        local support = getSupportSystem()
        if not support or support:Version() ~= 17 then error("Install all v0.17d support files and restart the game") end
        if not support:IsPartnerDownConfigured() then error("Partner down effect unavailable. Install the complete mod, including NCPDPatrol_PartnerDown.yaml, and restart the game") end
        if patrol:Version() ~= 17 then error("Lua/redscript version mismatch; install all v0.17d files and restart the game") end
        Trunk.prepareShift()
        patrol:BeginShift()
        if not patrol:IsOnDuty() then error("Cannot start a shift while wanted") end
    end)
    if not ok then status("Cannot start shift: " .. tostring(err)); return end
    onDuty = true
    bonusPoll = 0
    scannerLogElapsed, scannerLogJobs, scannerLogTotal = 0, 0, 0
    scannerLogState = nil
    bridgeErrorReported = false
    logScanner(patrol, true)
    Dispatch.start(patrol, status)
    VehicleRadio.reset()
    assignPatrolCar()
    ensurePoliceOutfit()
    print("[NCPD Patrol] On duty. Existing NCPD Scanner missions are unchanged.")
    Partner.spawn(onDuty, status)
end

local function endShift()
    if not isInGame() then
        status("Load a save before ending a shift.")
        return
    end
    if not onDuty then
        status("Already off duty.")
        return
    end
    local patrol = getPatrolSystem()
    if patrol then
        Trunk.finish()
        Backup.finish(getSupportSystem(), status)
        VehicleRadio.finish(patrol)
        Dispatch.finish(patrol, status)
        patrol:FinishShift()
        logScanner(patrol, true)
    end
    onDuty = false
    Arrest.finish()
    Partner.dismiss(status)
    if patrol and patrol:WasTerminatedForCrime() then
        status("Shift terminated due to criminal activity.")
    else
        status("Off duty. Vehicle and Police Uniform stay unlocked; worn outfit unchanged.")
    end
end

local function toggleDuty()
    if onDuty then endShift() else startShift() end
end

local function forgetLoadedWorld()
    -- Also forget failed cleanup IDs when the previous shift was already over.
    -- This callback must never delete entities or unregister old native handles.
    Partner.reset()
    Backup.reset()
    Dispatch.reset()
    VehicleRadio.reset()
    Arrest.reset()
    Trunk.reset()
    onDuty = false
    scannerLogState = nil
    dutyPoll, bonusPoll = 0, 0
end

registerForEvent("onInit", function()
    Dispatch.init()
    Observe("PlayerPuppet", "OnGameAttached", forgetLoadedWorld)
    status("v0.17d CET refactor r2 loaded. Patrol, Dispatch, Career, Settings, Diagnostics and Testing tabs. Existing gameplay and dispatch refactor retained. Install the complete package and restart.")
end)

-- Preserve the hotkey ID from v0.1.1 / v0.2, with no default binding.
registerHotkey("ncpdpatrol_toggle_duty", "NCPD Patrol - Toggle duty", toggleDuty)
-- Optional binding only; the trunk interaction is the normal in-game control.
registerHotkey("ncpdpatrol_request_backup", "NCPD Patrol - Request backup", requestBackup)

registerForEvent("onOverlayOpen", function() overlayOpen = true end)
registerForEvent("onOverlayClose", function() overlayOpen = false end)

registerForEvent("onUpdate", function(delta)
    if not isInGame() then
        Trunk.reset()
        Arrest.reset()
        if onDuty then Partner.reset(); Backup.reset(); Dispatch.reset(); VehicleRadio.reset(); onDuty = false end
        return
    end
    dutyPoll = dutyPoll + delta
    bonusPoll = bonusPoll + delta
    if onDuty then scannerLogElapsed = scannerLogElapsed + delta end
    if dutyPoll >= 0.25 then
        dutyPoll = 0
        local ok, err = pcall(function()
            local patrol = getPatrolSystem()
            if not patrol then return end
            if patrol:Version() ~= 17 then return end
            patrol:EnforceDutyRules()
            if onDuty and not patrol:IsOnDuty() then
                onDuty = false
                if patrol:WasTerminatedForCrime() then
                    Trunk.finish()
                    Arrest.finish()
                    Backup.finish(getSupportSystem(), status)
                    VehicleRadio.finish(patrol)
                    Dispatch.finish(patrol, status)
                    Partner.dismiss(status)
                    status("Shift terminated due to criminal activity.")
                else
                    -- Loading a save reset the native session; old actor IDs are stale.
                    Partner.reset()
                    Backup.reset()
                    Dispatch.reset()
                    VehicleRadio.reset()
                    Arrest.reset()
                    Trunk.reset()
                end
                scannerLogState = nil
            end
            local request = patrol:TakeDutyRequest()
            if request == 1 then startShift() elseif request == 2 then endShift() end
            if onDuty and bonusPoll >= 1 then
                bonusPoll = 0
                patrol:TickBonuses()
                logScanner(patrol, false)
            end
            local revision = patrol:GetVoiceDiagnosticRevision()
            if revision ~= lastVoiceRevision then
                print("[NCPD Patrol] Voice | " .. tostring(patrol:GetVoiceDiagnostics()))
                lastVoiceRevision = revision
            end
        end)
        if not ok and not bridgeErrorReported then
            bridgeErrorReported = true
            status("Duty/bonus control failed: " .. tostring(err))
        end
    end
    Partner.update(delta, onDuty, status)
    Backup.update(delta, onDuty, getSupportSystem(), getPatrolSystem(), status)
    Trunk.update(delta, onDuty, getPatrolSystem(), status)
    Dispatch.update(delta, onDuty, status, getPatrolSystem)
    VehicleRadio.update(delta, onDuty, status, getPatrolSystem)
    local arrestPaused = true
    pcall(function() arrestPaused = getPatrolSystem():IsDispatchMenuOpen() end)
    Arrest.update(delta, onDuty, arrestPaused)
end)

registerForEvent("onShutdown", function()
    Trunk.finish()
    Backup.finish(getSupportSystem(), nil)
    VehicleRadio.finish(getPatrolSystem())
    Dispatch.shutdown(getPatrolSystem())
    pcall(function()
        local patrol = getPatrolSystem()
        if patrol then patrol:ResetSession() end
    end)
    Arrest.finish()
    Partner.dismiss(function() end)
end)

-- The menu reads live session state and routes actions to the existing owners.
local menu = require("cet_ui").new({
    partner=Partner, dispatch=Dispatch, backup=Backup, arrest=Arrest,
    trunk=Trunk, vehicleRadio=VehicleRadio,
    isOnDuty=function() return onDuty end,
    getLastMessage=function() return lastMessage end,
    status=status, toggleDuty=toggleDuty, requestBackup=requestBackup,
    getPatrolSystem=getPatrolSystem, getSupportSystem=getSupportSystem,
    careerAction=careerAction, assignPatrolCar=assignPatrolCar,
    ensurePoliceOutfit=ensurePoliceOutfit, showVehicleDiagnostics=showVehicleDiagnostics,
    assignVanillaHella=function()
        assignVehicleById(VANILLA_POLICE_HELLA, "NCPD Hella (vanilla police variant)")
    end,
    logScanner=logScanner,
})

registerForEvent("onDraw", function()
    if overlayOpen then menu.draw() end
end)
