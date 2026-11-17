-- NCPD Patrol v0.6a | partner aid and one backup patrol via native interactions
-- Upgrades the working v0.2 CET UI. No Equipment-EX dependency.
-- Start Shift gives the vanilla Police Uniform only when it is not owned.
-- No automatic equipping: player uses the game's Special Outfit slot.
-- The optional backup key has no default binding; the trunk needs none.

local Partner = require("partner")
local Dispatch = require("dispatch")
local VehicleRadio = require("vehicle_radio")
local Backup = require("backup")
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

local function requestBackup()
    local support = getSupportSystem()
    local ok, accepted = pcall(function()
        return support and support:Version() == 11 and support:RequestBackup()
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
        if not support or support:Version() ~= 11 then error("Install all v0.6a support files and restart the game") end
        if patrol:Version() ~= 11 then error("Lua/redscript version mismatch; install all v0.6a files and restart the game") end
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
        Backup.finish(getSupportSystem(), status)
        VehicleRadio.finish(patrol)
        Dispatch.finish(patrol, status)
        patrol:FinishShift()
        logScanner(patrol, true)
    end
    onDuty = false
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
    onDuty = false
    scannerLogState = nil
    dutyPoll, bonusPoll = 0, 0
end

registerForEvent("onInit", function()
    Dispatch.init()
    Observe("PlayerPuppet", "OnGameAttached", forgetLoadedWorld)
    status("v0.6a loaded. Partner revive and one backup patrol from your police car's trunk. Backup key is optional in CET Bindings.")
end)

-- Preserve the hotkey ID from v0.1.1 / v0.2, with no default binding.
registerHotkey("ncpdpatrol_toggle_duty", "NCPD Patrol - Toggle duty", toggleDuty)
-- Optional binding only; the trunk interaction is the normal in-game control.
registerHotkey("ncpdpatrol_request_backup", "NCPD Patrol - Request backup", requestBackup)

registerForEvent("onOverlayOpen", function() overlayOpen = true end)
registerForEvent("onOverlayClose", function() overlayOpen = false end)

registerForEvent("onUpdate", function(delta)
    if not isInGame() then
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
            if patrol:Version() ~= 11 then return end
            patrol:EnforceDutyRules()
            if onDuty and not patrol:IsOnDuty() then
                onDuty = false
                if patrol:WasTerminatedForCrime() then
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
    Dispatch.update(delta, onDuty, status, getPatrolSystem)
    VehicleRadio.update(delta, onDuty, status, getPatrolSystem)
end)

registerForEvent("onShutdown", function()
    Backup.finish(getSupportSystem(), nil)
    VehicleRadio.finish(getPatrolSystem())
    Dispatch.shutdown(getPatrolSystem())
    pcall(function()
        local patrol = getPatrolSystem()
        if patrol then patrol:ResetSession() end
    end)
    Partner.dismiss(function() end)
end)

registerForEvent("onDraw", function()
    if not overlayOpen then return end
    local visible = ImGui.Begin("NCPD Patrol - v0.6a")
    if visible then
        ImGui.Text("PATROL STATUS")
        ImGui.Separator()
        ImGui.Text(onDuty and "ON DUTY" or "OFF DUTY")
        ImGui.TextWrapped("Use a Fast Travel terminal for Start Shift / End Shift. These controls remain available for diagnostics.")
        if ImGui.Button(onDuty and "End Shift" or "Start Shift") then
            toggleDuty()
        end

        ImGui.Separator()
        ImGui.Text("DISPATCH")
        ImGui.TextWrapped("Dispatch searches within 1 km, then 1.5 km and 2 km. Empty searches retry after 30 seconds. Request a call now to skip the automatic wait.")
        if ImGui.Button("Request dispatch now") then
            Dispatch.request(getPatrolSystem(), status)
        end
        if ImGui.Button("Cancel active dispatch") then
            Dispatch.cancel(getPatrolSystem(), status)
        end
        if ImGui.Button(Dispatch.isAutomatic() and "Pause automatic dispatch" or "Resume automatic dispatch") then
            Dispatch.setAutomatic(not Dispatch.isAutomatic(), status)
        end
        if ImGui.Button(Dispatch.isSoundEnabled() and "Mute dispatch alert" or "Enable dispatch alert") then
            Dispatch.setSoundEnabled(not Dispatch.isSoundEnabled(), status)
        end
        if ImGui.Button("Test dispatch alert") then
            Dispatch.testAudio(getPatrolSystem(), false, status)
        end
        if ImGui.Button(Dispatch.isVoiceEnabled() and "Mute dispatch voice" or "Enable dispatch voice") then
            Dispatch.setVoiceEnabled(not Dispatch.isVoiceEnabled(), status)
        end
        if ImGui.Button("Preview police radio (in vehicle)") then
            Dispatch.testAudio(getPatrolSystem(), true, status)
        end
        ImGui.TextWrapped("The confirmed police radio line accompanies new dispatch notices. Custom on-scene briefs can be added later.")
        local voicePatrol = getPatrolSystem()
        if voicePatrol then
            local ok, info = pcall(function() return voicePatrol:GetVoiceDiagnostics() end)
            ImGui.TextWrapped(ok and info or "Voice diagnostics unavailable; install all v0.6a files.")
        end
        ImGui.TextWrapped("Navigation: " .. Dispatch.navigationState())
        if ImGui.Button(VehicleRadio.isEnabled() and "Mute vehicle chatter" or "Enable vehicle chatter") then
            VehicleRadio.setEnabled(not VehicleRadio.isEnabled(), getPatrolSystem(), status)
        end
        ImGui.TextWrapped("Vehicle radio: " .. VehicleRadio.state())
        ImGui.TextWrapped(Dispatch.state())
        ImGui.Text("Dispatches completed: " .. tostring(Dispatch.completed()))
        if onDuty and Dispatch.isAutomatic() and not Dispatch.isActive() then
            ImGui.Text("Next automatic call in about " .. tostring(Dispatch.seconds()) .. " s (pauses in menus/combat).")
        end
        ImGui.TextWrapped("Objective display: " .. Dispatch.hudState())

        ImGui.Separator()
        ImGui.Text("NCPD PATROL VEHICLE")
        ImGui.TextWrapped("Vanilla NCPD Hella. Bundled TweakXL tweak adds it to the garage-eligible vehicle list; Start Shift requests ownership.")
        if ImGui.Button("Check vehicle records and ownership") then
            showVehicleDiagnostics()
        end
        if ImGui.Button("Assign / re-check NCPD Hella") then
            assignPatrolCar()
        end
        if ImGui.Button("Try vanilla police Hella explicitly") then
            assignVehicleById(VANILLA_POLICE_HELLA, "NCPD Hella (vanilla police variant)")
        end
        ImGui.TextWrapped("After updating: restart the game, reassign the car, then check ownership and the summon menu. If ownership still says no, report the exact status.")

        ImGui.Separator()
        ImGui.Text("POLICE UNIFORM - VANILLA SPECIAL OUTFIT")
        ImGui.TextWrapped("Start Shift grants the existing River Ward quest uniform once if it is not owned. No Equipment-EX or wardrobe setup.")
        if ImGui.Button("Grant / check Police Uniform") then
            ensurePoliceOutfit()
        end
        ImGui.TextWrapped("Equip manually via Inventory > Special Outfit. End Shift does not remove or unequip it.")

        ImGui.Separator()
        ImGui.Text("NCPD PARTNER")
        ImGui.TextWrapped("Start Shift automatically calls one NCPD partner to follow you. End Shift dismisses your partner.")
        if ImGui.Button("Spawn partner") then
            Partner.spawn(onDuty, status)
        end
        if ImGui.Button("Dismiss partner") then
            Partner.dismiss(status)
        end
        if ImGui.Button("Check partner state") then
            status(Partner.state())
        end
        ImGui.TextWrapped("Current state: " .. Partner.state())
        ImGui.TextWrapped("Vehicle: " .. Partner.vehicleState())
        ImGui.TextWrapped("Revive: " .. Partner.aidState())
        ImGui.TextWrapped("When your partner is down, approach and use Revive Partner. Stay within 2.5 m for 3 seconds.")
        if ImGui.Button("Test: down partner") then
            local support = getSupportSystem()
            if support then support:DownPartner() end
        end
        if ImGui.Button("Revive partner (nearby)") then
            local support = getSupportSystem()
            if support then support:StartPartnerRevive() end
        end
        ImGui.TextWrapped("Dismiss removes your partner for the current shift. Use Spawn partner if you want to call another one.")

        ImGui.Separator()
        ImGui.Text("NCPD BACKUP")
        ImGui.TextWrapped("On duty, use Request NCPD Backup at your owned police car's trunk, beside stash. One car with two officers responds. Optional key: CET Bindings > NCPD Patrol - Request backup.")
        if ImGui.Button("Request backup patrol") then requestBackup() end
        ImGui.TextWrapped(Backup.state())
        ImGui.TextWrapped("One patrol per scene. Move 150 m away from the scene, officers and car for 3 seconds to release it. Use a clear roadside location for this first driving test.")
        ImGui.Separator()
        ImGui.Text("SCANNER BONUS")
        ImGui.TextWrapped("EUR$1000 for each eligible NCPD combat activity completed on duty. Reported Crime follow-ups are not included in this build.")
        local patrol = getPatrolSystem()
        if patrol then
            local ok, info = pcall(function()
                if patrol:Version() ~= 11 then return "Version mismatch: install all v0.6a files and restart the game." end
                return patrol:GetMonitorDiagnostics()
                    .. " | Last payment: EUR$" .. tostring(patrol:GetLastBonusAmount())
            end)
            ImGui.TextWrapped(ok and info or ("Scanner diagnostics failed: " .. tostring(info)))
            if ImGui.Button("Log scanner diagnostics") then logScanner(patrol, true) end
        else
            ImGui.TextWrapped("NCPD Patrol redscript module unavailable.")
        end
        ImGui.Separator()
        ImGui.Text("STATUS / DIAGNOSTICS")
        ImGui.TextWrapped(lastMessage)
        ImGui.TextWrapped("Shift status resets on game reload.")
    end
    ImGui.End()
end)
