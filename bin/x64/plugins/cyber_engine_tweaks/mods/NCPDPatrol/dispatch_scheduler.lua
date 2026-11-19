-- Timing and weighted selection only. Actor ownership and native rewards live
-- elsewhere; no cleanup operation is allowed to restart this clock implicitly.
local M = {}
local automatic, busy = true, false
local countdown, generatedCooling = 0, false

function M.isAutomatic() return automatic end
function M.isBusy() return busy end
function M.setBusy(value) busy = value == true end
function M.seconds() return math.max(0, math.ceil(countdown)) end
function M.isCooling() return generatedCooling end
function M.isDue() return countdown <= 0 end

-- Keep automatic-call preference across shifts and save restoration.
function M.prepareShift() busy, generatedCooling = false, false end
function M.reset() M.prepareShift(); countdown = 0 end
function M.finish() busy, countdown = false, 0 end
function M.start() countdown = math.random(30, 60) end
function M.standby() countdown = math.random(60, 120) end
function M.retry() countdown = 30 end
function M.scannerSelected() generatedCooling = false end
function M.scannerAssigned() countdown = 0 end
function M.generatedAssigned() generatedCooling = false; M.standby() end
function M.generatedClosed(status)
    generatedCooling = true
    M.standby()
    if status then status("Dispatch | Assignment closed; next automatic call in "..countdown.." seconds. Scene cleanup runs during standby.") end
end

function M.setAutomatic(value, status)
    automatic = value
    if countdown <= 0 then M.start() end
    if status then status("Dispatch | Automatic calls " .. (automatic and "enabled" or "paused")) end
end

function M.canAdvance(inMenu)
    return automatic and not busy and not inMenu
end

function M.advance(elapsed, duringCleanup)
    countdown = countdown - elapsed
    if duringCleanup then countdown = math.max(0, countdown) end
end

function M.mixDescription() return "50% Scanner / 30% VIP / 20% Cyberpsycho" end
function M.choices()
    return {{name="Scanner",weight=50},{name="VIP",weight=30},{name="Cyberpsycho",weight=20}}
end

-- Remove each attempted type, preserving relative weights on fallback. Reads
-- and diagnostics never draw random numbers; a request draws once per attempt.
function M.draw(choices)
    local total = 0
    for _, choice in ipairs(choices) do total = total + choice.weight end
    local roll, index = math.random(1, total), 1
    for i, choice in ipairs(choices) do
        roll = roll - choice.weight
        if roll <= 0 then index = i; break end
    end
    return table.remove(choices, index)
end

return M
