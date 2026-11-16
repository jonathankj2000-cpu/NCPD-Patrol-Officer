-- NCPD Patrol v0.4a | terminal duty, scanner bonuses, explicit passenger boarding
-- Upgrades the working v0.2 CET UI. No Equipment-EX dependency.
-- Start Shift gives the vanilla Police Uniform only when it is not owned.
-- No automatic equipping: player uses the game's Special Outfit slot.
-- Native partner AI is updated while on duty. No quest edits or new key bindings.

local Partner = require("partner")
local onDuty = false
local overlayOpen = false
local lastMessage = "Ready. Load a save and start a shift."
local dutyPoll, bonusPoll = 0, 0
local bridgeErrorReported = false
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
        if patrol:Version() ~= 4 then error("Lua/redscript version mismatch") end
        patrol:BeginShift()
    end)
    if not ok then status("Cannot start shift: " .. tostring(err)); return end
    onDuty = true
    bonusPoll = 0
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
    if patrol then patrol:FinishShift() end
    onDuty = false
    Partner.dismiss(status)
    status("Off duty. Vehicle and Police Uniform stay unlocked; worn outfit unchanged.")
end

local function toggleDuty()
    if onDuty then endShift() else startShift() end
end

registerForEvent("onInit", function()
    status("v0.4a loaded. Start/End Shift at a Fast Travel terminal. Scanner bonus: EUR$1000 per eligible activity.")
end)

-- Preserve the hotkey ID from v0.1.1 / v0.2, with no default binding.
registerHotkey("ncpdpatrol_toggle_duty", "NCPD Patrol - Toggle duty", toggleDuty)

registerForEvent("onOverlayOpen", function() overlayOpen = true end)
registerForEvent("onOverlayClose", function() overlayOpen = false end)

registerForEvent("onUpdate", function(delta)
    if not isInGame() then
        if onDuty then Partner.reset(); onDuty = false end
        return
    end
    dutyPoll = dutyPoll + delta
    bonusPoll = bonusPoll + delta
    if dutyPoll >= 0.25 then
        dutyPoll = 0
        local ok, err = pcall(function()
            local patrol = getPatrolSystem()
            if not patrol then return end
            if onDuty and not patrol:IsOnDuty() then
                -- Loading a save reset the native session; old actor IDs are stale.
                onDuty = false
                Partner.reset()
            end
            local request = patrol:TakeDutyRequest()
            if request == 1 then startShift() elseif request == 2 then endShift() end
            if onDuty and bonusPoll >= 1 then
                bonusPoll = 0
                patrol:TickBonuses()
            end
        end)
        if not ok and not bridgeErrorReported then
            bridgeErrorReported = true
            status("Duty/bonus control failed: " .. tostring(err))
        end
    end
    Partner.update(delta, onDuty, status)
end)

registerForEvent("onShutdown", function()
    pcall(function()
        local patrol = getPatrolSystem()
        if patrol then patrol:ResetSession() end
    end)
    Partner.dismiss(function() end)
end)

registerForEvent("onDraw", function()
    if not overlayOpen then return end
    local visible = ImGui.Begin("NCPD Patrol - v0.4a")
    if visible then
        ImGui.Text("PATROL STATUS")
        ImGui.Separator()
        ImGui.Text(onDuty and "ON DUTY" or "OFF DUTY")
        ImGui.TextWrapped("Use a Fast Travel terminal for Start Shift / End Shift. These controls remain available for diagnostics.")
        if ImGui.Button(onDuty and "End Shift" or "Start Shift") then
            toggleDuty()
        end

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
        ImGui.TextWrapped("Dismiss removes your partner for the current shift. Use Spawn partner if you want to call another one.")

        ImGui.Separator()
        ImGui.Text("SCANNER BONUS")
        ImGui.TextWrapped("EUR$1000 for each eligible NCPD combat activity completed on duty. Reported Crime follow-ups are not included in this build.")
        local patrol = getPatrolSystem()
        if patrol then
            local ok, info = pcall(function()
                return (patrol:IsMonitorReady() and "Monitor ready" or "Monitor idle / waiting")
                    .. " | Activities: " .. tostring(patrol:GetShiftJobs())
                    .. " | Shift bonus: EUR$" .. tostring(patrol:GetShiftBonus())
            end)
            ImGui.TextWrapped(ok and info or "Scanner diagnostics unavailable")
        end
        ImGui.Separator()
        ImGui.Text("STATUS / DIAGNOSTICS")
        ImGui.TextWrapped(lastMessage)
        ImGui.TextWrapped("Shift status resets on game reload.")
    end
    ImGui.End()
end)
