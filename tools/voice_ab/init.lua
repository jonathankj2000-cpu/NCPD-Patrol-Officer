-- Explicit developer A/B control. Plays four individual native dialog events
-- on V; never starts a scene, changes metadata, moves/spawns actors or mutes.
local M = {}
local active, last, initialized, overlay = nil, nil, false, false
local label = "Idle. Stand still off duty, away from an active conversation."
local output = "voss_voice_ab_result.json"
local tracks = {
    {name="A1: original V", kind="stock", id=1938843197804515328ULL, slot=10},
    {name="A2: original V", kind="stock", id=1895381798296993792ULL, slot=10},
    {name="B1: Voss 01", kind="custom", id=7936178618028821476ULL, slot=20},
    {name="B2: Voss 03", kind="custom", id=7936180817052077898ULL, slot=16},
}

local function short(value) return tostring(value):sub(1, 280) end
local function log(message) print("[NCPD Voice A/B] " .. message) end
local function player_id(player) return short(player:GetEntityID().hash) end

local function metadata_status()
    local container = Game.GetScriptableServiceContainer()
    if not container then error("Codeware service container unavailable") end
    local service = container:GetService(CName.new("NCPDPatrolVossLengthTest"))
    if not service then return "Length experiment not installed" end
    local status = service:GetDiagnostics()
    if not status:find("disabled=true", 1, true) then
        error("VO Lengths experiment is still active. Disable it and fully restart the game.")
    end
    return status
end

local function snapshot()
    local player = Game.GetPlayer()
    if not player or not player:IsAttached() or player:IsDead() then error("Load a live player") end
    if player:IsInCombat() then error("Leave combat before this developer test") end
    local patrol = Game.GetScriptableSystemsContainer():Get("NCPDPatrolSystem")
    if not patrol or patrol:IsOnDuty() or patrol:HasWantedLevel() then error("Off duty and no wanted level required") end
    local defs = GetAllBlackboardDefs()
    local boards = Game.GetBlackboardSystem()
    local psm = boards:GetLocalInstanced(player:GetEntityID(), defs.PlayerStateMachine)
    if not psm then error("Player state unavailable") end
    local row = {player_id=player_id(player), overlay=overlay}
    for _, name in ipairs({"SceneTier", "HighLevel", "UpperBody", "Zones"}) do
        row[name] = psm:GetInt(defs.PlayerStateMachine[name])
    end
    local ui = boards:Get(defs.UI_System)
    row.in_menu = not ui or ui:GetBool(defs.UI_System.IsInMenu)
    local scene = Game.GetSceneSystem():GetScriptInterface()
    row.in_scene = scene:IsEntityInScene(player:GetEntityID())
    row.in_dialogue = scene:IsEntityInDialogue(player:GetEntityID())
    if row.in_menu or row.SceneTier > 1 or row.HighLevel > 1 or row.in_dialogue then
        error("Finish the current conversation/scene and close game menus")
    end
    if Game.GetQuestsSystem():GetFactStr("ncpd_patrol_qgiver_test_stage") == 2 then
        error("Finish Voss's quest conversation before running this separate test")
    end
    -- Optional, read-only evidence. An unavailable getter is not recorded as false.
    local ok, ff = pcall(function()
        return {default=scene:IsFastForwardingActive(Enum.new("scnFastForwardMode", "Default")),
            review=scene:IsFastForwardingActive(Enum.new("scnFastForwardMode", "GameplayReview"))}
    end)
    if ok then row.fast_forward_default, row.fast_forward_review = ff.default, ff.review
    else row.fast_forward_error = short(ff) end
    return player, row
end

function M.export()
    if active then return false, "Finish or cancel the test before export" end
    if not last then return false, "No result yet" end
    local ok, failure = pcall(function()
        local body = json.encode(last)
        local file, reason = io.open(output, "w")
        if not file then error(reason or "Output unavailable") end
        local wrote, write_error = file:write(body)
        local closed, close_error = file:close()
        if not wrote or not closed then error(write_error or close_error or "Export failed") end
    end)
    if not ok then label = "Export failed: " .. short(failure); return false, label end
    return true, "Exported " .. output
end

function M.finish(reason)
    if not active then return false, "No active test" end
    local run = active
    active = nil -- Never stop or mute other audio. A sent line may finish naturally.
    run.end_reason = reason
    run.finished_at_t = run.elapsed
    run.previous_state, run.sample_clock, run.silence, run.remaining = nil, nil, nil, nil
    last = run
    label = reason == "four_events_sent" and "Four native events sent. Confirm all four were audible; event delivery is not playback proof."
        or "Test ended: " .. short(reason)
    log(label)
    return M.export()
end

function M.arm()
    if not initialized or active then return false, "Wait for initialization or finish the active test" end
    local ok, player, row = pcall(snapshot)
    if not ok then label = short(player); return false, label end
    local checked, meta = pcall(metadata_status)
    if not checked then label = short(meta); return false, label end
    active = {tool="NCPD Voice A/B", version="0.1", elapsed=0, silence=0, remaining=0, sample_clock=0,
        index=0, player_id=row.player_id, states={}, frame_gaps={}, queued={}, dropped_states=0, dropped_gaps=0,
        rollback_status=meta, wait_for_overlay_seconds=0,
        coverage={native_event_queue_only=true, quest_scene_started=false, player_emitter_for_both_groups=true,
            queued_is_not_proof_of_audible_playback=true, actual_audio_measured=false,
            time_source="CET update delta; not an audio clock", npc_emitter_tested=false}}
    label = "Armed. Close CET; the first line starts after 3 seconds. About 59 seconds total."
    return true, label
