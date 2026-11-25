-- Retire the silent direct-event experiment without any playback hooks.
local overlay = false
registerForEvent("onInit", function()
    print("[NCPD Voice A/B] Direct-event control disabled: no audible playback in game. Use the existing Voss scene for the stock-audio control.")
end)
registerForEvent("onOverlayOpen", function() overlay = true end)
registerForEvent("onOverlayClose", function() overlay = false end)
registerForEvent("onDraw", function()
    if not overlay then return end
    local visible = ImGui.Begin("NCPD Voice A/B (disabled)###NCPDVoiceAB")
    if visible then
        ImGui.TextWrapped("The direct voice comparison was silent in game and is disabled. Use NCPD Patrol's existing quest-giver test to meet Voss. In the stock-scene control, she deliberately speaks with V's original voice.")
    end
    ImGui.End()
end)
