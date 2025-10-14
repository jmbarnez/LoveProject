-- Cannon Impact Effects: Subtle particle-like sparks for cannon projectiles
local CannonImpactEffects = {}

-- Active cannon impacts
local activeImpacts = {}
local MAX_IMPACTS = 12

-- Effect parameters
local SPARK_DURATION = 0.4
local SPARK_COUNT = 8
local SPARK_SPREAD = 0.8  -- Radians spread
local SPARK_SPEED = 80    -- Pixels per second
local SPARK_GRAVITY = 200 -- Downward acceleration

-- Create a new cannon impact with particle-like sparks
function CannonImpactEffects.createImpact(hitX, hitY, impactAngle, bulletKind, entity)
    if bulletKind ~= "cannonball" and bulletKind ~= "cannon" then
        return nil  -- Only for cannon projectiles
    end
    
    if #activeImpacts >= MAX_IMPACTS then
        table.remove(activeImpacts, 1)
    end

    local impact = {
        hitX = hitX,
        hitY = hitY,
        impactAngle = impactAngle or 0,
        bulletKind = bulletKind or "cannonball",
        entity = entity,
        startTime = love.timer.getTime(),
        sparks = {}
    }

    -- Create individual sparks
    for i = 1, SPARK_COUNT do
        local sparkAngle = impactAngle + (math.random() - 0.5) * SPARK_SPREAD
        local sparkSpeed = SPARK_SPEED * (0.7 + math.random() * 0.6)  -- 70-130% of base speed
        
        local spark = {
            x = hitX,
            y = hitY,
            vx = math.cos(sparkAngle) * sparkSpeed,
            vy = math.sin(sparkAngle) * sparkSpeed,
            life = SPARK_DURATION * (0.8 + math.random() * 0.4),  -- 80-120% of base duration
            maxLife = SPARK_DURATION,
            size = 1.5 + math.random() * 1.0,  -- 1.5-2.5 pixel radius
            intensity = 0.8 + math.random() * 0.2  -- 80-100% intensity
        }
        
        table.insert(impact.sparks, spark)
    end

    table.insert(activeImpacts, impact)
    return impact
end

-- Update a single impact
local function updateImpact(impact, dt)
    local currentTime = love.timer.getTime()
    local elapsed = currentTime - impact.startTime
    
    -- Update each spark
    for i = #impact.sparks, 1, -1 do
        local spark = impact.sparks[i]
        
        -- Apply gravity
        spark.vy = spark.vy + SPARK_GRAVITY * dt
        
        -- Update position
        spark.x = spark.x + spark.vx * dt
        spark.y = spark.y + spark.vy * dt
        
        -- Update life
        spark.life = spark.life - dt
        
        -- Remove dead sparks
        if spark.life <= 0 then
            table.remove(impact.sparks, i)
        end
    end
    
    -- Remove impact if all sparks are dead
    return #impact.sparks > 0
end

-- Draw a single impact
local function drawImpact(impact)
    for _, spark in ipairs(impact.sparks) do
        local lifeRatio = spark.life / spark.maxLife
        local alpha = lifeRatio * spark.intensity
        
        -- Fade out over time
        alpha = alpha * (1 - (1 - lifeRatio) * 0.5)
        
        -- Cannon sparks are bright yellow-orange
        local colorIntensity = 0.7 + 0.3 * lifeRatio
        love.graphics.setColor(
            colorIntensity,           -- Red
            colorIntensity * 0.8,     -- Green (slightly less)
            colorIntensity * 0.2,     -- Blue (very little)
            alpha
        )
        
        -- Draw spark as a small circle
        love.graphics.circle('fill', spark.x, spark.y, spark.size)
        
        -- Add a smaller, brighter core
        love.graphics.setColor(
            colorIntensity * 1.2,     -- Brighter red
            colorIntensity * 1.0,     -- Brighter yellow
            colorIntensity * 0.3,     -- Slightly more blue
            alpha * 0.8
        )
        love.graphics.circle('fill', spark.x, spark.y, spark.size * 0.6)
    end
end

-- Update all impacts
function CannonImpactEffects.update(dt)
    for i = #activeImpacts, 1, -1 do
        local impact = activeImpacts[i]
        if not updateImpact(impact, dt) then
            table.remove(activeImpacts, i)
        end
    end
end

-- Draw all impacts
function CannonImpactEffects.draw()
    for _, impact in ipairs(activeImpacts) do
        drawImpact(impact)
    end
end

-- Utilities
function CannonImpactEffects.getActiveCount()
    return #activeImpacts
end

function CannonImpactEffects.clear()
    activeImpacts = {}
end

return CannonImpactEffects
