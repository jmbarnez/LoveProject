--[[
    ProjectileLifecycle System

    Handles the lifecycle management of projectiles, including:
    - Timed life expiration (based on duration)
    - Max range expiration (based on distance traveled)
    - Proper event emission before marking projectiles as dead

    This system updates the timed_life and max_range components that are
    already properly designed in the projectile template.
]]

local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS

local ProjectileLifecycle = {}

function ProjectileLifecycle.update(dt, world)
    local entities = world:getEntities()
    
    for id, entity in pairs(entities) do
        -- Only process projectiles (entities with bullet component)
        if entity.components and entity.components.projectile and not entity.dead then
            local timedLife = entity.components.timed_life
            local maxRange = entity.components.max_range
            
            -- Handle timed life expiration
            if timedLife then
                timedLife.timer = timedLife.timer - dt
                if timedLife.timer <= 0 then
                    -- Emit EXPIRE event before marking as dead
                    local eventsComp = entity.components.projectile_events
                    if eventsComp and eventsComp.dispatcher then
                        eventsComp.dispatcher:emit(ProjectileEvents.EXPIRE, {
                            projectile = entity,
                            reason = "timed_out",
                            world = world,
                        })
                    end
                    entity.dead = true
                end
            end
            
            -- Handle max range expiration (only if not already dead from timed life)
            if maxRange and not entity.dead then
                local pos = entity.components.position
                if pos then
                    local dx = pos.x - maxRange.startX
                    local dy = pos.y - maxRange.startY
                    local distance = math.sqrt(dx*dx + dy*dy)
                    
                    if distance >= maxRange.maxDistance then
                        -- Emit EXPIRE event before marking as dead
                        local eventsComp = entity.components.projectile_events
                        if eventsComp and eventsComp.dispatcher then
                            eventsComp.dispatcher:emit(ProjectileEvents.EXPIRE, {
                                projectile = entity,
                                reason = "max_range",
                                world = world,
                            })
                        end
                        entity.dead = true
                    end
                end
            end
        end
    end
end

return ProjectileLifecycle
