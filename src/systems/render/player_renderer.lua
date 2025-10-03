-- Player entity rendering
local RenderUtils = require("src.systems.render.utils")
local Config = require("src.content.config")
local ShieldEffects = require("src.systems.render.shield_effects")
local Util = require("src.core.util")
local Log = require("src.core.log")

local PlayerRenderer = {}

-- Empty function since thruster effects are now handled by the engine_trail component
local function drawThrusterEffects()
    -- All thruster effects have been moved to the engine_trail component system
end

-- Draw player ship with turret tracking
local function drawPlayerShip(entity, size)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local S = RenderUtils.createScaler(size)

    -- Calculate turret angle to track cursor (relative to ship rotation)
    local turretAngle = 0
    if entity.components and entity.components.position and entity.cursorWorldPos then
        -- Use the cursor world position that's already calculated by the input system
        local shipX, shipY = entity.components.position.x, entity.components.position.y
        local cursorX, cursorY = entity.cursorWorldPos.x, entity.cursorWorldPos.y

        -- Calculate angle from ship to cursor in world space
        local dx = cursorX - shipX
        local dy = cursorY - shipY
        local worldAngle = math.atan2(dy, dx)

        -- Convert to angle relative to ship's rotation
        local shipAngle = entity.components.position.angle or 0
        turretAngle = worldAngle - shipAngle + math.pi / 2
    end

    if type(v.shapes) == "table" and #v.shapes > 0 then
        for i, shape in ipairs(v.shapes) do
            -- Check if this is a turret component
            if shape.turret then
                -- Rotate turret components to track cursor
                love.graphics.push()
                local pivot = shape.turretPivot or v.turretPivot
                local pivotX, pivotY

                if type(pivot) == "table" then
                    pivotX = pivot.x or 0
                    pivotY = pivot.y or 0
                elseif type(pivot) == "number" then
                    pivotX = pivot
                    pivotY = 0
                elseif shape.turretPivotX or shape.turretPivotY then
                    pivotX = shape.turretPivotX or 0
                    pivotY = shape.turretPivotY or 0
                else
                    if shape.type == "rectangle" then
                        pivotX = (shape.x or 0) + (shape.w or 0) / 2
                        pivotY = (shape.y or 0) + (shape.h or 0) / 2
                    else
                        pivotX = shape.x or 0
                        pivotY = shape.y or 0
                    end
                end

                love.graphics.translate(S(pivotX), S(pivotY))
                love.graphics.rotate(turretAngle)
                love.graphics.translate(S(-pivotX), S(-pivotY))

                RenderUtils.drawShape(shape, S)
                love.graphics.pop()
            else
                -- Draw ship body components normally
                RenderUtils.drawShape(shape, S)
            end
        end
    else
        -- Fallback default drawing if no shapes are defined
        local hull = v.hullColor or {0.16, 0.20, 0.28, 1}
        local panel = v.panelColor or {0.22, 0.26, 0.34, 1}
        local accent = v.accentColor or {0.1, 0.9, 1.0, 0.9}
        local cockpit = v.cockpitColor or {0.2, 1.0, 0.9, 0.25}
        local engine = v.engineColor or {0.2, 0.8, 1.0}

        RenderUtils.setColor(hull)
        love.graphics.polygon("fill", S(-20), S(-12), S(22), 0, S(-20), S(12))
        RenderUtils.setColor(panel)
        love.graphics.polygon("fill", S(-10), S(-9), S(10), 0, S(-10), S(9))
        RenderUtils.setColor(accent)
        love.graphics.polygon("line", S(-20), S(-12), S(22), 0, S(-20), S(12))
        RenderUtils.setColor(cockpit)
        love.graphics.circle("fill", S(-4), 0, S(5))
        RenderUtils.setColor({engine[1], engine[2], engine[3], 0.18})
        love.graphics.rectangle("fill", S(-24), S(-6), S(10), S(12), S(4), S(4))
        RenderUtils.setColor({engine[1], engine[2], engine[3], 0.35})
        love.graphics.rectangle("fill", S(-22), S(-3), S(8), S(6), S(3), S(3))
    end
end

-- Main player renderer function
function PlayerRenderer.render(entity, playerRef)
    if not entity or not entity.components or not entity.components.renderable then
        Log.warn("PlayerRenderer: Invalid entity or missing components")
        return
    end
    
    local pos = entity.components.position
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    local S = RenderUtils.createScaler(size)
    
    -- Draw engine trail in world space if present (before ship to render under)
    if entity.components and entity.components.engine_trail then
        entity.components.engine_trail:draw()
    end

    -- Save current graphics state
    love.graphics.push("all")
    
    -- Apply world transformation for player
    love.graphics.translate(pos.x, pos.y)
    love.graphics.rotate(pos.angle or 0)
    
    -- Draw main ship
    drawPlayerShip(entity, size)
    
    -- Engine trails are now handled by the engine_trail component in entity_renderers.lua
    
    -- Show full shield bubble when inside station area or when channeling shields
    local playerState = entity.components and entity.components.player_state
    local weaponsDisabled = (playerState and playerState.weapons_disabled) or entity.weaponsDisabled
    if weaponsDisabled or entity.shieldChannel then
        ShieldEffects.drawShieldBubble(entity)
    end
    
    -- Restore graphics state
    love.graphics.pop()

    -- Draw laser beams for player turrets from grid
    local TurretEffects = require("src.systems.turret.effects")
    if entity.components and entity.components.equipment and entity.components.equipment.grid then
        for _, gridData in ipairs(entity.components.equipment.grid) do
            if gridData.type == "turret" and gridData.module and (gridData.module.kind == "laser" or gridData.module.kind == "mining_laser" or gridData.module.kind == "salvaging_laser") and gridData.module.beamActive then
                -- Get turret world position for beam rendering
                local Turret = require("src.systems.turret.core")
                local turretX, turretY = Turret.getTurretWorldPosition(gridData.module)
                TurretEffects.renderBeam(gridData.module, turretX, turretY, gridData.module.beamEndX, gridData.module.beamEndY, gridData.module.beamTarget)
            end
        end
    end
end

return PlayerRenderer
