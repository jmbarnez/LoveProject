local PhysicsSystem = {}

function PhysicsSystem.update(dt, entities)
    for id, entity in pairs(entities) do
        -- Handle ECS entities with components only
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

            -- Integrate simple kinematics if we have velocity and no physics body
            -- Don't integrate position for laser-type bullets (they are instant traces)
            if (hasVel and not hasPhysicsBody) and (not isLaserBullet) then
                entity.components.position.x = (entity.components.position.x or 0) + (entity.components.velocity.x or 0) * dt
                entity.components.position.y = (entity.components.position.y or 0) + (entity.components.velocity.y or 0) * dt
            end

            -- Update physics component if present
            if entity.components.physics and entity.components.physics.update then
                entity.components.physics:update(dt)
                if entity.components.physics.body then
                    -- Sync position/angle from physics body
                    -- Avoid overwriting laser bullet positions even if a body exists
                    if not isLaserBullet then
                        entity.components.position.x = entity.components.physics.body.x or entity.components.position.x or 0
                        entity.components.position.y = entity.components.physics.body.y or entity.components.position.y or 0
                        entity.components.position.angle = entity.components.physics.body.angle or entity.components.position.angle or 0
                    end
                end
            end

            -- Debug: if this entity is a projectile/bullet, log any position change during physics update
            if entity.components.bullet then
                -- (Debug removed) position-change logging removed for clean build
            end
        end
    end
end

return PhysicsSystem
