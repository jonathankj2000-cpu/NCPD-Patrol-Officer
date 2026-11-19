-- CET presentation only. The entrypoint owns the live session and supplies its
-- existing actions; feature modules and native systems retain gameplay guards.
local M = {}

function M.new(context)
    local Partner, Dispatch = context.partner, context.dispatch
    local Backup, Arrest = context.backup, context.arrest
    local Trunk, VehicleRadio = context.trunk, context.vehicleRadio
    local status = context.status
    local getPatrolSystem, getSupportSystem = context.getPatrolSystem, context.getSupportSystem
    local careerAction = context.careerAction
    local menu = {}
    local renderErrors = {}

    local function heading(label)
        ImGui.Spacing()
        ImGui.Text(label)
        ImGui.Separator()
    end

    local function careerSystem()
        local ok, career = pcall(function()
            local system = Game.GetScriptableSystemsContainer():Get("NCPDPatrolCareerSystem")
            if system and system:Version() == 3 then return system end
        end)
        return ok and career or nil
    end

    local function testUnlocksActive()
        local ok, active = pcall(function()
            local career = careerSystem()
            return career and career:IsTestUnlockActive()
        end)
        return ok and active == true
    end

    local function drawPatrol()
        ImGui.TextWrapped("Start or end your shift at a Fast Travel terminal. At your police car's trunk: tap R for backup, hold R for Patrol Menu (secondary interaction binding).")
        local repairSeconds = Trunk.repairSeconds()
        if repairSeconds > 0 then ImGui.Text("Vehicle repair: " .. tostring(repairSeconds) .. " s remaining") end

        heading("PARTNER")
        ImGui.TextWrapped("Current state: " .. Partner.state())
        ImGui.TextWrapped("Active profile: " .. Partner.activeProfile())
        ImGui.TextWrapped("Vehicle: " .. Partner.vehicleState() .. " | Revive: " .. Partner.aidState())
        if ImGui.Button("Spawn partner") then Partner.spawn(context.isOnDuty(), status) end
        if ImGui.Button("Request new partner") then Partner.replace(context.isOnDuty(), status) end
        if ImGui.Button("Dismiss partner") then Partner.dismiss(status) end
        if ImGui.Button("Revive partner (nearby)") then
            local support = getSupportSystem()
            if support then support:StartPartnerRevive() end
        end
        ImGui.TextWrapped("Revive a downed partner within 2.5 m for 3 seconds. Choose unlocked partner profiles under Career.")

        heading("BACKUP")
        ImGui.TextWrapped(Backup.state())
        if ImGui.Button("Request backup patrol") then context.requestBackup() end
        if ImGui.Button("10-4: Release backup") then Backup.release(getSupportSystem(), getPatrolSystem(), status) end
        ImGui.TextWrapped("One car with two officers. 10-4 releases their follower duty; let seated officers exit. They stay on scene until you leave the area.")

        if ImGui.CollapsingHeader("Patrol vehicle and uniform") then
            if ImGui.Button("Assign / re-check NCPD Hella") then context.assignPatrolCar() end
            if ImGui.Button("Grant / check Police Uniform") then context.ensurePoliceOutfit() end
            ImGui.TextWrapped("Start Shift requests the car and grants the uniform once if missing. Equip the uniform in Inventory > Special Outfit.")
        end
        if ImGui.CollapsingHeader("Arrests and in-game controls") then
            ImGui.TextWrapped("Arrest: " .. Arrest.state())
            ImGui.TextWrapped("On duty, use Arrest suspect on a living, downed enemy. Stay within 2.5 m for 2 seconds. Each registered arrest pays EUR$250 separately.")
            ImGui.TextWrapped("Bosses, civilians, police, companions and quest-marked bodies are excluded. Move suspects to flat, clear ground if required.")
            ImGui.TextWrapped("The trunk menu uses 1-7; 9 closes. Repair, dispatch replacement, availability and partner replacement are also available there.")
        end
    end

    local function drawDispatch()
        ImGui.TextWrapped(Dispatch.state())
        ImGui.TextWrapped("Automatic dispatch: " .. Dispatch.schedulerStatus(getPatrolSystem()))
        ImGui.Text("Completed: " .. tostring(Dispatch.completed()) .. " | Failed: " .. tostring(Dispatch.failedCount()))
        ImGui.TextWrapped("Last result: " .. Dispatch.lastOutcome())
        if ImGui.Button("Request dispatch now") then Dispatch.requestMixed(getPatrolSystem(), status) end
        if ImGui.Button("Cancel active dispatch") then Dispatch.cancel(getPatrolSystem(), status) end
        if ImGui.Button(Dispatch.isAutomatic() and "Pause automatic dispatch" or "Resume automatic dispatch") then
            Dispatch.setAutomatic(not Dispatch.isAutomatic(), status)
        end
        ImGui.TextWrapped("Mix: " .. Dispatch.mixDescription() .. ". Unavailable types fall back to another type. Busy pauses automatic calls.")
        heading("CURRENT INCIDENTS")
        ImGui.TextWrapped("VIP: " .. Dispatch.vipState())
        ImGui.TextWrapped("Cyberpsycho: " .. Dispatch.cyberpsychoState())
        ImGui.TextWrapped("Navigation: " .. Dispatch.navigationState())
        if ImGui.CollapsingHeader("Dispatch rules and payments") then
            ImGui.TextWrapped("Scanner search expands from 1 km to 1.5 km and 2 km; empty searches retry after 30 seconds. Scanner response deadline: 3 minutes, paused in menus and cleared On scene.")
            ImGui.TextWrapped("Scanner bonus: EUR$1000. An attended scanner dispatch adds EUR$500 with a separate receipt. VIP delivery: EUR$2000. Cyberpsycho: EUR$3000, plus EUR$500 for non-lethal neutralization.")
            ImGui.TextWrapped("VIP delivery unlocks after boarding an owned police car. Stop at the destination and let the witness exit. Cyberpsycho threats spawn when you arrive at the assigned scene.")
            ImGui.TextWrapped("GPS may require opening and closing the map. Marker recovery and detailed state are under Diagnostics; typed dispatch tests are under Testing.")
        end
    end

    local function drawCareer()
        local career = careerSystem()
        local ok, info = pcall(function()
            if not career then return nil end
            return {rank=career:GetRank(), count=career:GetRecordedActivities(), next=career:GetNextMilestone(),
                reward=career:GetNextReward(), percent=career:GetProgressPercent(), available=career:GetAvailableRewards()}
        end)
        if ok and info then
            ImGui.Text("RANK: " .. tostring(info.rank))
            ImGui.Text("Incidents resolved: " .. tostring(info.count) .. " | Rewards available: " .. tostring(info.available))
            local fraction = math.max(0, math.min(1, info.percent / 100))
            ImGui.ProgressBar(fraction, -1, 0, info.next > 0 and (tostring(info.count) .. " / " .. tostring(info.next) .. " incidents") or "All milestones reached")
            ImGui.TextWrapped("Next reward: " .. tostring(info.reward))
        else
            ImGui.TextWrapped("Career details unavailable. Load a save with the complete mod installed.")
        end
        if ImGui.Button("Cop Stats") then Trunk.showStats(status) end
        if ImGui.Button("Claim next milestone reward") then careerAction("claim") end
        if ImGui.Button("Open NCPD Career (computer browser)") then
            local success, result = pcall(function()
                local browser = Game.GetScriptableSystemsContainer():Get("NCPDPatrol.Career.NCPDPatrolCareerBrowserState")
                if not browser or browser:Version() ~= 1 then error("Install the complete v0.17d package and restart") end
                if not browser:OpenCareer() then return "Open a computer's Net browser first; check career browser diagnostics if the page is unavailable." end
                return "Career page requested on the current computer."
            end)
            status("Career browser | " .. tostring(result))
        end
        ImGui.TextWrapped("The computer page needs the optional Browser Extension. Stats, rewards and partner selection remain available here.")
        if ImGui.CollapsingHeader("Partner assignment (CET fallback)") then
            if career then
                ImGui.TextWrapped("Selected: " .. tostring(career:GetSelectedPartnerName()))
                for index = 0, career:PartnerCount() - 1 do
                    local name = tostring(career:PartnerName(index))
                    local label = career:IsPartnerUnlocked(index) and ("Assign " .. name) or ("LOCKED: " .. name)
                    if ImGui.Button(label) then careerAction("partner", index) end
                end
                ImGui.TextWrapped("Selection applies at shift start or Request new partner; it does not replace your current partner immediately.")
            else
                ImGui.TextWrapped("Load a save to select a partner.")
            end
        end
    end

    local function drawSettings()
        heading("DISPATCH AUDIO")
        if ImGui.Button(Dispatch.isSoundEnabled() and "Mute dispatch alert" or "Enable dispatch alert") then
            Dispatch.setSoundEnabled(not Dispatch.isSoundEnabled(), status)
        end
        if ImGui.Button(Dispatch.isVoiceEnabled() and "Mute dispatch voice" or "Enable dispatch voice") then
            Dispatch.setVoiceEnabled(not Dispatch.isVoiceEnabled(), status)
        end
        ImGui.TextWrapped("The police radio line accompanies new dispatch notices. Audio previews are under Testing.")
        heading("VEHICLE CHATTER")
        if ImGui.Button(VehicleRadio.isEnabled() and "Mute vehicle chatter" or "Enable vehicle chatter") then
            VehicleRadio.setEnabled(not VehicleRadio.isEnabled(), getPatrolSystem(), status)
        end
        ImGui.TextWrapped("Vehicle radio: " .. VehicleRadio.state())
        heading("ENCOUNTER PREFERENCES")
        if ImGui.Button("Ambush cars: " .. Dispatch.vipAmbushCars() .. " (change)") then Dispatch.cycleVIPAmbushCars(status) end
        ImGui.TextWrapped("VIP ambushes can use 1-3 cars. The default is random. Cyberpsycho variant selection is grouped with its manual tests.")
        heading("CONTROLS")
        ImGui.TextWrapped("Optional key bindings: CET > Bindings > NCPD Patrol - Toggle duty / Request backup. Fast Travel terminals and the trunk work without extra hotkeys.")
        ImGui.TextWrapped("Shift status resets on game reload. Earned career progress and claimed rewards remain saved.")
    end

    local function drawDiagnostics()
        ImGui.TextWrapped("Diagnostic buttons write details to the CET log. Recovery controls use the existing feature guards.")
        if ImGui.CollapsingHeader("Dispatch, journal and navigation") then
            ImGui.TextWrapped("Journal: " .. Dispatch.journalDiagnostics())
            ImGui.TextWrapped("Objective display: " .. Dispatch.hudState())
            ImGui.TextWrapped("VIP ambush: " .. Dispatch.vipAmbushState())
            if ImGui.Button("Log automatic dispatch diagnostics") then status("Automatic dispatch | " .. Dispatch.schedulerDiagnostics(getPatrolSystem())) end
            if ImGui.Button("Log dispatch journal diagnostics") then status("Dispatch journal | " .. Dispatch.journalDiagnostics()) end
            if ImGui.Button("Log VIP diagnostics") then status("VIP | " .. Dispatch.vipDiagnostics()) end
            if ImGui.Button("Log cyberpsycho diagnostics") then status("Cyberpsycho | " .. Dispatch.cyberpsychoDiagnostics()) end
            if ImGui.Button("Log incident reward diagnostics") then status("Incident rewards | " .. Dispatch.rewardDiagnostics()) end
            if ImGui.Button("Rebuild VIP waypoint") then Dispatch.refreshVIPWaypoint(getPatrolSystem(), status) end
        end
        if ImGui.CollapsingHeader("Partner AI and officer readiness") then
            if ImGui.Button("Check partner state") then status(Partner.state()) end
            if ImGui.Button("Log partner AI diagnostics") then
                status("Partner AI | " .. Partner.diagnostics())
                print("[NCPD Patrol] Partner health | " .. Partner.healthDiagnostics())
            end
            if ImGui.Button("Log officer readiness (partner + backup)") then
                status("Partner readiness | " .. Partner.readinessDiagnostics())
                print("[NCPD Patrol] " .. Backup.diagnostics())
            end
        end
        if ImGui.CollapsingHeader("Scanner bonus and radio") then
            local patrol = getPatrolSystem()
            if patrol then
                local ok, info = pcall(function()
                    if patrol:Version() ~= 17 then return "Version mismatch: install all v0.17d files and restart the game." end
                    return patrol:GetMonitorDiagnostics() .. " | Last payment: EUR$" .. tostring(patrol:GetLastBonusAmount())
                end)
                ImGui.TextWrapped(ok and info or ("Scanner diagnostics failed: " .. tostring(info)))
                if ImGui.Button("Log scanner diagnostics") then context.logScanner(patrol, true) end
                local success, voice = pcall(function() return patrol:GetVoiceDiagnostics() end)
                ImGui.TextWrapped(success and voice or "Voice diagnostics unavailable; install all v0.17d files.")
            else
                ImGui.TextWrapped("NCPD Patrol redscript module unavailable.")
            end
        end
        if ImGui.CollapsingHeader("Career browser and equipment") then
            if ImGui.Button("Log career browser diagnostics") then
                local ok, result = pcall(function()
                    local browser = Game.GetScriptableSystemsContainer():Get("NCPDPatrol.Career.NCPDPatrolCareerBrowserState")
                    if not browser or browser:Version() ~= 1 then error("Install the complete v0.17d package and restart") end
                    return browser:GetDiagnostics()
                end)
                status("Career browser | " .. tostring(result))
            end
            if ImGui.Button("Log Bean Bagger diagnostics") then
                local ok, info = pcall(function()
                    local system = Game.GetScriptableSystemsContainer():Get("NCPDPatrolBeanBaggerSystem")
                    if not system or system:Version() ~= 1 then error("Install all v0.17d files and restart") end
                    return system:GetDiagnostics()
                end)
                status("Bean Bagger | " .. tostring(info))
            end
            if ImGui.Button("Check vehicle records and ownership") then context.showVehicleDiagnostics() end
            if ImGui.Button("Try vanilla police Hella explicitly") then context.assignVanillaHella() end
        end
    end

    local function drawTesting()
        -- r4 probe UI begin
        if ImGui.CollapsingHeader("Quest marker experiment") then
            local probe = context.markerProbe
            ImGui.TextWrapped("OFF DUTY test: a fixed native quest marker 150 m ahead of your starting position. Set a manual waypoint first, then compare both on the map. This does not replace dispatch markers or award credits.")
            ImGui.TextWrapped(probe.state())
            if ImGui.Button("TEST: Start static quest marker") then probe.start(status) end
            if ImGui.Button("Remove quest marker test") then probe.finish(status) end
            if ImGui.Button("Log quest marker test diagnostics") then status("Quest marker test | " .. probe.diagnostics()) end
            ImGui.TextWrapped("Activation: Active. Cleanup: Inactive. If not confirmed after five seconds, log diagnostics, then remove the test. Each start sends exactly one native request. No game-engine success is assumed.")
        end
        -- r4 probe UI end
        ImGui.TextWrapped("Use a test save. Test grants and claimed rewards remain if you save. Session unlocks leave your real incident count unchanged.")
        if ImGui.Button("TEST: Unlock all milestones (session)") then careerAction("test", true) end
        if ImGui.Button("Clear test unlocks") then careerAction("test", false) end
        if ImGui.CollapsingHeader("Dispatch scenarios") then
            if ImGui.Button("TEST: Request scanner dispatch") then Dispatch.request(getPatrolSystem(), status) end
            if ImGui.Button("Test timeout: 15 s left (on route)") then Dispatch.armTimeoutTest(getPatrolSystem(), status) end
            if ImGui.Button("TEST: Request VIP transport") then Dispatch.requestVIP(getPatrolSystem(), status) end
            if ImGui.Button("TEST: Trigger VIP ambush") then Dispatch.requestVIPAmbush(status) end
            if ImGui.Button("TEST: Request cyberpsycho dispatch") then Dispatch.requestCyberpsycho(getPatrolSystem(), status) end
            ImGui.TextWrapped("Next cyberpsycho: " .. Dispatch.cyberpsychoVariantState())
            if ImGui.Button("TEST: Next cyberpsycho variant") then Dispatch.cycleCyberpsychoVariant(status) end
            if ImGui.Button("Use random cyberpsycho variants") then Dispatch.randomCyberpsychoVariants(status) end
            ImGui.TextWrapped("Typed requests retain normal assignment and cleanup guards. They do not replace a current dispatch.")
        end
        if ImGui.CollapsingHeader("Partner recovery") then
            if ImGui.Button("Test: down partner") then
                local support = getSupportSystem()
                if support then support:DownPartner() end
            end
            ImGui.TextWrapped("Revive using the in-game interaction or Revive partner (nearby) under Patrol.")
        end
        if ImGui.CollapsingHeader("Reward equipment") then
            if ImGui.Button("TEST: Give tiered reward weapons") then careerAction("weapons") end
            if ImGui.Button("TEST: Give Bean Bagger (Tier 2)") then careerAction("beanbagger") end
            ImGui.TextWrapped("Tiered tests need session unlocks: Bean Bagger T2, Lexington T2, Masamune T3 and Defender T5. The separate Bean Bagger button needs no unlock override. One test copy per weapon per session; claim receipts stay unchanged.")
        end
        if ImGui.CollapsingHeader("Audio previews") then
            if ImGui.Button("Test dispatch alert") then Dispatch.testAudio(getPatrolSystem(), false, status) end
            if ImGui.Button("Preview police radio (in vehicle)") then Dispatch.testAudio(getPatrolSystem(), true, status) end
        end
    end

    local tabs = {
        {name="Patrol", draw=drawPatrol}, {name="Dispatch", draw=drawDispatch},
        {name="Career", draw=drawCareer}, {name="Settings", draw=drawSettings},
        {name="Diagnostics", draw=drawDiagnostics}, {name="Testing", draw=drawTesting},
    }

    function menu.draw()
        ImGui.SetNextWindowSize(660, 620, ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowSizeConstraints(520, 360, 1600, 1200)
        local visible = ImGui.Begin("NCPD Patrol - v0.17d quest marker test r4b###NCPDPatrolWindow")
        if visible then
            ImGui.Text((context.isOnDuty() and "ON DUTY" or "OFF DUTY") .. "  |  " .. (Dispatch.isBusy() and "BUSY" or "AVAILABLE"))
            if ImGui.Button(context.isOnDuty() and "End Shift" or "Start Shift") then context.toggleDuty() end
            ImGui.SameLine()
            if ImGui.Button(Dispatch.isBusy() and "Set AVAILABLE" or "Set BUSY") then Trunk.setBusy(not Dispatch.isBusy(), status) end
            if testUnlocksActive() then
                ImGui.TextColored(1, 0.72, 0.25, 1, "TEST UNLOCKS ACTIVE - clear under Testing")
            end
            if ImGui.BeginTabBar("NCPDPatrolTabs") then
                for _, tab in ipairs(tabs) do
                    if ImGui.BeginTabItem(tab.name) then
                        -- Each tab retains its own scroll position. Reserve a
                        -- font-scaled footer so long diagnostics cannot hide it.
                        local footerHeight = ImGui.GetTextLineHeightWithSpacing() * 3 + 12
                        local childVisible = ImGui.BeginChild("NCPDPatrolContent_" .. tab.name, 0, -footerHeight, false)
                        if childVisible then
                            local ok, err = pcall(tab.draw)
                            if ok then
                                renderErrors[tab.name] = nil
                            else
                                ImGui.TextWrapped("This panel is unavailable. See the CET log for details.")
                                local message = tostring(err)
                                if renderErrors[tab.name] ~= message then
                                    renderErrors[tab.name] = message
                                    status("CET UI | " .. tab.name .. ": " .. message)
                                end
                            end
                        end
                        ImGui.EndChild()
                        ImGui.EndTabItem()
                    end
                end
                ImGui.EndTabBar()
            end
            ImGui.Separator()
            ImGui.Text("LAST STATUS")
            local footerVisible = ImGui.BeginChild("NCPDPatrolLastStatus", 0, 0, false)
            if footerVisible then ImGui.TextWrapped(context.getLastMessage()) end
            ImGui.EndChild()
        end
        ImGui.End()
    end

    return menu
end

return M
