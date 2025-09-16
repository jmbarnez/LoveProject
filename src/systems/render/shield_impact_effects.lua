-- Completely redesigned shield impact: Breach core with radiating energy veins and ejecting orbs
local ShieldImpactEffects = {}

-- Active impacts
local activeImpacts = {}
local MAX_IMPACTS = 8

-- Effect parameters
local BREACH_DURATION = 0.6
local VEIN_COUNT = 7
local ORB_COUNT = 6
local WAVE_SPEED = 1.5
local CORE_INTENSITY = {1.0, 1.0, 1.0, 1.0}  -- White core
local VEIN_COLOR = {0.3, 0.8, 1.0, 0.8}  -- Cyan veins
local WAVE_COLOR = {0.2, 0.6, 0.9, 0.3}  -- Subtle blue wave
local ORB_COLORS = {{1.0, 0.9, 0.6, 1.0}, {0.8, 1.0, 0.9, 1.0}}  -- Yellow/cyan orbs

-- Create a new shield impact
function ShieldImpactEffects.createImpact(hitX, hitY, entityX, entityY, shieldRadius, impactAngle, bulletKind, entity)
    if entity.tag == "station" then return nil end  -- No shield impacts for stations
    
    if #activeImpacts >= MAX_IMPACTS then
        table.remove(activeImpacts, 1)
    end

    local impact = {
        entity = entity,
        entityX = entityX,
        entityY = entityY,
        hitX = hitX,
        hitY = hitY,
        shieldRadius = shieldRadius,
        impactAngle = impactAngle or 0,
        bulletKind = bulletKind or "default",
        startTime = love.timer.getTime(),
        veins = {},  -- Precompute vein angles
        orbs = {}    -- Particle orbs
    }

    -- Trigger shield visibility briefly on impact
    impact.entity.shieldImpactTime = love.timer.getTime() + BREACH_DURATION

    -- Initialize veins (radial lines)
    local baseAngle = impactAngle
    for i = 0, VEIN_COUNT - 1 do
        local angle = baseAngle + (i / VEIN_COUNT) * math.pi * 2
        table.insert(impact.veins, {
            angle = angle,
            length = 0,
            targetLength = shieldRadius * 0.6
        })
    end

    -- Initialize orbs (ejecting particles)
    for i = 1, ORB_COUNT do
        local angle = baseAngle + (i / ORB_COUNT) * math.pi * 2 + math.random() * 0.5 - 0.25
        local speed = 50 + math.random() * 100
        table.insert(impact.orbs, {
            x = hitX,
            y = hitY,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 1.0,
            decay = 0.02 + math.random() * 0.01,
            size = 2 + math.random() * 3,
            colorIndex = i % 2 + 1
        })
    end

    -- Adjust for bullet type
    if bulletKind == "missile" then
        impact.intensity = 1.8
        VEIN_COLOR[1] = 1.0  -- Red tint for explosives
        VEIN_COLOR[2] = 0.4
    elseif bulletKind == "collision" then
        impact.intensity = 1.3
    else
        impact.intensity = 1.0
    end

    table.insert(activeImpacts, impact)
    return impact
end

-- Update a single impact
local function updateImpact(impact, dt)
    local elapsed = love.timer.getTime() - impact.startTime
    if elapsed > BREACH_DURATION then
        return false  -- Expired
    end

    local progress = elapsed / BREACH_DURATION

    -- Update veins
    for _, vein in ipairs(impact.veins) do
        local ease = 1 - (progress ^ 2)  -- Quadratic ease out
        vein.length = vein.targetLength * ease * impact.intensity
    end

    -- Update orbs
    for _, orb in ipairs(impact.orbs) do
        orb.x = orb.x + orb.vx * dt
        orb.y = orb.y + orb.vy * dt
        orb.vy = orb.vy + 100 * dt  -- Gravity for arc
        orb.life = math.max(0, orb.life - orb.decay)
        orb.size = orb.size * (1 - progress * 0.5)  -- Shrink over time
    end

    return true
end

-- Draw a single impact
local function drawImpact(impact)
    -- Update entity position
    local ex, ey = impact.entityX, impact.entityY
    if impact.entity and impact.entity.components.position then
        ex = impact.entity.components.position.x
        ey = impact.entity.components.position.y
    end

    local elapsed = love.timer.getTime() - impact.startTime
    local progress = elapsed / BREACH_DURATION
    local alphaMult = (1 - progress) ^ 1.5  -- Smooth fade

    -- Breach core: Expanding glow
    local coreSize = 4 + 20 * progress
    love.graphics.setColor(
        CORE_INTENSITY[1], CORE_INTENSITY[2], CORE_INTENSITY[3],
        CORE_INTENSITY[4] * alphaMult * impact.intensity
    )
    love.graphics.circle("fill", impact.hitX, impact.hitY, coreSize)

    -- Radiating energy veins
    love.graphics.setLineWidth(2 * alphaMult)
    for _, vein in ipairs(impact.veins) do
        local endX = impact.hitX + math.cos(vein.angle) * vein.length
        local endY = impact.hitY + math.sin(vein.angle) * vein.length
        love.graphics.setColor(
            VEIN_COLOR[1], VEIN_COLOR[2], VEIN_COLOR[3],
            VEIN_COLOR[4] * alphaMult * (0.5 + 0.5 * math.sin(elapsed * 8 + vein.angle))
        )
        love.graphics.line(impact.hitX, impact.hitY, endX, endY)
    end

    -- Distortion wave: Expanding ellipse
    local waveRadius = impact.shieldRadius * (progress * WAVE_SPEED)
    if waveRadius > 0 then
        love.graphics.setColor(
            WAVE_COLOR[1], WAVE_COLOR[2], WAVE_COLOR[3],
            WAVE_COLOR[4] * alphaMult * 0.7
        )
        love.graphics.setLineWidth(1.5 * alphaMult)
        love.graphics.ellipse("line", impact.hitX, impact.hitY, waveRadius * 1.2, waveRadius * 0.8)
    end

    -- Energy orbs
    for _, orb in ipairs(impact.orbs) do
        if orb.life > 0 then
            local orbAlpha = orb.life * alphaMult
            local col = ORB_COLORS[orb.colorIndex]
            love.graphics.setColor(col[1], col[2], col[3], col[4] * orbAlpha)
            love.graphics.circle("fill", orb.x, orb.y, orb.size)
            
            -- Trail glow
            love.graphics.setColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, col[4] * orbAlpha * 0.5)
            love.graphics.circle("fill", orb.x - orb.vx * 0.05, orb.y - orb.vy * 0.05, orb.size * 1.5)
        end
    end

    love.graphics.setLineWidth(1)
end

-- Update all impacts
function ShieldImpactEffects.update(dt)
    for i = #activeImpacts, 1, -1 do
        local impact = activeImpacts[i]
        if not updateImpact(impact, dt) then
            table.remove(activeImpacts, i)
        end
    end
end

-- Draw all impacts
function ShieldImpactEffects.draw()
    for _, impact in ipairs(activeImpacts) do
        if impact.entity.tag ~= "station" then  -- Skip stations
            drawImpact(impact)
        end
    end
end

-- Utilities
function ShieldImpactEffects.getActiveCount()
    return #activeImpacts
end

function ShieldImpactEffects.clear()
    activeImpacts = {}
end

return ShieldImpactEffects