local Notifications = require("src.ui.notifications")
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
    
    if mineable.hotspots and mineable.hotspots.setRadius then
        mineable.hotspots:setRadius(mineable.hotspotRadius)
    end
    return radius
end

-- Old array-based hotspot system removed - now using Hotspots class

-- Updates mining progress on all mineable entities being mined.
-- Yields resources to the player every N cycles.
function MiningSystem.update(dt, world, player)
    local entities = world:get_entities_with_components("mineable")
    for _, e in ipairs(entities) do
        local m = e.components and e.components.mineable
        if m then
            ensureHotspotDefaults(e, m)

            local isBeingMined = m.isBeingMined and (m.resources or 0) > 0
            if m.hotspots and m.hotspots.update then
                m.hotspots:update(dt, e, isBeingMined)
            end

            if isBeingMined then
                m.mineProgress = (m.mineProgress or 0) + dt
                local cycleTime = m.mineCycleTime or 1.0
                local cyclesRequired = math.max(1, m.activeCyclesPerResource or 12)

                while m.mineProgress >= cycleTime do
                    m.mineProgress = m.mineProgress - cycleTime
                    m.cycleCount = (m.cycleCount or 0) + 1

                    if m.cycleCount >= cyclesRequired then
                        m.cycleCount = 0
                        if (m.resources or 0) > 0 then
                            m.resources = m.resources - 1
                            if player then
                                local resourceId = m.resourceType or "stones"

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

                                local xpBase = 12
                                local miningLevel = Skills.getLevel("mining")
                                local xpGain = xpBase * (1 + miningLevel * 0.06)
                                local leveledUp = Skills.addXp("mining", xpGain)
                                player:addXP(xpGain)

                                if leveledUp then
                                    Notifications.action("Mining level up!")
                                end

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
            end

            m._wasBeingMined = m.isBeingMined
        end
    end
end

return MiningSystem