end

local function send(track, player)
    local event = NewObject("gameaudioeventsDialogLine")
    local data = NewObject("audioDialogLineEventData")
    if not event or not data then error("Native dialog event/data type unavailable") end
    data.stringId = CRUID.new(track.id)
    data.context = Enum.new("locVoiceoverContext", "Vo_Context_Minor_Activity")
    data.expression = Enum.new("locVoiceoverExpression", "Vo_Expression_Spoken")
    data.isPlayer, data.isRewind, data.isHolocall = true, false, false
    data.customVoEvent = CName.new("None")
    data.seekTime, data.playbackSpeedParameter = 0, 1
    event.data = data -- Reflected native struct is assigned back by value.
    local check = event.data
    if check.stringId.hash ~= track.id or not check.isPlayer or check.isRewind or check.isHolocall
        or check.seekTime ~= 0 or check.playbackSpeedParameter ~= 1 then
        error("Native dialog event readback failed; nothing queued")
    end
    player:QueueEvent(event)
    return {label=track.name, kind=track.kind, string_id=short(track.id), emitter_id=player_id(player),
        context="Vo_Context_Minor_Activity", expression="Vo_Expression_Spoken", is_player=true,
        is_rewind=false, is_holocall=false, seek_time=0, playback_speed=1, slot_seconds=track.slot}
end

function M.update(delta)
    if not active or type(delta) ~= "number" or delta ~= delta or delta <= 0 or delta == math.huge then return end
    local run = active
    run.elapsed = run.elapsed + delta
    if delta >= .12 then
        if #run.frame_gaps < 64 then run.frame_gaps[#run.frame_gaps+1] = {t=run.elapsed, delta=delta}
        else run.dropped_gaps = run.dropped_gaps + 1 end
    end
    local ok, player, row = pcall(snapshot)
    if not ok then return M.finish("guard: " .. short(player)) end
    if row.player_id ~= run.player_id then return M.finish("player_replaced") end
    run.sample_clock = run.sample_clock + delta
    if run.sample_clock >= .05 then
        run.sample_clock = 0
        local key = table.concat({row.player_id, tostring(row.SceneTier), tostring(row.HighLevel), tostring(row.UpperBody),
            tostring(row.Zones), tostring(row.in_scene), tostring(row.in_dialogue), tostring(row.overlay),
            tostring(row.fast_forward_default), tostring(row.fast_forward_review), tostring(row.fast_forward_error)}, "|")
        if key ~= run.previous_state then
            run.previous_state = key; row.t = run.elapsed
            if #run.states < 128 then run.states[#run.states+1] = row else run.dropped_states = run.dropped_states+1 end
        end
    end
    if overlay then
        if run.index > 0 then return M.finish("overlay_reopened; remaining events cancelled") end
        run.silence = 0
        run.wait_for_overlay_seconds = run.wait_for_overlay_seconds + delta
        if run.wait_for_overlay_seconds > 45 then return M.finish("overlay_not_closed") end
        return
    end
    if run.index == 0 then
        run.silence = run.silence + delta
        if run.silence < 3 then return end
    else
        run.remaining = run.remaining - delta
        if run.remaining > 0 then return end
        if run.index == #tracks then return M.finish("four_events_sent") end
    end
    run.index = run.index + 1
    local sent, result = pcall(send, tracks[run.index], player)
    if not sent then run.dispatch_failure = short(result); return M.finish("native_event_failed") end
    result.t = run.elapsed; run.queued[#run.queued+1] = result
    run.remaining = tracks[run.index].slot
    label = tracks[run.index].name .. " sent. Keep CET closed and listen to the background at its start/end."
    log(label)
end

registerForEvent("onInit", function()
    if initialized then return end
    -- Register once on init, never from an audio/worker callback or onUpdate.
    local ok, failure = pcall(Observe, "PlayerPuppet", "OnGameAttached", function() if active then M.finish("world_replaced") end end)
    if not ok then label = "Initialization failed: " .. short(failure); return end
    initialized = true
end)
registerForEvent("onUpdate", M.update)
registerForEvent("onOverlayOpen", function() overlay = true end)
registerForEvent("onOverlayClose", function() overlay = false end)
registerForEvent("onShutdown", function() if active then M.finish("shutdown") end end)
registerForEvent("onDraw", function()
    if not overlay then return end
    local visible = ImGui.Begin("NCPD Voice A/B (temporary)###NCPDVoiceAB")
    if visible then
        ImGui.TextWrapped(label)
        ImGui.TextWrapped("Plays 2 original V lines, then Voss 01 and 03 directly on V, outside the quest scene. No Voss NPC or quest is needed.")
        if ImGui.Button("Run voice A/B comparison") then M.arm() end
        if active and ImGui.Button("Cancel remaining events") then M.finish("manual_cancel") end
        if last and not active and ImGui.Button("Export last result again") then M.export() end
        ImGui.TextWrapped("Stay off duty and close CET after arming. Reopening CET cancels the remaining lines; a current line may finish naturally.")
        ImGui.TextWrapped("Output: NCPDPatrolVoiceAB/" .. output)
    end
    ImGui.End()
end)

function M.status() return label end
return M
