-- Player entity rendering
local RenderUtils = require("src.systems.render.utils")
local Config = require("src.content.config")
local ShieldEffects = require("src.systems.render.shield_effects")

local PlayerRenderer = {}

-- Draw thruster effects based on current thrust state
local function drawThrusterEffects(entity, size, time)
    local thrusterState = entity.thrusterState
    if not thrusterState then return end
    
    local S = RenderUtils.createScaler(size)
    local shipRadius = S(20) -- Base ship radius, scales with size
    
    -- Calculate dynamic ship bounds for any ship size
    local shipBounds = {
        front = shipRadius * 0.8,   -- Front of ship
        back = -shipRadius * 0.9,   -- Back of ship  
        left = -shipRadius * 0.6,   -- Left side
        right = shipRadius * 0.6    -- Right side
    }
    
    local effectIntensity = 0.7
    local boostMult = thrusterState.boost > 0 and 1.5 or 1.0
    
    -- Forward thrust effect (main engines at back of ship)
    if thrusterState.forward > 0 then
        local intensity = thrusterState.forward * effectIntensity * boostMult
        local flicker = 0.8 + 0.2 * math.sin(time * 20)
        
        -- Main engine exhaust
        RenderUtils.setColor({0.2, 0.6, 1.0, intensity * 0.6 * flicker})
        love.graphics.circle("fill", shipBounds.back - S(8), 0, S(6))
        
        -- Engine glow
        RenderUtils.setColor({0.4, 0.8, 1.0, intensity * 0.3})
        love.graphics.circle("fill", shipBounds.back - S(12), 0, S(10))
        
        -- Exhaust trail particles
        for i = 1, 3 do
            local offset = i * S(6)
            local alpha = intensity * (0.4 - i * 0.1) * flicker
            RenderUtils.setColor({0.3, 0.7, 1.0, alpha})
            love.graphics.circle("fill", shipBounds.back - offset, math.random(-S(2), S(2)), S(3))
        end
    end
    
    -- Reverse thrust effect (front maneuvering thrusters)
    if thrusterState.reverse > 0 then
        local intensity = thrusterState.reverse * effectIntensity * boostMult
        local flicker = 0.8 + 0.2 * math.sin(time * 18)
        
        -- Small forward-facing thrusters
        RenderUtils.setColor({1.0, 0.6, 0.2, intensity * 0.5 * flicker})
        love.graphics.circle("fill", shipBounds.front + S(6), S(4), S(3))
        love.graphics.circle("fill", shipBounds.front + S(6), S(-4), S(3))
    end
    
    -- Left strafe thrust effect (right-side thrusters)
    if thrusterState.strafeLeft > 0 then
        local intensity = thrusterState.strafeLeft * effectIntensity * boostMult
        local flicker = 0.8 + 0.2 * math.sin(time * 16)
        
        -- Right-side thrusters firing left
        RenderUtils.setColor({1.0, 0.8, 0.2, intensity * 0.5 * flicker})
        love.graphics.circle("fill", S(8), shipBounds.right + S(4), S(3))
        love.graphics.circle("fill", S(-8), shipBounds.right + S(4), S(3))
    end
    
    -- Right strafe thrust effect (left-side thrusters)
    if thrusterState.strafeRight > 0 then
        local intensity = thrusterState.strafeRight * effectIntensity * boostMult
        local flicker = 0.8 + 0.2 * math.sin(time * 14)
        
        -- Left-side thrusters firing right
        RenderUtils.setColor({1.0, 0.8, 0.2, intensity * 0.5 * flicker})
        love.graphics.circle("fill", S(8), shipBounds.left - S(4), S(3))
        love.graphics.circle("fill", S(-8), shipBounds.left - S(4), S(3))
    end
    
    -- Boost effect (enhanced engine glow)
    if thrusterState.boost > 0 then
        local intensity = thrusterState.boost * 0.3
        local pulse = 0.7 + 0.3 * math.sin(time * 8)
        
        -- Extra boost glow around main engines
        RenderUtils.setColor({0.8, 0.9, 1.0, intensity * pulse})
        love.graphics.circle("fill", shipBounds.back - S(6), 0, S(15))
        
        -- Boost particles
        for i = 1, 2 do
            local angle = (time * 4 + i * math.pi) % (2 * math.pi)
            local x = shipBounds.back + math.cos(angle) * S(12)
            local y = math.sin(angle) * S(8)
            RenderUtils.setColor({0.6, 0.8, 1.0, intensity * 0.6})
            love.graphics.circle("fill", x, y, S(2))
        end
    end
    
    -- Braking RCS thrusters (omnidirectional)
    if thrusterState.brake > 0 then
        local intensity = thrusterState.brake * 0.4
        local flicker = 0.8 + 0.2 * math.sin(time * 25)
        
        -- Multiple small RCS thrusters firing in all directions
        local rcsPositions = {
            {shipBounds.front * 0.3, S(8)},      -- front-right
            {shipBounds.front * 0.3, S(-8)},     -- front-left
            {shipBounds.back * 0.3, S(8)},       -- back-right
            {shipBounds.back * 0.3, S(-8)},      -- back-left
            {S(8), shipBounds.right * 0.6},      -- side-right
            {S(-8), shipBounds.left * 0.6}       -- side-left
        }
        
        RenderUtils.setColor({1.0, 0.4, 0.1, intensity * 0.7 * flicker})
        for _, pos in ipairs(rcsPositions) do
            love.graphics.circle("fill", pos[1], pos[2], S(2))
            -- Small exhaust trails
            local trailLength = S(4)
            love.graphics.circle("fill", pos[1] + math.random(-trailLength, trailLength), 
                               pos[2] + math.random(-trailLength, trailLength), S(1))
        end
    end
