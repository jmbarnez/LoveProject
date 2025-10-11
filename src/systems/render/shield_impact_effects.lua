-- Subtle shield impact: Fading energy ripples (concentric expanding circles)
local ShieldImpactEffects = {}

-- Active impacts
local activeImpacts = {}
local MAX_IMPACTS = 8

-- Effect parameters
local BREACH_DURATION = 0.6
local RIPPLE_COLOR = {0.2, 0.6, 1.0, 0.4}  -- Subtle blue
local RIPPLE_COUNT = 3

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
        intensity = 1.0
    }

    -- Trigger shield visibility briefly on impact
    impact.entity.shieldImpactTime = love.timer.getTime() + BREACH_DURATION

    -- Adjust intensity for bullet type
    if bulletKind == "missile" then
        impact.intensity = 1.8
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

    -- Calculate current hit position relative to entity
    local offsetX = impact.hitX - impact.entityX
    local offsetY = impact.hitY - impact.entityY
    local currentHitX = ex + offsetX
    local currentHitY = ey + offsetY

    local elapsed = love.timer.getTime() - impact.startTime
    local progress = elapsed / BREACH_DURATION
    local alphaMult = math.pow(1 - progress, 1.5) * impact.intensity  -- Smooth fade

    -- Draw expanding ripples
    for i = 1, RIPPLE_COUNT do
        local waveOffset = (i - 1) * 0.2  -- Staggered start
        local waveProgress = math.max(0, (progress - waveOffset) / (1 - waveOffset))
        local waveRadius = waveProgress * impact.shieldRadius * 1.5

        if waveRadius > 10 then  -- Minimum size
            local waveAlpha = alphaMult * (1 - waveProgress) * (0.8 / i) * RIPPLE_COLOR[4]
            love.graphics.setColor(
                RIPPLE_COLOR[1], RIPPLE_COLOR[2], RIPPLE_COLOR[3], waveAlpha
            )
            love.graphics.setLineWidth(1.5 * alphaMult / i)
            love.graphics.circle("line", currentHitX, currentHitY, waveRadius, 32)  -- 32 segments for smooth circle
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