--[[
    PhysicsSystem

    Handles simple integration for entities with velocity components and keeps
    physics-body driven entities synchronised with their component data. The
    project mixes "pure" ECS entities with love.physics bodies, so this system
    bridges the gap without forcing every entity into the physics engine.
]]

local ProjectileEvents = require("src.templates.projectile_system.event_dispatcher").EVENTS

local PhysicsSystem = {}

function PhysicsSystem.update(dt, entities, world)
    for id, entity in pairs(entities) do
        -- Skip anything that does not follow the component schema; legacy
        -- objects occasionally sneak in during development tools.
        if entity.components and entity.components.position then
            local hasVel = entity.components.velocity ~= nil
            local hasPhysicsBody = entity.components.physics and entity.components.physics.body
            local isLaserBullet = false
            if entity.components.bullet and entity.components.renderable and entity.components.renderable.props then
                local k = entity.components.renderable.props.kind
                if k == 'laser' or k == 'salvaging_laser' or k == 'mining_laser' then isLaserBullet = true end
            end
            local wasPosX = entity.components.position.x
            local wasPosY = entity.components.position.y

            -- Integrate simple kinematics if we have velocity and no physics
            -- body. Laser-type bullets are treated as instantaneous beams, so
            -- we leave their position untouched and let the render system
            -- handle the visuals.
            if (hasVel and not hasPhysicsBody) and (not isLaserBullet) then
                -- Apply space drag to velocity-based entities
                local CorePhysics = require("src.core.physics")
                local dragCoeff = CorePhysics.constants.SPACE_DRAG_COEFFICIENT
                entity.components.velocity.x = (entity.components.velocity.x or 0) * dragCoeff
                entity.components.velocity.y = (entity.components.velocity.y or 0) * dragCoeff
                
                entity.components.position.x = (entity.components.position.x or 0) + (entity.components.velocity.x or 0) * dt
                entity.components.position.y = (entity.components.position.y or 0) + (entity.components.velocity.y or 0) * dt
            end

            -- Update physics component if present
            if entity.components.physics and entity.components.physics.update then
                entity.components.physics:update(dt)
                if entity.components.physics.body then
                    -- Sync position/angle from physics body. We still protect
                    -- laser bullets because some templates attach minimal
                    -- bodies for collision tests only.
                    if not isLaserBullet then
                        entity.components.position.x = entity.components.physics.body.x or entity.components.position.x or 0
                        entity.components.position.y = entity.components.physics.body.y or entity.components.position.y or 0
                        entity.components.position.angle = entity.components.physics.body.angle or entity.components.position.angle or 0
                    end
                end
            end

            -- Debug: if this entity is a projectile/bullet, log any position change during physics update
            if entity.components.bullet then
            end

            local projectileEvents = entity.components.projectile_events
            if projectileEvents and projectileEvents.dispatcher then
                projectileEvents.dispatcher:emit(ProjectileEvents.UPDATE, {
                    projectile = entity,
                    dt = dt,
                    world = world,
                })
            end
        end
    end
end

return PhysicsSystem
