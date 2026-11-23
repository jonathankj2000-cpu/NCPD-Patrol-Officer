-- Temporary, opt-in CET trace. Records requests/state; never changes audio or quests.
local M = {}
local capture, last, overlay, registered = nil, nil, false, false
local registrations = {}
local label = "Idle: arm before approaching Voss."
local OUTPUT = "voss_audio_capture.json"
local PREFIX = "ncpd_patrol_qgiver_test_"
local limits = {audio=768, subtitles=48, states=192, frame_gaps=64, errors=16}
local hooks = {"Play", "Stop", "Switch", "State", "GlobalParameter", "Parameter", "NotifyGameTone", "PlayOnEmitter"}
local expected_scene = {{2,300,16650,16950},{3,0,4500,4500},{4,300,22817,23117},{5,0,6000,6000},
    {6,300,12417,12717},{7,0,5000,5000},{8,300,29951,30251},{10,300,22817,23117},{13,0,8000,8000},{14,300,13384,13684}}

local function short(value, length)
    if value == nil then return nil end
    local ok, text = pcall(tostring, value)
    return ok and text:sub(1, length or 180) or "<unreadable>"
end

local function field(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    return ok and value or nil
end

local function identity(object)
    if not object then return nil end
    local ok, id = pcall(function() return object:GetEntityID() end)
    return ok and short(field(id, "hash")) or nil
end

local function sound_name(value)
    if type(value) == "userdata" and type(NameToString) == "function" then
        local ok, name = pcall(NameToString, value)
        if ok and type(name) == "string" and name ~= "" then return short(name) end
    end
    return short(value)
end

local function append(kind, row)
    local c = capture
    if not c then return end
    row.t = c.elapsed
    row.phase = c.scene_seen and "dialogue_or_postroll" or "preroll"
    local rows = c[kind]
    if not c.scene_seen and kind ~= "errors" then
        -- Only a short, bounded pre-roll survives the wait for the conversation.
        while rows[1] and (rows[1].t < c.elapsed - 3 or #rows >= 32) do table.remove(rows, 1) end
    end
    if #rows < limits[kind] then rows[#rows + 1] = row
    else c.dropped[kind] = c.dropped[kind] + 1 end
end

local function problem(where, message)
    if capture then
        capture.error_counts[where] = (capture.error_counts[where] or 0) + 1
        if capture.error_counts[where] == 1 then append("errors", {where=where, message=short(message, 300)}) end
    end
end

local function stage()
    return Game.GetQuestsSystem():GetFactStr(PREFIX .. "stage")
end

local function snapshot()
    local player = Game.GetPlayer()
    if not player or not player:IsAttached() then return nil, "Player unavailable" end
    local defs = GetAllBlackboardDefs()
    local boards = Game.GetBlackboardSystem()
    local psm = boards:GetLocalInstanced(player:GetEntityID(), defs.PlayerStateMachine)
    if not psm then return nil, "Player state blackboard unavailable" end
    local row = {quest_stage=stage(), player_id=identity(player), overlay=overlay}
    for _, name in ipairs({"SceneTier", "HighLevel", "UpperBody", "Zones"}) do
        local key = defs.PlayerStateMachine[name]
        if key then row[name] = psm:GetInt(key) end
    end
    local ui = boards:Get(defs.UI_System)
    if ui then row.in_menu = ui:GetBool(defs.UI_System.IsInMenu) end
    local system = Game.GetSceneSystem()
    local scene = system and system:GetScriptInterface()
    if scene then
        row.in_scene = scene:IsEntityInScene(player:GetEntityID())
        row.in_dialogue = scene:IsEntityInDialogue(player:GetEntityID())
    end
    return row
end

local function state_key(row)
    local keys = {"quest_stage", "player_id", "SceneTier", "HighLevel", "UpperBody", "Zones", "in_menu", "in_scene", "in_dialogue", "overlay"}
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(row[key]) end
    return table.concat(parts, "|")
end

local function sample()
    local ok, row, failure = pcall(snapshot)
    if not ok or not row then
        problem("state_sample", ok and failure or row)
        return
    end
    local key = state_key(row)
    if not capture.initial_state then capture.initial_state = row end
    if key ~= capture.previous_state then
        capture.previous_state = key
        append("states", row)
    end
end

local function audio(method, a, b, entity, emitter)
    if not capture then return end
    local c = capture
    c.observed_calls[method] = (c.observed_calls[method] or 0) + 1
    local row = {method=method, name=sound_name(a), value=sound_name(b), entity_id=short(field(entity, "hash")), emitter=sound_name(emitter)}
    local key = table.concat({method, row.name or "", row.entity_id or "", row.emitter or ""}, "|")
    local value = row.value or ""
    -- Keep recurring Play/Stop requests, but coalesce unchanged parameter writes.
    if method ~= "Play" and method ~= "Stop" and method ~= "PlayOnEmitter" then
        if c.previous_audio[key] == value then return end
        if c.previous_audio[key] == nil then
            if c.previous_audio_size >= 1024 then c.dropped.audio = c.dropped.audio + 1;return end
            c.previous_audio_size = c.previous_audio_size + 1
        end
        c.previous_audio[key] = value
    end
    append("audio", row)
end

local function subtitle(_, data)
    if not capture then return end
    capture.subtitle_callbacks = capture.subtitle_callbacks + 1
    local speaker = field(data, "speaker")
    local record
    if speaker then
        local ok, value = pcall(function() return speaker:GetRecordID() end)
        if ok then record = short(value) end
    end
    local text = field(data, "text")
    if not speaker and not text then problem("subtitle_decode", "Callback received, but line fields were unavailable") end
    local duration = field(data, "duration")
    if type(duration) ~= "number" or duration ~= duration or math.abs(duration) == math.huge then duration = short(duration) end
    append("subtitles", {source="SubtitleLineLogicController.SetLineData", event="data_received", line_id=short(field(data,"id")), speaker_id=identity(speaker), record=record,
        text_preview=short(text, 110), declared_duration=duration})
end

local function hidden(kind, rows)
    if not capture then return end
    capture.subtitle_hide_callbacks = capture.subtitle_hide_callbacks + 1
    local count = 0
    for _, value in ipairs(rows) do
        count = count + 1
        if count > 16 then capture.dropped.subtitles = capture.dropped.subtitles + 1;break end
        local id = kind == "hide_by_data" and field(value,"id") or value
        append("subtitles", {event=kind, line_id=short(id)})
    end
end

local function inspect_scene()
    -- Inspect after recording, so the diagnostic cannot pre-load the scene
    -- and accidentally hide a streaming problem during the conversation.
    local row = {path="base\\ncpd_patrol\\quest_giver_test\\conversation.scene", requested_after_recording=true,
        expected_v020f1_solution_hash="7566336010319024185", speech_sections={}}
    local ok, failure = pcall(function()
        local token = Game.GetResourceDepot():LoadResource(row.path)
        if not token then error("No resource token") end
        row.loaded, row.finished, row.failed = token:IsLoaded(), token:IsFinished(), token:IsFailed()
        if not row.loaded then return end
        local resource = token:GetResource()
        row.solution_hash = short(resource.sceneSolutionHash.sceneSolutionHash.sceneSolutionHashDate)
        local graph = resource.sceneGraph.graph
        local matches = true
        for _, expected in ipairs(expected_scene) do
            local node = graph[expected[1]]
            local event = node.events[1]
            local actual = {node=tonumber(node.nodeId.id),start_ms=tonumber(event.startTime),
                duration_ms=tonumber(event.duration),section_ms=tonumber(node.sectionDuration.stu)}
            row.speech_sections[#row.speech_sections + 1] = actual
            if actual.node ~= expected[1] or actual.start_ms ~= expected[2] or actual.duration_ms ~= expected[3] or actual.section_ms ~= expected[4] then matches = false end
        end
        row.timing_fields_match_v020f1 = matches
    end)
    if not ok then row.read_error = short(failure, 300) end
    return row
end

function M.export()
    if capture then return false, "Stop the current capture before exporting." end
    local report = last
    if not report then return false, "No completed capture yet." end
    if report.end_reason == "shutdown" or report.end_reason == "world_replaced" or report.end_reason == "world_unavailable" then
        report.loaded_scene = {skipped=report.end_reason} -- No engine access during teardown.
    else
        report.loaded_scene = inspect_scene()
    end
    local ok, body = pcall(function() return json.encode(report) end)
    if not ok or type(body) ~= "string" then label = "Capture retained in memory; JSON export failed."; return false, label end
    local opened, file, failure = pcall(io.open, OUTPUT, "w")
    if not opened or not file then label = "Capture retained in memory: " .. (short(opened and failure or file) or "open failed"); return false, label end
    local wrote, written, write_error = pcall(function() return file:write(body) end)
    local closed, close_result, close_error = pcall(function() return file:close() end)
    if not wrote or not written or not closed or not close_result then
        label = "Capture retained in memory: " .. (short(write_error or close_error or (not wrote and written)) or "write/close failed")
        return false, label
    end
    label = "Saved " .. OUTPUT .. " (" .. report.end_reason .. ")."
    return true, label
end

function M.finish(reason)
    if not capture then return false, "No capture is armed." end
    local c = capture
    capture = nil -- Never retain native objects, callbacks or live sampling after completion.
    c.end_reason = reason or "manual_stop"
    c.finished_at_t = c.elapsed
    c.previous_audio, c.previous_state, c.sample_clock, c.post_until = nil, nil, nil, nil
    last = c
    return M.export()
end

function M.arm()
    if capture then return false, "A capture is already armed." end
    if not registered then return false, "Wait for CET initialization." end
    local ok, message = pcall(function()
        local player = Game.GetPlayer()
        if not player or not player:IsAttached() or player:IsDead() then return "Load a live save first." end
        local systems = Game.GetScriptableSystemsContainer()
        local patrol = systems and systems:Get("NCPDPatrolSystem")
        if not patrol then return "NCPD Patrol is unavailable." end
        if patrol:IsOnDuty() then return "Run the Voss trace off duty." end
        if stage() == 2 then return "Arm before the conversation starts." end
        return nil
    end)
    if not ok or message then label = ok and message or ("Cannot arm: " .. short(message)); return false, label end
    local dropped = {};for key in pairs(limits) do dropped[key] = 0 end
    capture = {tool="NCPD Patrol Audio Trace", version="0.1", elapsed=0, scene_seen=false, sample_clock=0,
        audio={}, subtitles={}, states={}, frame_gaps={}, errors={}, dropped=dropped, observed_calls={},
        error_counts={}, subtitle_callbacks=0, subtitle_hide_callbacks=0, previous_audio={}, previous_audio_size=0, limits=limits,
        registration_attempts=registrations,
        coverage={time_source="CET onUpdate delta, not the audio sample clock", subtitle_markers_are_not_audible_voice_onsets=true,
            observes_script_facing_audio_requests_only=true, native_wwise_internals_observed=false,
            mixer_levels_measured=false, no_callbacks_is_not_proof_of_no_native_audio_changes=true}}
    label = "Armed. Close CET and approach Voss within three minutes."
    sample()
    return true, label
end

function M.update(delta)
    if not capture or type(delta) ~= "number" or delta ~= delta or delta <= 0 or delta == math.huge then return end
    local c = capture
    c.elapsed = c.elapsed + delta
    if not c.scene_seen then
        for _, kind in ipairs({"audio", "subtitles", "states", "frame_gaps"}) do
            local rows = c[kind]
            while rows[1] and rows[1].t < c.elapsed - 3 do table.remove(rows, 1) end
        end
    end
    if delta >= .12 then append("frame_gaps", {delta=delta, overlay=overlay}) end
    local ok, current = pcall(stage)
    if not ok then problem("quest_stage", current);return M.finish("world_unavailable") end
    if current == 2 and not c.scene_seen then
        c.scene_seen = true;c.scene_started_at_t = c.elapsed
        c.previous_audio = {} -- First observed values inside dialogue must be retained.
        c.previous_audio_size = 0
        c.previous_state = nil
        label = "Recording Voss conversation; export is automatic after it ends."
    end
    c.sample_clock = c.sample_clock + delta
    if c.sample_clock >= .05 then c.sample_clock = 0;sample() end
    if c.scene_seen then
        if current ~= 2 and not c.post_until then c.post_until = c.elapsed + 2 end
        if current == 2 then c.post_until = nil end
        if c.post_until and c.elapsed >= c.post_until then return M.finish("conversation_ended") end
        if c.elapsed - c.scene_started_at_t > 180 then return M.finish("conversation_timeout") end
    elseif c.elapsed > 180 then return M.finish("no_conversation_before_timeout") end
end

local function guarded(name, callback)
    return function(...)
        if not capture then return end
        local ok, failure = pcall(callback, ...)
        if not ok then problem(name, failure) end
    end
end

local function register()
    if registered then return end
    registered = true
    local function observe(class, method, callback)
        local ok, failure = pcall(Observe, class, method, callback)
        -- CET can also report a missing function only in its own log. A
        -- successful registration call alone is not callback-delivery proof.
        registrations[class .. "." .. method] = ok and "requested; inspect observed callback counts" or short(failure)
    end
    -- CET registrations happen only in onInit, avoiding dynamic worker/Lua lock inversion.
    for _, method in ipairs(hooks) do
        local name = method
        observe("AudioSystem", name, guarded("audio_" .. name, function(_, a, b, c, d)
            if name == "Play" or name == "Stop" then audio(name, a, nil, b, c)
            elseif name == "PlayOnEmitter" then audio(name, a, nil, b, c)
            else audio(name, a, b, c, d) end
        end))
    end
    observe("SubtitleLineLogicController", "SetLineData", guarded("subtitle_callback", subtitle))
    observe("BaseSubtitlesGameController", "HideDialogLinesByData", guarded("subtitle_hide_data", function(_, rows) hidden("hide_by_data", rows) end))
    observe("BaseSubtitlesGameController", "HideDialogLine", guarded("subtitle_hide_ids", function(_, rows) hidden("hide_by_id", rows) end))
    observe("PlayerPuppet", "OnGameAttached", function()
        if capture then M.finish("world_replaced") end
    end)
end

registerForEvent("onInit", register)
registerForEvent("onUpdate", M.update)
registerForEvent("onOverlayOpen", function() overlay = true end)
registerForEvent("onOverlayClose", function() overlay = false end)
registerForEvent("onShutdown", function() if capture then M.finish("shutdown") end end)
registerForEvent("onDraw", function()
    if not overlay then return end
    local visible = ImGui.Begin("NCPD Audio Trace (temporary)###NCPDAudioTrace")
    if visible then
        ImGui.TextWrapped(label)
        if ImGui.Button("Arm next Voss conversation") then M.arm() end
        if capture and ImGui.Button("Stop and export capture") then M.finish("manual_stop") end
        if last and not capture and ImGui.Button("Export last capture again") then M.export() end
        ImGui.TextWrapped("No audio or quest settings are changed. The trace does not measure the internal Wwise mix.")
        ImGui.TextWrapped("Output: NCPDPatrolAudioTrace/" .. OUTPUT)
    end
    ImGui.End()
end)

function M.status() return label end
return M
