local Hotspots = {}
Hotspots.__index = Hotspots

function Hotspots.new(values)
    local instance = setmetatable({}, Hotspots)
    
    -- Hotspot data
    instance.hotspots = {} -- Array of hotspot objects
    instance.maxHotspots = values.maxHotspots or 3
    instance.hotspotRadius = values.hotspotRadius or 15
    instance.hotspotDamageMultiplier = values.hotspotDamageMultiplier or 2.0
    instance.hotspotLifetime = values.hotspotLifetime or 8.0 -- seconds
    instance.hotspotSpawnChance = values.hotspotSpawnChance or 0.3 -- chance per mining cycle
    
    -- Hotspot generation timing
    instance.lastHotspotSpawn = 0
    instance.hotspotSpawnInterval = values.hotspotSpawnInterval or 2.0 -- seconds between spawn attempts
    
    return instance
end

-- Generate a new hotspot on the asteroid surface
function Hotspots:generateHotspot(asteroid)
    if not asteroid or not asteroid.components or not asteroid.components.position then
        return false
    end
    
    if #self.hotspots >= self.maxHotspots then
        return false
    end
    
    local pos = asteroid.components.position
    local radius = asteroid.components.collidable and asteroid.components.collidable.radius or 30
    
    -- Generate random position on asteroid surface
    local angle = math.random() * math.pi * 2
    local distance = radius * (0.7 + math.random() * 0.3) -- 70-100% of radius
    local x = pos.x + math.cos(angle) * distance
    local y = pos.y + math.sin(angle) * distance
    
    local hotspot = {
        x = x,
        y = y,
        radius = self.hotspotRadius,
        damageMultiplier = self.hotspotDamageMultiplier,
        lifetime = self.hotspotLifetime,
        maxLifetime = self.hotspotLifetime,
        active = true,
        pulsePhase = math.random() * math.pi * 2 -- For pulsing animation
    }
    
    table.insert(self.hotspots, hotspot)
    return true
end

-- Update hotspots (lifetime, animation)
function Hotspots:update(dt)
    for i = #self.hotspots, 1, -1 do
        local hotspot = self.hotspots[i]
        if hotspot.active then
            hotspot.lifetime = hotspot.lifetime - dt
            hotspot.pulsePhase = hotspot.pulsePhase + dt * 3 -- Pulse animation
            
            if hotspot.lifetime <= 0 then
                table.remove(self.hotspots, i)
            end
        end
    end
end

-- Check if a point (beam impact) is within any hotspot
function Hotspots:isPointInHotspot(x, y)
    for _, hotspot in ipairs(self.hotspots) do
        if hotspot.active then
            local dx = x - hotspot.x
            local dy = y - hotspot.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= hotspot.radius then
                return hotspot
            end
        end
    end
    return nil
end

-- Get damage multiplier for a point
function Hotspots:getDamageMultiplier(x, y)
    local hotspot = self:isPointInHotspot(x, y)
    return hotspot and hotspot.damageMultiplier or 1.0
end

-- Consume a hotspot at a point (remove it and return burst damage)
function Hotspots:consumeHotspot(x, y)
    for i, hotspot in ipairs(self.hotspots) do
        if hotspot.active then
            local dx = x - hotspot.x
            local dy = y - hotspot.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= hotspot.radius then
                -- Remove the hotspot
                table.remove(self.hotspots, i)
                -- Return burst damage (base damage + multiplier bonus)
                return hotspot.damageMultiplier * 2.0 -- 2x the normal multiplier as burst
            end
        end
    end
    return 0
end

-- Clear all hotspots
function Hotspots:clear()
    self.hotspots = {}
end

-- Get hotspot count
function Hotspots:getCount()
    return #self.hotspots
end

-- Get all active hotspots
function Hotspots:getHotspots()
    return self.hotspots
end

return Hotspots
