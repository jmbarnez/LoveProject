local ContainerSystem = {}

function ContainerSystem.update(world)
  for _, entity in pairs(world:getEntities()) do
    if entity.components and entity.components.lootContainer then
      local items = entity.components.lootContainer.items
      if not items or #items == 0 then
        entity.dead = true
      end
    end
  end
end

return ContainerSystem
