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
    
    -- Initialize hotspots as Hotspots class instance if not already
    if not mineable.hotspots or type(mineable.hotspots) == "table" and not mineable.hotspots.update then
        print("MiningSystem: Initializing hotspots system for entity")
        local Hotspots = require("src.components.hotspots")
        mineable.hotspots = Hotspots.new({
            maxHotspots = 3,
            hotspotRadius = mineable.hotspotRadius,
            hotspotDamageMultiplier = 2.0,
            hotspotLifetime = 8.0,
            hotspotSpawnChance = 0.3,
            hotspotSpawnInterval = 2.0
        })
        print("MiningSystem: Hotspots system initialized, maxHotspots: " .. mineable.hotspots.maxHotspots)
    else
        print("MiningSystem: Hotspots system already exists")
    end
    return radius
end

-- Old array-based hotspot system removed - now using Hotspots class

-- Updates mining progress on all mineable entities being mined.
-- Yields resources to the player every N cycles.
function MiningSystem.update(dt, world, player)
    local entities = world:get_entities_with_components("mineable")
    print("MiningSystem: Found " .. #entities .. " mineable entities")
    for _, e in ipairs(entities) do
        local m = e.components and e.components.mineable
        print("MiningSystem: Entity has mineable component: " .. tostring(m ~= nil) .. ", isBeingMined: " .. tostring(m and m.isBeingMined) .. ", resources: " .. tostring(m and m.resources))
        if m and m.isBeingMined and (m.resources or 0) > 0 then
            print("MiningSystem: Entity is being mined, resources: " .. (m.resources or 0))
            -- Ensure hotspots system is initialized
            ensureHotspotDefaults(e, m)

            if not m._wasBeingMined then
                m.hotspotTimer = math.max(0.2, (m.hotspotWarmup or 0.35))
            end

            m.hotspotTimer = (m.hotspotTimer or 0) - dt
            print("MiningSystem: Hotspot timer: " .. (m.hotspotTimer or 0) .. ", hotspots system exists: " .. tostring(m.hotspots ~= nil))
            if (m.hotspotTimer or 0) <= 0 then
                print("MiningSystem: Hotspot timer expired, attempting to generate hotspot")
                -- Use the Hotspots class to generate hotspots with random chance
                if m.hotspots and m.hotspots.generateHotspot then
                    local spawnChance = m.hotspots.hotspotSpawnChance or 0.3
                    print("MiningSystem: Spawn chance: " .. spawnChance .. ", random: " .. math.random())
                    if math.random() < spawnChance then
                        local success = m.hotspots:generateHotspot(e)
                        if success then
                            print("Hotspot generated! Total hotspots: " .. m.hotspots:getCount())
                        else
                            print("Hotspot generation failed!")
                        end
                    else
                        print("MiningSystem: Spawn chance failed")
                    end
                else
                    print("MiningSystem: No hotspots system or generateHotspot method")
                end
                local interval = m.hotspotInterval or 2.2
                local jitter = m.hotspotIntervalJitter or 1.4
                m.hotspotTimer = interval + math.random() * jitter
            end
      
            -- Update hotspots using the Hotspots class
            if m.hotspots and m.hotspots.update then
                m.hotspots:update(dt)
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
            -- Update hotspots even when not being mined
            if m.hotspots and m.hotspots.update then
                m.hotspots:update(dt)
            end
            
            -- Generate hotspots even when not being mined, but less frequently
            if (m.resources or 0) > 0 then
                -- Ensure hotspots system is initialized
                ensureHotspotDefaults(e, m)
                
                if not m._wasBeingMined and not m.isBeingMined then
                    m.hotspotTimer = math.max(1.0, (m.hotspotWarmup or 0.35) * 3) -- Longer delay when not mining
                end
                
                m.hotspotTimer = (m.hotspotTimer or 0) - dt
                if (m.hotspotTimer or 0) <= 0 then
                    -- Use the Hotspots class to generate hotspots with lower chance when not mining
                    if m.hotspots and m.hotspots.generateHotspot then
                        local spawnChance = (m.hotspots.hotspotSpawnChance or 0.3) * 0.2 -- Much lower chance when not mining
                        if math.random() < spawnChance then
                            local success = m.hotspots:generateHotspot(e)
                            if success then
                                print("Hotspot generated (idle)! Total hotspots: " .. m.hotspots:getCount())
                            end
                        end
                    end
                    local interval = (m.hotspotInterval or 2.2) * 4 -- Much longer interval when not mining
                    local jitter = (m.hotspotIntervalJitter or 1.4) * 2
                    m.hotspotTimer = interval + math.random() * jitter
                end
            end
            
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
