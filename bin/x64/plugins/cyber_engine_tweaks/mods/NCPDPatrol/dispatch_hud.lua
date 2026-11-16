-- Small in-game objective display; independent of CET's overlay window.
local M = {}
local widget, initialized = nil, false
local text, visible = "", false
local state = "Waiting for the game HUD"

local function removeWidget()
    if widget then
        pcall(function()
            local parent = widget:GetParentWidget()
            if parent then parent:RemoveChild(widget) end
        end)
    end
    widget = nil
end

local function apply()
    if not widget then return end
    local ok, err = pcall(function()
        widget:SetText(text)
        widget:SetVisible(visible)
    end)
    if not ok then state = "HUD update failed: " .. tostring(err) end
end

function M.init()
    if initialized then return end
    initialized = true
    Observe("QuestTrackerGameController", "OnInitialize", function(controller)
        removeWidget()
        local ok, err = pcall(function()
            local root = controller:GetRootWidget()
            local parent = root and (root:GetParentWidget() or root)
            if not parent then error("Quest tracker parent unavailable") end
            widget = inkText.new()
            widget:SetName("NCPDPatrolDispatchObjective")
            widget:SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily")
            widget:SetFontStyle("Medium")
            widget:SetFontSize(23)
            widget:SetAnchor(inkEAnchor.TopRight)
            widget:SetAnchorPoint(Vector2.new({X = 1.0, Y = 0.0}))
            widget:SetMargin(inkMargin.new({left = 0, top = 285, right = 60, bottom = 0}))
            widget:SetSize(Vector2.new({X = 440, Y = 140}))
            widget:SetWrappingAtPosition(430)
            widget:SetTintColor(HDRColor.new({Red = 1.0, Green = 0.78, Blue = 0.25, Alpha = 1.0}))
            widget:Reparent(parent)
        end)
        if ok then
            state = "Attached to game HUD"
            apply()
        else
            removeWidget()
            state = "HUD setup failed: " .. tostring(err)
            print("[NCPD Patrol] " .. state)
        end
    end)
    Observe("QuestTrackerGameController", "OnUninitialize", function()
        removeWidget()
        state = "Waiting for the game HUD"
    end)
end

function M.set(value, show)
    if text == value and visible == show then return end
    text, visible = value, show
    apply()
end

function M.state() return state end
function M.shutdown()
    text, visible = "", false
    removeWidget()
end

return M
