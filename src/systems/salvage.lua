local SalvageSystem = {}

function SalvageSystem.update(dt, world, player)
    for _, entity in ipairs(world:getEntitiesWithComponents("wreckage", "timed_life")) do
        local wreckage = entity.components.wreckage
        if wreckage.isBeingSalvaged then
            wreckage.salvageProgress = wreckage.salvageProgress + dt
            if wreckage.salvageProgress >= wreckage.salvageCycleTime then
                wreckage.salvageProgress = wreckage.salvageProgress - wreckage.salvageCycleTime
                wreckage.salvageAmount = wreckage.salvageAmount - 1
                local Cargo = require("src.core.cargo")
                Cargo.add(player, wreckage.resourceType or "scraps", 1)
                player:addXP(5) -- Add 5 XP for each salvaged resource
                if wreckage.salvageAmount <= 0 then
                    entity.dead = true
                end
            end
        end
    end
end

return SalvageSystem
