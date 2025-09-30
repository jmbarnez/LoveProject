local Hotspots = {}
Hotspots.__index = Hotspots

local DEFAULT_SPAWN_INTERVAL = 2.0
local DEFAULT_SPAWN_JITTER = 0.8

function Hotspots.new(values)
    local instance = setmetatable({}, Hotspots)

    instance.hotspots = {}
    instance.maxHotspots = values.maxHotspots or 3
    instance.radius = values.hotspotRadius or 15
    instance.lifetime = values.hotspotLifetime or 6.0
    instance.spawnChance = values.hotspotSpawnChance or 0.4
    instance.spawnInterval = values.hotspotSpawnInterval or DEFAULT_SPAWN_INTERVAL
    instance.spawnJitter = values.hotspotSpawnJitter or DEFAULT_SPAWN_JITTER

    local baseBurst = values.hotspotBurstDamage or values.hotspotDamage or 10
    if values.hotspotDamageMultiplier then
        baseBurst = baseBurst * values.hotspotDamageMultiplier
    end
    instance.burstDamage = baseBurst

    instance.bonusResources = values.hotspotBonusResources or 2
    instance.spawnTimer = instance.spawnInterval

    return instance
end

function Hotspots:setRadius(radius)
    if radius then
        self.radius = radius
    end
end

local function getAsteroidRadius(collidable, hotspotRadius)
    if collidable then
        if collidable.effectiveRadius and collidable.effectiveRadius > 0 then
            return collidable.effectiveRadius
        end
        if collidable.radius and collidable.radius > 0 then
            return collidable.radius
        end
    end

    local fallback = (hotspotRadius or 12) * 2.5
    return math.max(24, fallback)
end

local function generatePositionOnAsteroid(asteroid, radius)
    local pos = asteroid.components.position
    local collidable = asteroid.components.collidable
    local hotspotRadius = radius or 12
    local asteroidRadius = getAsteroidRadius(collidable, hotspotRadius)

    local desiredDistance = asteroidRadius + hotspotRadius * 0.35
    local baseDistance = asteroidRadius + hotspotRadius * 0.05
    local angle

    if collidable and collidable.shape == "polygon" and collidable.vertices and #collidable.vertices >= 6 then
        local vertexCount = math.floor(#collidable.vertices / 2)
        if vertexCount >= 3 then
            local index = math.random(1, vertexCount)
            local nextIndex = (index % vertexCount) + 1

            local vx = collidable.vertices[(index - 1) * 2 + 1] or 0
            local vy = collidable.vertices[(index - 1) * 2 + 2] or 0
            local nx = collidable.vertices[(nextIndex - 1) * 2 + 1] or 0
            local ny = collidable.vertices[(nextIndex - 1) * 2 + 2] or 0

            local t = math.random()
            local edgeX = vx + (nx - vx) * t
            local edgeY = vy + (ny - vy) * t

            angle = math.atan2(edgeY, edgeX)
        end
    end

    if not angle then
        angle = math.random() * math.pi * 2
    end

    local radialJitter = (math.random() - 0.5) * hotspotRadius * 0.2
    local distance = math.min(baseDistance + radialJitter, desiredDistance - hotspotRadius * 0.1)
    if distance < 0 then
        distance = baseDistance
    end
    distance = math.min(distance, desiredDistance - hotspotRadius * 0.1)

    local tangentJitter = (math.random() - 0.5) * hotspotRadius * 0.6
    local cosAngle = math.cos(angle)
    local sinAngle = math.sin(angle)

    local x = pos.x + cosAngle * distance + (-sinAngle) * tangentJitter
    local y = pos.y + sinAngle * distance + (cosAngle) * tangentJitter

    return x, y
end

function Hotspots:generateHotspot(asteroid)
    if not asteroid or not asteroid.components or not asteroid.components.position then
        return false
    end

    if #self.hotspots >= self.maxHotspots then
        return false
    end

    local x, y = generatePositionOnAsteroid(asteroid, self.radius)

    local hotspot = {
        x = x,
        y = y,
        radius = self.radius,
        lifetime = self.lifetime,
        maxLifetime = self.lifetime,
        active = true,
        pulsePhase = math.random() * math.pi * 2
    }

    table.insert(self.hotspots, hotspot)
    return true
end

function Hotspots:update(dt, asteroid, isBeingMined)
    if isBeingMined then
        self.spawnTimer = (self.spawnTimer or self.spawnInterval) - dt
        if self.spawnTimer <= 0 then
            self.spawnTimer = self.spawnInterval + math.random() * self.spawnJitter
            if math.random() <= self.spawnChance then
                self:generateHotspot(asteroid)
            end
        end
    else
        self.spawnTimer = math.min(self.spawnTimer or self.spawnInterval, self.spawnInterval)
    end

    for i = #self.hotspots, 1, -1 do
        local hotspot = self.hotspots[i]
        hotspot.lifetime = hotspot.lifetime - dt
        hotspot.pulsePhase = (hotspot.pulsePhase or 0) + dt * 3

        if hotspot.lifetime <= 0 then
            table.remove(self.hotspots, i)
        end
    end
end

local function spawnBonusResources(world, asteroid, impactX, impactY, count)
    if not world or not asteroid or count <= 0 then
        return
    end

    local components = asteroid.components
    if not components or not components.position or not components.mineable then
        return
    end

    local mineable = components.mineable
    local available = mineable.resources or 0
    if available <= 0 then
        return
    end

    local drops = math.min(count, available)
    if drops <= 0 then
        return
    end

    mineable.resources = available - drops

    local ItemPickup = require("src.entities.item_pickup")
    local speedBase = 160

    for i = 1, drops do
        local angle = math.random() * math.pi * 2
        local distance = 6 + math.random() * 16
        local spawnX = impactX + math.cos(angle) * distance
        local spawnY = impactY + math.sin(angle) * distance

        local speed = speedBase + math.random() * 140
        local spread = angle + (math.random() - 0.5) * 0.6
        local vx = math.cos(spread) * speed
        local vy = math.sin(spread) * speed

        local pickup = ItemPickup.new(
            spawnX,
            spawnY,
            "stones",  -- Always drop raw stones
            1,
            0.85 + math.random() * 0.3,
            vx,
            vy
        )

        if world.entities then
            table.insert(world.entities, pickup)
        elseif world.addEntity then
            world:addEntity(pickup)
        end
    end
end

function Hotspots:activateAt(asteroid, world, x, y)
    if not x or not y then
        return 0
    end

    for index = #self.hotspots, 1, -1 do
        local hotspot = self.hotspots[index]
        local dx = x - hotspot.x
        local dy = y - hotspot.y
        local radius = hotspot.radius or self.radius
        if (dx * dx + dy * dy) <= radius * radius then
            table.remove(self.hotspots, index)
            spawnBonusResources(world, asteroid, x, y, self.bonusResources)
            return self.burstDamage or 0
        end
    end

    return 0
end

function Hotspots:clear()
    self.hotspots = {}
    self.spawnTimer = self.spawnInterval
end

function Hotspots:getCount()
    return #self.hotspots
end

function Hotspots:getHotspots()
    return self.hotspots
end

return Hotspots
