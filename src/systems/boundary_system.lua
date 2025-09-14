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
        if entity.components and entity.components.physics and entity.components.physics.body then
          entity.components.physics.body.vx = 0
        end
        bounced = true
      end
      
      if newY ~= pos.y then
        pos.y = newY
        if entity.components.velocity then entity.components.velocity.y = 0 end
        if entity.components and entity.components.physics and entity.components.physics.body then
          entity.components.physics.body.vy = 0
        end
        bounced = true
      end
      
      -- Update physics position if entity has physics system
      if bounced and entity.components and entity.components.physics and entity.components.physics.body then
        entity.components.physics.body.x = pos.x
        entity.components.physics.body.y = pos.y
      end
    end
  end
end

return BoundarySystem