end

-- Draw player ship with turret tracking
local function drawPlayerShip(entity, size)
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local S = RenderUtils.createScaler(size)

    -- Calculate turret angle to track cursor
    local turretAngle = 0
    if entity.components and entity.components.position and entity.cursorWorldPos then
        -- Use the cursor world position that's already calculated by the input system
        local shipX, shipY = entity.components.position.x, entity.components.position.y
        local cursorX, cursorY = entity.cursorWorldPos.x, entity.cursorWorldPos.y
        
        -- Calculate angle from ship to cursor
        local dx = cursorX - shipX
        local dy = cursorY - shipY
        turretAngle = math.atan2(dy, dx)
        
        -- Adjust for ship's current rotation (turret angle relative to ship body)
        local shipAngle = entity.components.position.angle or 0
        turretAngle = turretAngle - shipAngle
    end

    if type(v.shapes) == "table" and #v.shapes > 0 then
        for i, shape in ipairs(v.shapes) do
            -- Check if this is a turret component
            if shape.turret then
                -- Rotate turret components to track cursor
                love.graphics.push()
                -- Translate to turret center, rotate, then draw
                if shape.type == "rectangle" then
                    love.graphics.translate(S(shape.x + shape.w/2), S(shape.y + shape.h/2))
                    love.graphics.rotate(turretAngle)
                    love.graphics.translate(S(-(shape.x + shape.w/2)), S(-(shape.y + shape.h/2)))
                else
                    love.graphics.translate(S(shape.x or 0), S(shape.y or 0))
                    love.graphics.rotate(turretAngle)
                    love.graphics.translate(S(-(shape.x or 0)), S(-(shape.y or 0)))
                end
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
    local props = entity.components.renderable.props or {}
    local v = props.visuals or {}
    local size = v.size or 1.0
    
    -- Draw main ship
    drawPlayerShip(entity, size)
    
    -- Draw thruster effects based on movement input (optional)
    if Config.RENDER and Config.RENDER.SHOW_THRUSTER_EFFECTS then
        drawThrusterEffects(entity, size, love.timer.getTime())
    end
    
    -- Show full shield bubble when inside station area or when channeling shields
    if entity.weaponsDisabled or entity.shieldChannel then
        ShieldEffects.drawShieldBubble(entity)
    end
end

return PlayerRenderer
