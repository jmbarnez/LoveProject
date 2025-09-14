local Config = require("src.content.config")

local HeatManager = {}

function HeatManager.initializeHeat(turret, params)
    turret.maxHeat = params.maxHeat or 100.0
    turret.heatPerShot = params.heatPerShot or (turret.kind == "laser" and 25 or (turret.kind == "missile" and 15 or 10))
    turret.cooldownRate = params.cooldownRate or (turret.kind == "laser" and 20 or 15)
    turret.heatCycleMult = params.heatCycleMult or (turret.kind == "mining_laser" and 0.5 or 0.8)
    turret.heatEnergyMult = params.heatEnergyMult or (turret.kind == "mining_laser" and 2.0 or 1.5)

    turret.currentHeat = 0
    turret.overheated = false
    turret.overheatStartTime = 0
    turret.overheatDuration = params.overheatDuration or 3.0
end

function HeatManager.updateHeat(turret, dt, locked)
    if not turret.maxHeat or turret.maxHeat <= 0 then return end

    -- Cool down when not firing or when locked (can't fire)
    if locked or not turret.firing then
        turret.currentHeat = math.max(0, turret.currentHeat - turret.cooldownRate * dt)

        -- Check if we've cooled down from overheated state
        if turret.overheated then
            local timeSinceOverheat = (love.timer and love.timer.getTime() or 0) - turret.overheatStartTime
            if timeSinceOverheat >= turret.overheatDuration then
                turret.overheated = false
            end
        end
    end

    -- Check for overheating
    if turret.currentHeat >= turret.maxHeat and not turret.overheated then
        turret.overheated = true
        turret.overheatStartTime = love.timer and love.timer.getTime() or 0
        -- Optional: play overheat sound effect
    end
end

function HeatManager.addHeat(turret, amount)
    if not turret.maxHeat or turret.maxHeat <= 0 then return end
    turret.currentHeat = math.min(turret.maxHeat, turret.currentHeat + amount)
end

function HeatManager.getHeatFactor(turret)
    if not turret.maxHeat or turret.maxHeat <= 0 then return 0 end
    return turret.currentHeat / turret.maxHeat
end

function HeatManager.getHeatModifiedCycle(turret)
    local baseCycle = turret.cycle or 1.0
    local heatFactor = HeatManager.getHeatFactor(turret)
    local heatMult = 1 + heatFactor * (turret.heatCycleMult - 1)
    return baseCycle * heatMult
end

function HeatManager.getHeatModifiedEnergyCost(turret)
    local baseCost = turret.capCost or 0
    local heatFactor = HeatManager.getHeatFactor(turret)
    local heatMult = 1 + heatFactor * (turret.heatEnergyMult - 1)
    return baseCost * heatMult
end

function HeatManager.canFire(turret)
    return not turret.overheated
end

function HeatManager.drawHeatIndicator(turret, x, y, size)
    if not turret.maxHeat or turret.maxHeat <= 0 then return end

    size = size or 40
    local heatFactor = HeatManager.getHeatFactor(turret)

    -- Heat bar background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, size, 4)

    -- Heat level
    local heatColor = {
        1 - heatFactor, -- Red increases with heat
        1 - heatFactor * 0.8, -- Green decreases with heat
        0.2, -- Blue stays low
        0.9
    }
    love.graphics.setColor(heatColor)
    love.graphics.rectangle("fill", x, y, size * heatFactor, 4)

    -- Overheated warning
    if turret.overheated then
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.rectangle("line", x - 1, y - 1, size + 2, 6)
    end

    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

return HeatManager