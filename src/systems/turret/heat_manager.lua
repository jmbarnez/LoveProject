local HeatManager = {}

function HeatManager.initializeHeat(turret, params)
    turret.maxHeat = params.maxHeat or 100.0
    turret.heatPerShot = params.heatPerShot or (turret.kind == "laser" and 300 or (turret.kind == "missile" and 200 or 150))
    turret.cooldownRate = params.cooldownRate or (turret.kind == "laser" and 6 or 4)
    turret.heatCycleMult = params.heatCycleMult or (turret.kind == "mining_laser" and 0.5 or 0.8)
    turret.heatEnergyMult = params.heatEnergyMult or (turret.kind == "mining_laser" and 2.0 or 1.5)

    turret.currentHeat = 0
    turret.overheated = false
    turret.overheatStartTime = 0
    turret.overheatCooldown = params.overheatCooldown or params.overheatDuration or 3.0
    turret.forcedOverheatCooldown = nil
    turret.heatBuildStartTime = nil
    turret.heatLastAddTime = nil
    turret.heatBuildElapsed = 0
    turret._heatSimulatedTime = 0
end

function HeatManager.updateHeat(turret, dt, locked)
    if not turret.maxHeat or turret.maxHeat <= 0 then return end

    local now
    if love.timer and love.timer.getTime then
        now = love.timer.getTime()
    else
        turret._heatSimulatedTime = (turret._heatSimulatedTime or 0) + dt
        now = turret._heatSimulatedTime
    end

    -- If the turret overheats, force it into a cooldown phase until the heat bar is empty
    if turret.currentHeat >= turret.maxHeat and not turret.overheated then
        -- Capture the final frame between the last heat event and the overheat trigger
        if turret.heatLastAddTime then
            turret.heatBuildElapsed = turret.heatBuildElapsed + math.max(0, now - turret.heatLastAddTime)
        end

        local measuredCooldown = turret.heatBuildElapsed or 0
        if measuredCooldown <= 0 then
            measuredCooldown = turret.overheatCooldown or 0
        end

        turret.overheated = true
        turret.overheatStartTime = now
        turret.currentHeat = turret.maxHeat
        turret.forcedOverheatCooldown = measuredCooldown
        turret.heatBuildStartTime = nil
        turret.heatLastAddTime = nil
        turret.heatBuildElapsed = 0
        -- Optional: play overheat sound effect
    end

    -- Heat always dissipates, but at different rates based on state
    local cooldownRate = turret.cooldownRate * 0.3  -- Much slower base dissipation

    if locked or turret.overheated then
        -- Full cooldown rate when locked or overheated
        if turret.overheated then
            local cooldownWindow = turret.forcedOverheatCooldown or turret.overheatCooldown
            if cooldownWindow and cooldownWindow > 0 then
                cooldownRate = turret.maxHeat / cooldownWindow
            end

            if turret.overheated and turret.overheatCooldown and turret.overheatCooldown > 0 then
                local forcedRate = turret.maxHeat / turret.overheatCooldown
                if forcedRate > cooldownRate then
                    cooldownRate = forcedRate
                end
            end
        else
            -- When locked but not overheated, use normal rate
            cooldownRate = turret.cooldownRate * 0.3
        end
    elseif turret.firing then
        -- Very slow dissipation when firing (heat builds up much faster than it dissipates)
        cooldownRate = turret.cooldownRate * 0.05  -- Even slower when actively firing
    end
    -- When not firing and not locked/overheated, use slow dissipation rate

    -- Track elapsed time while the heat bar is active but not yet empty
    if not turret.overheated and turret.currentHeat > 0 and turret.heatLastAddTime then
        turret.heatBuildElapsed = turret.heatBuildElapsed + math.max(0, now - turret.heatLastAddTime)
        turret.heatLastAddTime = now
    end

    if not turret.overheated and turret.currentHeat <= 0 then
        turret.heatBuildStartTime = nil
        turret.heatLastAddTime = nil
        turret.heatBuildElapsed = 0
    end

    turret.currentHeat = math.max(0, turret.currentHeat - cooldownRate * dt)

    -- Clear the overheated state once the heat bar has fully depleted
    if turret.overheated and turret.currentHeat <= 0 then
        turret.overheated = false
        turret.currentHeat = 0
        turret.forcedOverheatCooldown = nil
        turret.heatBuildStartTime = nil
        turret.heatLastAddTime = nil
        turret.heatBuildElapsed = 0
    end
end

function HeatManager.addHeat(turret, amount)
    if not turret.maxHeat or turret.maxHeat <= 0 then
        return
    end
    if turret.overheated then
        return
    end

    local now
    if love.timer and love.timer.getTime then
        now = love.timer.getTime()
    else
        turret._heatSimulatedTime = turret._heatSimulatedTime or 0
        now = turret._heatSimulatedTime
    end

    if not turret.heatBuildStartTime then
        turret.heatBuildStartTime = now
        turret.heatLastAddTime = now
        turret.heatBuildElapsed = 0
    else
        if turret.heatLastAddTime then
            turret.heatBuildElapsed = turret.heatBuildElapsed + math.max(0, now - turret.heatLastAddTime)
        end
        turret.heatLastAddTime = now
    end

    turret.currentHeat = math.min(turret.maxHeat, turret.currentHeat + amount)
end

function HeatManager.getHeatFactor(turret)
    if not turret.maxHeat or turret.maxHeat <= 0 then
        return 0
    end
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

    -- Heat level - red color that fills up
    local heatColor = {
        0.8 + heatFactor * 0.2, -- Red increases with heat
        0.2 - heatFactor * 0.1, -- Green decreases with heat
        0.1 - heatFactor * 0.05, -- Blue decreases with heat
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
