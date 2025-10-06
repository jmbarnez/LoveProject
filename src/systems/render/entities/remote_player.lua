local RenderUtils = require("src.systems.render.utils")
local EnemyStatusBars = require("src.ui.hud.enemy_status_bars")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)

    local bodyTint = {0.3, 0.6, 1.0, 1.0}
    local outlineTint = {0.12, 0.3, 0.6, 1.0}
    local accentTint = {0.55, 0.8, 1.0, 0.9}

    local function mixWithTint(original, tint)
        if type(original) ~= "table" then
            return {tint[1], tint[2], tint[3], tint[4]}
        end

        local r = (original[1] or tint[1]) * 0.25 + tint[1] * 0.75
        local g = (original[2] or tint[2]) * 0.25 + tint[2] * 0.75
        local b = (original[3] or tint[3]) * 0.25 + tint[3] * 0.75
        local a = original[4] or tint[4] or 1.0
        return {r, g, b, a}
    end

    local drewBody = false
    if type(v.shapes) == "table" and #v.shapes > 0 then
        for _, shape in ipairs(v.shapes) do
            local originalColor = shape.color
            shape.color = mixWithTint(originalColor, bodyTint)
            RenderUtils.drawShape(shape, S)
            shape.color = originalColor
        end
        drewBody = true
    end

    if not drewBody then
        RenderUtils.setColor(bodyTint)
        love.graphics.circle("fill", 0, 0, S(10))
        RenderUtils.setColor(outlineTint)
        love.graphics.circle("line", 0, 0, S(10))
        RenderUtils.setColor(accentTint)
        love.graphics.circle("fill", S(3), 0, S(3.2))
    end

    local previousLineWidth = love.graphics.getLineWidth and love.graphics.getLineWidth() or 1
    love.graphics.setLineWidth(1.5)
    RenderUtils.setColor({bodyTint[1], bodyTint[2], bodyTint[3], 0.35})
    love.graphics.circle("line", 0, 0, S(14))
    love.graphics.setLineWidth(previousLineWidth)

    if entity.playerName then
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(entity.playerName)
        local textHeight = font:getHeight()
        -- Position player name above the health bar (health bar is at -(radius + 22) with height 12)
        -- So we position the name at -(radius + 22 + 12 + 8) to be above it with some spacing
        local radius = (entity.components.collidable and entity.components.collidable.radius) or 12
        local nameY = -(radius + 22 + 12 + 8) - textHeight
        RenderUtils.setColor({0, 0, 0, 0.7})
        love.graphics.rectangle("fill", -textWidth / 2 - 2, nameY - 2, textWidth + 4, textHeight + 4)
        RenderUtils.setColor({0.65, 0.85, 1.0, 1.0})
        love.graphics.print(entity.playerName, -textWidth / 2, nameY)
    end

    -- Use the same health/shield bar system as enemies for consistent display
    if entity.components and entity.components.health then
        EnemyStatusBars.drawMiniBars(entity)
    end

    -- Render remote beam if active
    if entity.remoteBeamActive and entity.remoteBeamAngle and entity.remoteBeamLength then
        local TurretEffects = require("src.systems.turret.effects")
        -- Create a mock turret object for rendering
        local mockTurret = {
            kind = "laser",
            tracer = {
                color = {0.3, 0.7, 1.0, 0.8},
                width = 1.5,
                coreRadius = 0.5
            }
        }
        -- Calculate current beam positions based on player's current position
        local startX = 0  -- Relative to player center
        local startY = 0
        local endX = math.cos(entity.remoteBeamAngle) * entity.remoteBeamLength
        local endY = math.sin(entity.remoteBeamAngle) * entity.remoteBeamLength
        TurretEffects.renderBeam(mockTurret, startX, startY, endX, endY, false)
    end

    -- Render remote utility beam if active
    if entity.remoteUtilityBeamActive and entity.remoteUtilityBeamAngle and entity.remoteUtilityBeamLength then
        local TurretEffects = require("src.systems.turret.effects")
        local beamType = entity.remoteUtilityBeamType
        local mockTurret = {
            kind = beamType == "mining" and "mining_laser" or "salvaging_laser",
            tracer = {
                color = beamType == "mining" and {1.0, 0.7, 0.2, 0.8} or {0.2, 1.0, 0.3, 0.8},
                width = 2.0,
                coreRadius = 1.0
            }
        }
        -- Calculate current beam positions based on player's current position
        local startX = 0  -- Relative to player center
        local startY = 0
        local endX = math.cos(entity.remoteUtilityBeamAngle) * entity.remoteUtilityBeamLength
        local endY = math.sin(entity.remoteUtilityBeamAngle) * entity.remoteUtilityBeamLength
        TurretEffects.renderBeam(mockTurret, startX, startY, endX, endY, false)
    end
end

return render
