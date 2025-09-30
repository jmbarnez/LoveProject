local Notifications = require("src.ui.notifications")
local Content = require("src.content.content")
local Skills = require("src.core.skills")
local Events = require("src.core.events")

local MiningSystem = {}

local function getEntityRadius(entity)
    if not entity or not entity.components then
        return 24
    end

    local collidable = entity.components.collidable
    if collidable and collidable.radius then
        return collidable.radius
    end

    return entity.radius or 24
end

local function ensureHotspotDefaults(entity, mineable)
    local radius = getEntityRadius(entity)
    if not mineable.hotspotRadius then
        local scale = mineable.hotspotRadiusScale or 0.28
        mineable.hotspotRadius = math.max(6, radius * scale)
    end
    mineable.hotspots = mineable.hotspots or {}
    return radius
end

local function updateHotspots(dt, entity, mineable)
    if not mineable.hotspots or #mineable.hotspots == 0 then
        return
    end

    local pos = entity.components and entity.components.position
    if not pos then
        return
    end

    local angle = pos.angle or 0
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)

    for i = #mineable.hotspots, 1, -1 do
        local hotspot = mineable.hotspots[i]
        hotspot.life = (hotspot.life or 0) - dt
        hotspot.cooldown = math.max(0, (hotspot.cooldown or 0) - dt)
        hotspot.warmup = math.max(0, (hotspot.warmup or 0) - dt)
        hotspot.pulse = math.max(0, (hotspot.pulse or 0) - dt)
        hotspot.lastHit = math.max(0, (hotspot.lastHit or 0) - dt)

        if (hotspot.life or 0) <= 0 then
            table.remove(mineable.hotspots, i)
        else
            local offsetX = hotspot.offsetX or 0
            local offsetY = hotspot.offsetY or 0
            hotspot.worldX = pos.x + offsetX * cosA - offsetY * sinA
            hotspot.worldY = pos.y + offsetX * sinA + offsetY * cosA
        end
    end
end

local function spawnHotspot(entity, mineable)
    local radius = ensureHotspotDefaults(entity, mineable)
    if radius <= 0 then
        return
    end

    mineable.hotspots = mineable.hotspots or {}
    if #mineable.hotspots >= 3 then
        return
    end

    local distanceMin = radius * 0.35
    local distanceMax = radius * 0.85
    local distance = distanceMin + math.random() * (distanceMax - distanceMin)
    local angle = math.random() * math.pi * 2
    local offsetX = math.cos(angle) * distance
    local offsetY = math.sin(angle) * distance
    local hotspotRadius = math.max(6, mineable.hotspotRadius or radius * 0.25)

    local baseLife = mineable.hotspotLife or 2.4
    local life = baseLife * (0.75 + math.random() * 0.6)
    local warmup = mineable.hotspotWarmup or 0.35
    local burstInterval = mineable.hotspotBurstInterval or 0.75

    local hotspot = {
        offsetX = offsetX,
        offsetY = offsetY,
        radius = hotspotRadius,
        life = life,
        maxLife = life,
        warmup = warmup,
        cooldown = warmup,
        burstInterval = burstInterval,
        damage = mineable.hotspotDamage or 8,
        pulse = 0,
        lastHit = 0,
    }

    local pos = entity.components and entity.components.position
    if pos then
        local cosA = math.cos(pos.angle or 0)
        local sinA = math.sin(pos.angle or 0)
        hotspot.worldX = pos.x + offsetX * cosA - offsetY * sinA
        hotspot.worldY = pos.y + offsetX * sinA + offsetY * cosA
    end

    table.insert(mineable.hotspots, hotspot)
end

