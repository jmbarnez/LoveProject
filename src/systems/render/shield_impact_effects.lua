-- Realistic shield ripple effects
local ShieldImpactEffects = {}

-- Active shield ripples
local activeRipples = {}

-- Create a simple shield ripple animation
function ShieldImpactEffects.createImpact(hitX, hitY, entityX, entityY, shieldRadius, impactAngle, bulletKind, entity)
    local ripple = {
        -- Entity reference for position tracking
        entity = entity,
        
        -- Store impact offset relative to entity center
        hitOffsetX = hitX - entityX,
        hitOffsetY = hitY - entityY,
        
        -- Store initial entity position as a fallback
        entityX = entityX,
        entityY = entityY,
        
        -- Shield data
        shieldRadius = shieldRadius,
        impactAngle = impactAngle,
        
        -- Animation timing
        time = 0,
        duration = 0.5,  -- Shorter, more realistic
        
        -- Effect intensity based on bullet type
        intensity = (bulletKind == "missile") and 1.2 or ((bulletKind == "collision") and 1.05 or 0.8),
        bulletKind = bulletKind or "default"
    }
    
    table.insert(activeRipples, ripple)
    return ripple
end

-- Draw shield ripple effect similar to the shield bubble
local function drawShieldRipple(ripple)
    local progress = ripple.time / ripple.duration
    local intensity = ripple.intensity * (1 - progress * progress)  -- Quadratic fade
    
    -- Get current entity position (tracks movement)
    local currentEntityX, currentEntityY
    if ripple.entity and ripple.entity.components and ripple.entity.components.position then
        currentEntityX = ripple.entity.components.position.x
        currentEntityY = ripple.entity.components.position.y
    else
        -- Fallback if entity is gone: use last known position
        currentEntityX = ripple.entityX
        currentEntityY = ripple.entityY
    end
    
    -- Calculate accurate hit point on shield surface (guard against zero-length offsets)
    local hitOffsetLength = math.sqrt((ripple.hitOffsetX or 0) * (ripple.hitOffsetX or 0) + (ripple.hitOffsetY or 0) * (ripple.hitOffsetY or 0))
    local normalizedX, normalizedY
    if hitOffsetLength and hitOffsetLength > 0.0001 then
        normalizedX = ripple.hitOffsetX / hitOffsetLength
        normalizedY = ripple.hitOffsetY / hitOffsetLength
    else
        -- Fallback: if hit offset is zero (e.g. rounding or centered hit), derive direction from impactAngle
        local a = ripple.impactAngle or 0
        normalizedX = math.cos(a)
        normalizedY = math.sin(a)
    end

    -- Project hit point onto shield surface
    local currentHitX = currentEntityX + normalizedX * ripple.shieldRadius
    local currentHitY = currentEntityY + normalizedY * ripple.shieldRadius
    
    -- Draw the shield bubble with ripple effect
    local baseRadius = ripple.shieldRadius
    local rippleStrength = intensity * 8  -- Ripple amplitude
    local time = love.timer.getTime()
    
    -- Create multiple concentric ripples
    for i = 1, 3 do
        local ripplePhase = progress + (i - 1) * 0.15
        local rippleAlpha = intensity * (0.3 - i * 0.08)
        
        if rippleAlpha > 0 then
            -- Main shield bubble with ripple distortion
            local distortedRadius = baseRadius + math.sin(ripplePhase * math.pi * 4) * rippleStrength * (1 - progress)
            
            love.graphics.setColor(0.2, 0.7, 1.0, rippleAlpha * 0.6)
            love.graphics.circle('fill', currentEntityX, currentEntityY, distortedRadius)
            
            love.graphics.setColor(0.4, 0.8, 1.0, rippleAlpha)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle('line', currentEntityX, currentEntityY, distortedRadius)
        end
    end
    
    -- Bright impact flash at current hit point (moves with entity)
    local flashIntensity = intensity * (1 - progress)
    if flashIntensity > 0 then
        love.graphics.setColor(1.0, 1.0, 1.0, flashIntensity * 0.8)
        love.graphics.circle("fill", currentHitX, currentHitY, 6 * (1 - progress))
        
        love.graphics.setColor(0.6, 0.9, 1.0, flashIntensity * 0.6)
        love.graphics.circle("fill", currentHitX, currentHitY, 12 * (1 - progress))
    end
    
    love.graphics.setLineWidth(1)
end

-- Update all active ripples
function ShieldImpactEffects.update(dt)
    for i = #activeRipples, 1, -1 do
        local ripple = activeRipples[i]
        ripple.time = ripple.time + dt
        
        if ripple.time >= ripple.duration then
            table.remove(activeRipples, i)
        end
    end
end

-- Draw all active ripples
function ShieldImpactEffects.draw()
    for _, ripple in ipairs(activeRipples) do
        drawShieldRipple(ripple)
    end
end

-- Get count of active ripples (for performance monitoring)
function ShieldImpactEffects.getActiveCount()
    return #activeRipples
end

-- Clear all active ripples
function ShieldImpactEffects.clear()
    activeRipples = {}
end

return ShieldImpactEffects
