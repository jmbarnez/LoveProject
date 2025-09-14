-- Target highlighting and selection effects
local Theme = require("src.core.theme")
local Util = require("src.core.util")

local TargetEffects = {}

-- Draw fading ripple click markers
function TargetEffects.drawClickMarkers(clickMarkers)
    for _, m in ipairs(clickMarkers) do
        local k = math.max(0, math.min(1, m.t / m.dur))
        local r = Util.lerp(m.r0, m.r1, k)
        local a = (1 - k) * 0.6
        love.graphics.setColor(0.2, 1, 0.8, a)
        love.graphics.circle("line", m.x, m.y, r)
    end
end

-- Draw target highlight with subtle corner brackets
function TargetEffects.drawTargetHighlight(player)
    if not player.target or player.target.dead then return end
    
    local tgt = player.target
    local rr = (tgt.components and tgt.components.collidable and tgt.components.collidable.radius) or 20
    rr = rr + 12
    local x = tgt.components.position.x
    local y = tgt.components.position.y
    local l = 10
    local pulse = 0.55 + 0.35 * math.abs(math.sin(love.timer.getTime() * 3))
    local a = (player.locked and 0.9 or 0.55) * pulse
    
    love.graphics.setColor(0.2, 1.0, 0.8, a)
    love.graphics.setLineWidth(2)
    
    -- top-left
    love.graphics.line(x - rr, y - rr + l, x - rr, y - rr)
    love.graphics.line(x - rr, y - rr, x - rr + l, y - rr)
    -- top-right
    love.graphics.line(x + rr, y - rr + l, x + rr, y - rr)
    love.graphics.line(x + rr - l, y - rr, x + rr, y - rr)
    -- bottom-left
    love.graphics.line(x - rr, y + rr - l, x - rr, y + rr)
    love.graphics.line(x - rr, y + rr, x - rr + l, y + rr)
    -- bottom-right
    love.graphics.line(x + rr, y + rr - l, x + rr, y + rr)
    love.graphics.line(x + rr - l, y + rr, x + rr, y + rr)
    
    love.graphics.setLineWidth(1)
end

-- Draw per-turret assigned target brackets with synced colors
function TargetEffects.drawTurretTargets(player)
    if not player.components or not player.components.equipment or not player.components.equipment.turrets then
        return
    end
    
    for i = 1, #player.components.equipment.turrets do
        local slot = player.components.equipment.turrets[i]
        local assn = slot and slot.assignedTarget
        
        if assn and not assn.dead and assn.components and assn.components.position then
            local rr = (assn.components.collidable and assn.components.collidable.radius) or 20
            rr = rr + 10
            local x = assn.components.position.x
            local y = assn.components.position.y
            local l = 8
            local col = Theme.turretSlotColors[i] or {0.3, 0.85, 1.0, 1}
            local t = love.timer.getTime()
            local a = 0.8 * (0.6 + 0.4 * math.abs(math.sin(t * 3)))
            
            love.graphics.setColor(col[1], col[2], col[3], a)
            love.graphics.setLineWidth(2)
            
            -- top-left
            love.graphics.line(x - rr, y - rr + l, x - rr, y - rr)
            love.graphics.line(x - rr, y - rr, x - rr + l, y - rr)
            -- top-right
            love.graphics.line(x + rr, y - rr + l, x + rr, y - rr)
            love.graphics.line(x + rr - l, y - rr, x + rr, y - rr)
            -- bottom-left
            love.graphics.line(x - rr, y + rr - l, x - rr, y + rr)
            love.graphics.line(x - rr, y + rr, x - rr + l, y + rr)
            -- bottom-right
            love.graphics.line(x + rr, y + rr - l, x + rr, y + rr)
            love.graphics.line(x + rr - l, y + rr, x + rr, y + rr)
            
            love.graphics.setLineWidth(1)
            
            -- Hotkey marker near bracket (1/2/3/4)
            local hotkeys = {"1","2","3","4"}
            local label = hotkeys[i] or tostring(i)
            love.graphics.setColor(col[1], col[2], col[3], 0.95)
            love.graphics.print(label, x + rr + 6, y - rr - 6)
        end
    end
end

-- Draw hover highlight for loot containers
function TargetEffects.drawHoverHighlight(hoveredEntity, hoveredEntityType)
    -- Disabled: no yellow hover circles; rely on contextual UI or beam effects
    return
end

-- Draw player turret mining beams
function TargetEffects.drawTurretBeams(player, entities)
    -- Draw player turret beams
    if player and player.components and player.components.equipment and player.components.equipment.turrets then
        for i = 1, #player.components.equipment.turrets do
            local entry = player.components.equipment.turrets[i]
            local turret = entry and entry.turret
            if entry and entry.enabled and turret then
                -- Draw mining/salvaging beams
                if turret.drawMiningBeam and turret.beamActive then
                    turret:drawMiningBeam()
                end
                -- Draw laser beams
                if turret.drawLaserBeam and turret.beamActive then
                    turret:drawLaserBeam()
                end
            end
        end
    end

    -- Draw enemy turret beams
    if entities then
        for _, enemy in pairs(entities) do
            if enemy.components and enemy.components.ai and enemy.components.equipment and enemy.components.equipment.turrets then
                for _, turretData in ipairs(enemy.components.equipment.turrets) do
                    local turret = turretData and turretData.turret
                    if turret and turretData.enabled then
                        -- Draw laser beams from enemies
                        if turret.drawLaserBeam and turret.beamActive then
                            turret:drawLaserBeam()
                        end
                    end
                end
            end
        end
    end
end

-- Draw lock-on targeting indicators
function TargetEffects.drawLockOnIndicators(player)
    local lockState = player.lockOnState
    if not lockState or not lockState.target or lockState.target.dead then
        return
    end
    
    local target = lockState.target
    local pos = target.components.position
    if not pos then return end
    
    local x, y = pos.x, pos.y
    local radius = (target.components.collidable and target.components.collidable.radius or 20) + 15
    local time = love.timer.getTime()
    
    -- Lock-on progress ring
    if lockState.lockProgress > 0 then
        local progress = lockState.lockProgress
        local sweepAngle = progress * 2 * math.pi
        
        if lockState.isLocked then
            -- Locked - solid ring with pulse
            local pulse = 0.7 + 0.3 * math.sin(time * 6)
            love.graphics.setColor(1.0, 0.3, 0.1, 0.8 * pulse)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", x, y, radius)
            
            -- Lock confirmation cross
            local crossSize = 8
            love.graphics.setColor(1.0, 0.4, 0.2, 0.9 * pulse)
            love.graphics.setLineWidth(2)
            love.graphics.line(x - crossSize, y, x + crossSize, y)
            love.graphics.line(x, y - crossSize, x, y + crossSize)
            
            -- "LOCKED" text
            love.graphics.setColor(1.0, 0.5, 0.3, 0.9)
            local oldFont = love.graphics.getFont()
            if Theme.fonts and Theme.fonts.small then 
                love.graphics.setFont(Theme.fonts.small) 
            end
            love.graphics.printf("LOCKED", x - 30, y + radius + 8, 60, "center")
            if oldFont then love.graphics.setFont(oldFont) end
            
        else
            -- Locking in progress - partial ring only
            love.graphics.setColor(1.0, 0.8, 0.2, 0.7)
            love.graphics.setLineWidth(3)
            -- Draw progress arc starting from top
            love.graphics.arc("line", "open", x, y, radius, -math.pi/2, -math.pi/2 + sweepAngle, 32)
        end
    end
    
    love.graphics.setLineWidth(1)
end

return TargetEffects