-- Updates mining progress on all mineable entities being mined.
-- Yields resources to the player every N cycles.
function MiningSystem.update(dt, world, player)
    local entities = world:get_entities_with_components("mineable")
    for _, e in ipairs(entities) do
        local m = e.components and e.components.mineable
        if m and m.isBeingMined and (m.resources or 0) > 0 then
            updateHotspots(dt, e, m)

            if not m._wasBeingMined then
                m.hotspotTimer = math.max(0.2, (m.hotspotWarmup or 0.35))
            end

            m.hotspotTimer = (m.hotspotTimer or 0) - dt
            if (m.hotspotTimer or 0) <= 0 then
                spawnHotspot(e, m)
                local interval = m.hotspotInterval or 2.2
                local jitter = m.hotspotIntervalJitter or 1.4
                m.hotspotTimer = interval + math.random() * jitter
            end
      
            -- Update hotspots
            if m.hotspots then
                m.hotspots:update(dt)
                
                -- Try to generate new hotspots during mining
                local currentTime = love.timer.getTime()
                if currentTime - (m.hotspots.lastHotspotSpawn or 0) >= m.hotspots.hotspotSpawnInterval then
                    if math.random() < m.hotspots.hotspotSpawnChance then
                        local success = m.hotspots:generateHotspot(e)
                        if success then
                            print("Hotspot generated! Total hotspots: " .. m.hotspots:getCount())
                        end
                    end
                    m.hotspots.lastHotspotSpawn = currentTime
                end
            end
            
            -- Advance per-cycle progress
            m.mineProgress = (m.mineProgress or 0) + dt
            local cycleTime = m.mineCycleTime or 1.0
            local cyclesRequired = math.max(1, m.activeCyclesPerResource or 12)

            while m.mineProgress >= cycleTime do
                m.mineProgress = m.mineProgress - cycleTime
                m.cycleCount = (m.cycleCount or 0) + 1

                -- When enough cycles have accrued, yield one resource
                if m.cycleCount >= cyclesRequired then
                    m.cycleCount = 0
                    if (m.resources or 0) > 0 then
                        m.resources = m.resources - 1
                        if player then
                            local resourceId = m.resourceType or "stones"

                            -- Create item pickup instead of adding directly to cargo
                            local ItemPickup = require("src.entities.item_pickup")
                            local radius = (e.components.collidable and e.components.collidable.radius) or 30
                            local count = math.max(1, math.ceil(radius / 12))

                            for i = 1, count do
                                local angle = math.random() * math.pi * 2
                                local dist = radius * 0.2 + math.random() * radius * 0.6
                                local spawnX = e.components.position.x + math.cos(angle) * dist
                                local spawnY = e.components.position.y + math.sin(angle) * dist
                                local speed = 160 + math.random() * 200
                                local spreadAngle = angle + (math.random() - 0.5) * 0.8

                                local pickup = ItemPickup.new(
                                    spawnX,
                                    spawnY,
                                    resourceId,
                                    1,
                                    0.85 + math.random() * 0.35,
                                    math.cos(spreadAngle) * speed,
                                    math.sin(spreadAngle) * speed
                                )
                                table.insert(world.entities, pickup)
                            end

                            local xpBase = 12 -- modest base XP per ore
                            local miningLevel = Skills.getLevel("mining")
                            local xpGain = xpBase * (1 + miningLevel * 0.06) -- mild scaling per level
                            local leveledUp = Skills.addXp("mining", xpGain)
                            player:addXP(xpGain)

                            if leveledUp then
                                Notifications.action("Mining level up!")
                            end

                            -- Emit mining event for quest system
                            Events.emit(Events.GAME_EVENTS.ASTEROID_MINED, {
                                item = { id = resourceId, name = name },
                                amount = 1,
                                player = player,
                                asteroid = e
                            })
                        end
                    end
                end
            end
        elseif m then
            updateHotspots(dt, e, m)
            if m._wasBeingMined and not m.isBeingMined then
                local delay = 0.6 + math.random() * 0.6
                m.hotspotTimer = delay
            end
        end
        if m then
            m._wasBeingMined = m.isBeingMined
        end
    end
end

return MiningSystem
