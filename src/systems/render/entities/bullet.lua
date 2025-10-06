local RenderUtils = require("src.systems.render.utils")
local util = require("src.core.util")

local function render(entity, player)
    local props = entity.components.renderable.props or {}
    local kind = props.kind

    if kind == 'laser' or kind == 'salvaging_laser' or kind == 'mining_laser' or kind == 'plasma_torch' then
        -- Draw along +X in local space; outer renderer applies rotation.
        local len = props.length or props.maxLength or 800
        local baseColor, baseWidth

        -- Type-specific colors for charged pulse system
        if kind == 'salvaging_laser' then
            baseColor = util.copy(props.color or {0.2, 1.0, 0.3, 0.8}) -- Green
            baseWidth = props.tracerWidth or 2.0
        elseif kind == 'mining_laser' then
            baseColor = util.copy(props.color or {1.0, 0.7, 0.2, 0.8}) -- Orange
            baseWidth = props.tracerWidth or 2.0
        elseif kind == 'plasma_torch' then
            baseColor = util.copy(props.color or {1.0, 0.4, 0.1, 0.9}) -- Orange-red plasma
            baseWidth = props.tracerWidth or 8.0
        else
            baseColor = util.copy(props.color or {0.3, 0.7, 1.0, 0.8}) -- Blue (combat)
            baseWidth = props.tracerWidth or 1.5
        end

        -- Charged pulse effect system: buildup + flash then disappear
        local tl = entity.components.timed_life
        local totalLife = (tl and tl.life) or 0.15
        local timeLeft = (tl and tl.timer) or totalLife
        local elapsed = totalLife - timeLeft

        -- Phase timing
        local flashTime = 0.02

        local phase, phaseProgress, alpha, coreW, glowW
        local r, g, b, baseAlpha = util.unpack_color(baseColor)

        if elapsed <= flashTime then
            -- FLASH PHASE: Intense beam release
            phase = "flash"
            phaseProgress = elapsed / flashTime
            alpha = baseAlpha * (2.0 + 0.5 * math.sin(phaseProgress * math.pi * 8)) -- Flickering intensity
            coreW = baseWidth * (0.8 + 0.3 * math.sin(phaseProgress * math.pi * 12)) -- Thinner core
            glowW = coreW + 4 + 2 * math.sin(phaseProgress * math.pi * 6) -- Less glow
        else
            -- POST-FLASH: Immediate disappear (render nothing)
            phase = "done"
            alpha = 0
            coreW = 0
            glowW = 0
        end

        if love.graphics.setLineStyle then love.graphics.setLineStyle('smooth') end

        -- Skip rendering if laser is done
        if phase == "done" then
            return
        end

        -- Beam rendering
        if phase == "flash" then
            -- Beam discharge
            -- Outer glow
            love.graphics.setLineWidth(glowW)
            RenderUtils.setColor(baseColor, alpha * 0.5)
            love.graphics.line(0, 0, len, 0)

            -- Core beam - brighter and wider
            love.graphics.setLineWidth(coreW)
            RenderUtils.setColor({math.min(1, r + 0.4), math.min(1, g + 0.4), math.min(1, b + 0.4), alpha})
            love.graphics.line(0, 0, len, 0)

        end

        love.graphics.setLineWidth(1)
        if love.graphics.setLineStyle then love.graphics.setLineStyle('rough') end
    elseif kind == 'plasma' then
        -- Plasma projectile with electric effects
        local color = props.color or {0.8, 0.3, 1.0, 1.0}
        local radius = props.radius or 4
        local glowRadius = props.glowRadius or (radius * 2)
        
        -- Electric crackling effect
        local time = love.timer.getTime() or 0
        local crackleIntensity = 0.3 + 0.2 * math.sin(time * 20)
        
        -- Outer electric glow
        RenderUtils.setColor({color[1], color[2], color[3], color[4] * 0.3 * crackleIntensity})
        love.graphics.circle("fill", 0, 0, glowRadius)
        
        -- Inner plasma core
        RenderUtils.setColor(color)
        love.graphics.circle("fill", 0, 0, radius)
        
        -- Bright center
        local brightColor = {math.min(1, color[1] + 0.3), math.min(1, color[2] + 0.3), math.min(1, color[3] + 0.3), color[4]}
        RenderUtils.setColor(brightColor)
        love.graphics.circle("fill", 0, 0, radius * 0.6)
        
    elseif kind == 'railgun' then
        -- Railgun projectile with electromagnetic trail
        local color = props.color or {0.6, 0.8, 1.0, 1.0}
        local radius = props.radius or 2
        local trailLength = props.trailLength or 20
        
        -- Electromagnetic trail
        if trailLength > 0 then
            local vel = entity.components.velocity
            if vel then
                local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
                if speed > 0 then
                    local trailX = -vel.x / speed * trailLength
                    local trailY = -vel.y / speed * trailLength
                    
                    -- Trail glow
                    love.graphics.setLineWidth(radius * 2)
                    RenderUtils.setColor({color[1], color[2], color[3], color[4] * 0.4})
                    love.graphics.line(trailX, trailY, 0, 0)
                end
            end
        end
        
        -- Projectile core
        RenderUtils.setColor(color)
        love.graphics.circle("fill", 0, 0, radius)
        
        -- Bright center
        local brightColor = {math.min(1, color[1] + 0.4), math.min(1, color[2] + 0.4), math.min(1, color[3] + 0.4), color[4]}
        RenderUtils.setColor(brightColor)
        love.graphics.circle("fill", 0, 0, radius * 0.5)
        
    elseif kind == 'flame' then
        -- Plasma Torch projectile with superheated plasma effects
        local color = props.color or {1.0, 0.4, 0.1, 1.0}
        local radius = props.radius or 6
        local time = love.timer.getTime() or 0
        
        -- Plasma instability effect (like superheated gas)
        local instability = 0.8 + 0.4 * math.sin(time * 15 + entity.id or 0)
        local plasmaRadius = radius * instability
        
        -- Outer plasma glow (superheated gas)
        local glowColor = {color[1], color[2] * 0.8, color[3] * 0.3, color[4] * 0.6}
        RenderUtils.setColor(glowColor)
        love.graphics.circle("fill", 0, 0, plasmaRadius * 1.5)
        
        -- Middle plasma layer
        local midColor = {color[1], color[2] * 0.9, color[3] * 0.5, color[4] * 0.8}
        RenderUtils.setColor(midColor)
        love.graphics.circle("fill", 0, 0, plasmaRadius * 1.2)
        
        -- Inner plasma core
        RenderUtils.setColor(color)
        love.graphics.circle("fill", 0, 0, plasmaRadius)
        
        -- Bright center (superheated core)
        local brightColor = {1.0, math.min(1, color[2] + 0.3), math.min(1, color[3] + 0.2), color[4]}
        RenderUtils.setColor(brightColor)
        love.graphics.circle("fill", 0, 0, plasmaRadius * 0.6)
        
    else
        -- Default bullet rendering
        local color = props.color or {0.35, 0.70, 1.00, 1.0}
        local radius = props.radius or 1

        RenderUtils.setColor(color)
        love.graphics.circle("fill", 0, 0, radius)
    end
end

return render
