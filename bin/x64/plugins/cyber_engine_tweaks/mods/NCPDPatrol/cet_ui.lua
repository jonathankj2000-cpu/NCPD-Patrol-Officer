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
        -- Officer Down catalogue UI begin
        if ImGui.Button("Request Officer Down dispatch") then
            if Dispatch.requestOfficerDownNearby then Dispatch.requestOfficerDownNearby(getPatrolSystem(), status)
            else status("Officer Down dispatch module unavailable; install the complete package and restart") end
        end
        if Dispatch.officerDownState then ImGui.TextWrapped("Officer Down: " .. Dispatch.officerDownState()) end
        if Dispatch.officerDownCatalogueInfo then ImGui.TextWrapped(Dispatch.officerDownCatalogueInfo()) end
        -- Officer Down catalogue UI end
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
            -- Officer Down catalogue UI begin
            ImGui.TextWrapped("Officer Down: EUR$2000 and one career incident after both rescue and neutralization. Search expands from 1 km to 2 km and 5 km. Natural injured landings are checked for ground and aid access.")
            -- Officer Down catalogue UI end
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
        -- r5 marker UI begin
        if ImGui.CollapsingHeader("Fixed quest markers") then
            ImGui.TextWrapped("Scanner / VIP / Cyberpsycho: use this diagnostics control while a dispatch is active.")
            ImGui.TextWrapped(context.navigation.diagnostics())
            ImGui.TextWrapped("Before cleanup: " .. context.navigation.lastNative())
            if ImGui.Button("Log active dispatch marker diagnostics") then
                status("Fixed markers | " .. context.navigation.diagnostics())
                status("Fixed markers before cleanup | " .. context.navigation.lastNative())
            end
        end
        -- r5 marker UI end
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
        -- Officer Down catalogue UI begin
        if ImGui.CollapsingHeader("Officer Down: current dispatch") then
            if Dispatch.officerDownCatalogueInfo then ImGui.TextWrapped(Dispatch.officerDownCatalogueInfo()) end
            if Dispatch.officerDownState then ImGui.TextWrapped(Dispatch.officerDownState()) end
            if Dispatch.officerDownLogState then ImGui.TextWrapped(Dispatch.officerDownLogState()) end
            if ImGui.Button("Log Officer Down diagnostics") then status("Officer Down | " .. Dispatch.officerDownDiagnostics()) end
            if ImGui.Button("Export Officer Down gameplay report") then
                if Dispatch.exportOfficerDownLog then Dispatch.exportOfficerDownLog(status)
                else status("Officer Down dispatch module unavailable; install the complete package and restart") end
            end
            if ImGui.Button("Clear Officer Down scene") then Dispatch.clearOfficerDown(getPatrolSystem(), status) end
            ImGui.TextWrapped("Clear cancels the current Officer Down assignment and requests cleanup. Use a normal dispatch request to select a nearby catalogue location.")
        end
        -- Officer Down catalogue UI end
        -- v018i legacy recovery UI begin
        if ImGui.CollapsingHeader("Older marker test recovery") then
            ImGui.TextWrapped("For a leftover marker from an older experimental build. Removes only that experiment through its existing cleanup routine.")
            if context.markerProbe and ImGui.Button("Clear leftover quest marker experiment") then context.markerProbe.finish(status) end
        end
        -- v018i legacy recovery UI end
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
                -- v018f police fire UI begin
                if ImGui.Button("Log police fire diagnostics") then
                    local success, fire = pcall(function() return patrol:GetPoliceFireDiagnostics() end)
                    status("Police fire | " .. (success and fire or "Install the complete v0.18f package and fully restart the game."))
                end
                -- v018f police fire UI end
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
        ImGui.TextWrapped("Use a test save. Test grants and claimed rewards remain if you save. Session unlocks leave your real incident count unchanged.")
        if ImGui.CollapsingHeader("Dispatch scenarios") then
            if ImGui.Button("TEST: Request scanner dispatch") then Dispatch.request(getPatrolSystem(), status) end
            if ImGui.Button("Test timeout: 15 s left (on route)") then Dispatch.armTimeoutTest(getPatrolSystem(), status) end
            if ImGui.Button("TEST: Request VIP transport") then Dispatch.requestVIP(getPatrolSystem(), status) end
            if ImGui.Button("TEST: Trigger VIP ambush") then Dispatch.requestVIPAmbush(status) end
            if ImGui.Button("TEST: Request cyberpsycho dispatch") then Dispatch.requestCyberpsycho(getPatrolSystem(), status) end
            -- Officer Down catalogue UI begin
            if ImGui.Button("TEST: Request Officer Down dispatch") then
                if Dispatch.requestOfficerDownNearby then Dispatch.requestOfficerDownNearby(getPatrolSystem(), status)
                else status("Officer Down dispatch module unavailable") end
            end
            if ImGui.Button("Revive scene officer (nearby)") then Dispatch.reviveOfficerDown(status) end
            -- Officer Down catalogue UI end
            ImGui.TextWrapped("Next cyberpsycho: " .. Dispatch.cyberpsychoVariantState())
            if ImGui.Button("TEST: Next cyberpsycho variant") then Dispatch.cycleCyberpsychoVariant(status) end
            if ImGui.Button("Use random cyberpsycho variants") then Dispatch.randomCyberpsychoVariants(status) end
            ImGui.TextWrapped("Typed requests retain normal assignment and cleanup guards. They do not replace a current dispatch.")
        end
        -- qgiver UI begin
        if ImGui.CollapsingHeader("Quest giver prototype") then
            local test=context.questGiver
            ImGui.TextWrapped("OFF DUTY test: sends Mara Voss's SMS invitation and activates the meeting marker. Close CET and follow the marker. Voss prepares the arms-crossed pose on the ground while waiting; a pose warning retains the actors and meeting quest. Approaching within 3 m on foot starts the voiced conversation without restarting her body pose. The six-part Voss briefing and four original V replies play automatically, without dialogue choices. Enable subtitles; clear before replaying. The SMS stays in Messages.")
            if test then
                ImGui.TextWrapped(test.state())
                if ImGui.Button("TEST: Activate quest giver quest") then test.start(status) end
                if ImGui.Button("Clear quest giver test") then test.clear(status) end
                if ImGui.Button("Log quest giver diagnostics") then status("Quest giver test | "..test.diagnostics()) end
            end
            -- offbooks UI begin
            local operation=context.offBooks
            if operation then
                ImGui.TextWrapped(operation.state())
                if ImGui.Button("TEST: Continue Off the Books after briefing") then operation.begin(status) end
                if ImGui.Button("Clear Off the Books encounter only") then operation.clear(status) end
                if ImGui.Button("Log Off the Books diagnostics") then status("Off the Books | "..operation.diagnostics()) end
                ImGui.TextWrapped("Off-duty operation: eliminate the contractor, loot his actual evidence shard, lose any pursuing NCPD, then return to Voss. Native readable shards are kept in the Shards journal. This slice ends at the return objective; the debrief conversation is separate. Clearing only the encounter retains Voss for another test.")
            end
            -- offbooks UI end
            ImGui.TextWrapped("Voss: 1424.737, -2754.759, 204.665; yaw -143.376. A police Hella is parked across the scene 4 m behind her. Both actors spawn within 120 m. English voice and lipsync are included in the complete package.")
        end
        -- qgiver UI end
        if ImGui.CollapsingHeader("Partner recovery") then
            if ImGui.Button("Test: down partner") then
                local support = getSupportSystem()
                if support then support:DownPartner() end
            end
            ImGui.TextWrapped("Revive using the in-game interaction or Revive partner (nearby) under Patrol.")
        end
        if ImGui.CollapsingHeader("Reward equipment") then
            if ImGui.Button("TEST: Unlock all milestones (session)") then careerAction("test", true) end
            if ImGui.Button("Clear test unlocks") then careerAction("test", false) end
            if ImGui.Button("TEST: Give tiered reward weapons") then careerAction("weapons") end
            if ImGui.Button("TEST: Give Bean Bagger (Tier 2)") then careerAction("beanbagger") end
            ImGui.TextWrapped("Tiered tests need session unlocks: Bean Bagger T2, Lexington T2, Masamune T3 and Defender T5. The separate Bean Bagger button needs no unlock override. One test copy per weapon per session; claim receipts stay unchanged.")
        end
        if ImGui.CollapsingHeader("Audio previews") then
            if ImGui.Button("Test dispatch alert") then Dispatch.testAudio(getPatrolSystem(), false, status) end
            if ImGui.Button("Preview police radio (in vehicle)") then Dispatch.testAudio(getPatrolSystem(), true, status) end
        end
        heading("SCENE DEVELOPMENT - OFF DUTY")
        -- Officer Down UI begin
        if ImGui.CollapsingHeader("Scene survey: recorded sites") then
            local survey=context.sceneSurvey
            ImGui.TextWrapped("Recorded-site survey; current coverage is shown below. Use a manual test save, go OFF DUTY and exit your vehicle. The test moves V between recorded centers, spawns one protected scene, checks functional placement, confirms cleanup and returns to your start. Close CET and leave the game running. New candidates can be added to the survey catalogue before a later dispatch build.")
            if survey then
                ImGui.TextWrapped(survey.summary())
                ImGui.TextWrapped("Functional validation: the injured officer may land elsewhere inside the incident area. The test checks actual ground, local clearance, down-state and a complete walking route to a clear aid position within 2.5 m. That aid position must remain usable for three seconds. Spawn displacement is logged without correction or a precision limit. Actual F/revive execution still requires a gameplay test.")
                if ImGui.Button("TEST: Survey all recorded sites (compact)") then survey.startFunctional('compact',false,status) end
                if ImGui.Button("TEST: Survey all recorded sites (standard)") then survey.startFunctional('standard',false,status) end
                if ImGui.Button("TEST: Retry unverified survey sites") then survey.startFunctional('compact',true,status) end
                if ImGui.Button("Stop survey and return") then survey.cancel(status) end
                if ImGui.Button("Recover survey cleanup and return") then survey.recover(status) end
                if ImGui.Button("Load saved survey results") then survey.loadResults(status) end
                if ImGui.Button("Export scene survey report") then survey.export(status) end
                if ImGui.Button("Log scene survey diagnostics") then status('Scene survey | '..survey.diagnostics()) end
                ImGui.TextWrapped("Evidence: scene_survey_results.jsonl. Export: scene_survey_report.json. Both are inside the NCPDPatrol CET folder. Proven rotations are reused first on later tests. Temporary blockage remains eligible for retry. Cleanup must finish before another teleport. After a CET reload, use recovery; a saved-game reload never resumes the tour automatically. Transfers use controlled teleport and ground/navmesh checks; a memory-purging loading screen is not claimed.")
            end
        end
        -- Officer Down UI end
        -- v018g discovery UI begin
        if ImGui.CollapsingHeader("Scene discovery: terminal offsets") then
            local survey=context.sceneSurvey
            ImGui.TextWrapped("OFF DUTY developer test. Searches around the existing 60 terminal coordinates at 10/20/30 m in eight directions, trying both compact and standard layouts. Geometry and supported landing must pass before any actors spawn. Use a manual test save and exit your vehicle. The terminal itself need not have navmesh: a nearby supported staging point is checked first. Progress counts terminal/layout pairs, up to 120 for 60 anchors. The full search may take considerable time; begin with the nearest three terminals.")
            if survey and survey.startDiscovery then
                ImGui.TextWrapped(survey.discoverySummary())
                if ImGui.Button("TEST: Discover scenes near 3 closest terminals") then survey.startDiscovery('nearby',true,status) end
                if ImGui.Button("TEST: Discover scenes near all 60 terminals") then survey.startDiscovery('all',true,status) end
                if ImGui.Button("Stop discovery and return") then survey.cancel(status) end
                if ImGui.Button("Recover discovery cleanup and return") then survey.recover(status) end
                if ImGui.Button("Load discovery results") then survey.loadDiscovery(status) end
                if ImGui.Button("Export discovery report") then survey.exportDiscovery(status) end
            end
            ImGui.TextWrapped("Evidence: scene_discovery_results.jsonl. Export: scene_discovery_report.json, including verified_candidates with actual grounded coordinates, rotation and source terminal. Successful terminal/layout searches are skipped on later runs. Existing recorded surveys, approved dispatch sites and manual waypoints are preserved. Keep your previous discovery files: successful variants remain compatible. Stop/recovery waits for owned actors to detach before any return teleport; the reason stays visible during return and is included in last_run in the report.")
        end
        -- v018g discovery UI end
    end

    local tabs = {
        {name="Patrol", draw=drawPatrol}, {name="Dispatch", draw=drawDispatch},
        {name="Career", draw=drawCareer}, {name="Settings", draw=drawSettings},
        {name="Diagnostics", draw=drawDiagnostics}, {name="Testing", draw=drawTesting},
    }

    function menu.draw()
        ImGui.SetNextWindowSize(660, 620, ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowSizeConstraints(520, 360, 1600, 1200)
        local visible = ImGui.Begin("NCPD Patrol - v0.20e Evidence Receipt###NCPDPatrolWindow")
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
