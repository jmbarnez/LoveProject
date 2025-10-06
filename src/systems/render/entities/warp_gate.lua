local RenderUtils = require("src.systems.render.utils")

local function render(entity, player)
    local warpGate = entity.components.warp_gate
    local visual = warpGate and warpGate:getVisualProperties() or {}

    local isActive = visual.isActive ~= false
    local glowIntensity = visual.glowIntensity or 0.5
    local rotation = visual.rotation or 0
    local powerLevel = visual.powerLevel or 100
    local maxPowerLevel = visual.maxPowerLevel or 100

    -- Save current graphics state
    local r, g, b, a = love.graphics.getColor()
    local lineWidth = love.graphics.getLineWidth()

    -- Realistic warp gate parameters
    local outerRingRx = 500  -- Toroidal outer ring width
    local outerRingRy = 120  -- Toroidal outer ring height (flattened)
    local innerPortalRx = 300
    local innerPortalRy = 80
    local coreRadius = 150
    local supportThickness = 8
    local emitterSize = 25

    -- Central energy vortex parameters
    local vortexLayers = 5
    local vortexSpiralArms = 4

    love.graphics.push()
    love.graphics.translate(0, 0)
    love.graphics.rotate(rotation * 0.5)  -- Slow overall rotation

    if isActive then
        -- Outer structural toroidal ring (segmented for realism)
        local ringSegments = 24
        love.graphics.setLineWidth(5 * glowIntensity)
        for i = 0, ringSegments - 1 do
            local angle1 = (i / ringSegments) * math.pi * 2
            local angle2 = ((i + 1) / ringSegments) * math.pi * 2
            local midAngle = (angle1 + angle2) / 2
            local x1 = math.cos(angle1) * outerRingRx
            local y1 = math.sin(angle1) * outerRingRy
            local x2 = math.cos(angle2) * outerRingRx
            local y2 = math.sin(angle2) * outerRingRy
            local glow = 0.3 + glowIntensity * 0.7
            RenderUtils.setColor({0.25, 0.25, 0.35, glow})
            love.graphics.line(x1, y1, x2, y2)
        end

        -- Structural arches/supports
        local archCount = 8
        for i = 0, archCount - 1 do
            local angle = (i / archCount) * math.pi * 2
            local archAngle = angle + math.pi / 2  -- Perpendicular to ring
            local supportLength = outerRingRx * 0.8
            local sx1 = math.cos(angle) * outerRingRx * 0.9
            local sy1 = math.sin(angle) * outerRingRy * 0.9
            local sx2 = sx1 + math.cos(archAngle) * supportLength
            local sy2 = sy1 + math.sin(archAngle) * supportLength
            RenderUtils.setColor({0.4, 0.4, 0.5, 0.8 + glowIntensity * 0.2})
            love.graphics.setLineWidth(supportThickness)
            love.graphics.line(sx1, sy1, sx2, sy2)
        end

        -- Inner energy portal ring with distortion
        love.graphics.setLineWidth(3 * glowIntensity)
        RenderUtils.setColor({0.2, 0.8, 1.0, 0.6 + glowIntensity * 0.4})
        love.graphics.ellipse("line", 0, 0, innerPortalRx, innerPortalRy)

        -- Central energy core (glowing sphere)
        RenderUtils.setColor({0.1, 0.6, 1.0, 0.5 + glowIntensity * 0.5})
        love.graphics.circle("fill", 0, 0, coreRadius * 0.6)
        RenderUtils.setColor({0.3, 0.8, 1.0, 0.8 + glowIntensity * 0.2})
        love.graphics.circle("line", 0, 0, coreRadius * 0.6, coreRadius * 0.6, 32, 0, 0, false)

        -- Energy vortex (spiraling arms)
        love.graphics.push()
        love.graphics.rotate(rotation * 2)  -- Faster vortex rotation
        for arm = 1, vortexSpiralArms do
            local armOffset = (arm / vortexSpiralArms) * math.pi * 2
            for layer = 1, vortexLayers do
                local layerT = layer / vortexLayers
                local spiralRadius = coreRadius * layerT * 1.5
                local spiralAngle = armOffset + layerT * math.pi * 4 + rotation * 3  -- Spiral twist
                local ex = math.cos(spiralAngle) * spiralRadius
                local ey = math.sin(spiralAngle) * spiralRadius
                local alpha = (1 - layerT) * (0.4 + glowIntensity * 0.6)
                RenderUtils.setColor({0.4, 0.9, 1.0, alpha})
                love.graphics.circle("line", ex, ey, 5 * layerT, 5 * layerT, 8)
            end
        end
        love.graphics.pop()

        -- Rotating emitters on the ring
        local emitterPositions = {
            {x = outerRingRx * 0.8, y = 0},
            {x = -outerRingRx * 0.8, y = 0},
            {x = 0, y = outerRingRy * 0.8},
            {x = 0, y = -outerRingRy * 0.8}
        }
        for _, pos in ipairs(emitterPositions) do
            love.graphics.push()
            love.graphics.translate(pos.x, pos.y)
            love.graphics.rotate(rotation * 1.5)  -- Emitters rotate independently
            RenderUtils.setColor({1.0, 1.0, 0.5, 0.9 * glowIntensity})
            love.graphics.circle("fill", 0, 0, emitterSize)
            -- Emitter glow
            RenderUtils.setColor({1.0, 1.0, 0.5, 0.4 * glowIntensity})
            love.graphics.circle("fill", 0, 0, emitterSize * 1.5)
            love.graphics.pop()
        end

        -- Distortion field (subtle grid lines for space warp effect)
        if glowIntensity > 0.5 then
            love.graphics.setLineWidth(1)
            local gridSize = 20
            for i = -4, 4 do
                local offset = rotation * 10 + i * math.pi / 2
                local gx = math.cos(offset) * innerPortalRx * 1.2
                local gy = math.sin(offset) * innerPortalRy * 1.2
                RenderUtils.setColor({0.1, 0.4, 0.8, 0.2 * glowIntensity})
                love.graphics.line(-gx, -gy, gx, gy)
            end
        end

    else
        -- Inactive state: faded structural ring
        love.graphics.setLineWidth(2)
        RenderUtils.setColor({0.2, 0.2, 0.3, 0.4})
        love.graphics.ellipse("line", 0, 0, outerRingRx, outerRingRy)

        -- Inactive core
        RenderUtils.setColor({0.1, 0.1, 0.2, 0.3})
        love.graphics.circle("fill", 0, 0, coreRadius * 0.4)
    end

    love.graphics.pop()

    -- Enhanced particles for energy field
    if isActive and visual.particles then
        for _, particle in ipairs(visual.particles) do
            if particle.alpha > 0 then
                -- Particle as small energy sparks
                local px = particle.x + math.cos(rotation + particle.x) * 10
                local py = particle.y + math.sin(rotation + particle.y) * 10
                RenderUtils.setColor({0.8, 1.0, 1.0, particle.alpha * glowIntensity})
                love.graphics.circle("fill", px, py, particle.size * glowIntensity)
            end
        end
    end

    -- Power level indicator (if applicable)
    if entity.components.warp_gate and entity.components.warp_gate.requiresPower then
        local powerPercent = powerLevel / maxPowerLevel
        local barWidth = 80
        local barHeight = 6
        local barY = outerRingRx + 30

        -- Background
        RenderUtils.setColor({0.1, 0.1, 0.1, 0.8})
        love.graphics.rectangle("fill", -barWidth/2, barY, barWidth, barHeight, 2, 2)

        -- Power bar
        local powerColor = powerPercent > 0.3 and {0.2, 1.0, 0.2} or {1.0, 0.2, 0.2}
        RenderUtils.setColor({powerColor, powerColor, powerColor, 0.9})
        love.graphics.rectangle("fill", -barWidth/2, barY, barWidth * powerPercent, barHeight, 2, 2)

        -- Border
        RenderUtils.setColor({0.5, 0.5, 0.5, 0.6})
        love.graphics.rectangle("line", -barWidth/2, barY, barWidth, barHeight, 2, 2)
    end

    -- Restore graphics state
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(lineWidth)
end

return render
