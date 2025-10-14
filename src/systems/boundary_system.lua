local BoundarySystem = {}

function BoundarySystem.update(world)
  for _, entity in pairs(world:getEntities()) do
    local pos = entity.components and entity.components.position
    local col = entity.components and entity.components.collidable
    
    if pos and col and pos.x and pos.y then
      local radius = col.radius or 10
      local margin = math.max(10, radius)
      local bounced = false
      
      -- Clamp position to world boundaries with margin for entity radius
      local newX = math.max(margin, math.min(world.width - margin, pos.x))
      local newY = math.max(margin, math.min(world.height - margin, pos.y))
      
      -- If position was clamped, stop velocity in that direction
      if newX ~= pos.x then
        pos.x = newX
        if entity.components.velocity then entity.components.velocity.x = 0 end
        
        -- Handle Windfield physics
        if entity.components.windfield_physics then
          local EntityPhysics = require("src.systems.entity_physics")
          local manager = EntityPhysics.getManager()
          if manager then
            local collider = manager:getCollider(entity)
            if collider then
              local vx, vy = collider:getLinearVelocity()
              collider:setLinearVelocity(0, vy)
            end
          end
        end
        bounced = true
      end
      
      if newY ~= pos.y then
        pos.y = newY
        if entity.components.velocity then entity.components.velocity.y = 0 end
        
        -- Handle Windfield physics
        if entity.components.windfield_physics then
          local EntityPhysics = require("src.systems.entity_physics")
          local manager = EntityPhysics.getManager()
          if manager then
            local collider = manager:getCollider(entity)
            if collider then
              local vx, vy = collider:getLinearVelocity()
              collider:setLinearVelocity(vx, 0)
            end
          end
        end
        bounced = true
      end
      
      -- Update physics position if entity has physics system
      if bounced then
        -- Handle Windfield physics
        if entity.components.windfield_physics then
          local EntityPhysics = require("src.systems.entity_physics")
          local manager = EntityPhysics.getManager()
          if manager then
            local collider = manager:getCollider(entity)
            if collider then
              collider:setPosition(pos.x, pos.y)
            end
          end
        end
      end
    end
  end
end

return BoundarySystem
