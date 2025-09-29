local SalvageSystem = {}
local Skills = require("src.core.skills")
local Notifications = require("src.ui.notifications")
local Events = require("src.core.events")

function SalvageSystem.update(dt, world, player)
  for _, entity in ipairs(world:get_entities_with_components("wreckage", "timed_life")) do
      local wreckage = entity.components.wreckage
        if wreckage.isBeingSalvaged then
            wreckage.salvageProgress = wreckage.salvageProgress + dt
            if wreckage.salvageProgress >= wreckage.salvageCycleTime then
                wreckage.salvageProgress = wreckage.salvageProgress - wreckage.salvageCycleTime
                wreckage.salvageAmount = wreckage.salvageAmount - 1

                -- Create item pickup instead of adding directly to cargo
                local ItemPickup = require("src.entities.item_pickup")
                local pickup = ItemPickup.new(
                    entity.components.position.x + math.random(-15, 15),
                    entity.components.position.y + math.random(-15, 15),
                    wreckage.resourceType or "scraps",
                    1,
                    0.6 + math.random() * 0.4, -- Smaller size for scraps
                    math.random(-80, 80), -- Slower initial velocity
                    math.random(-80, 80)
                )
                table.insert(world.entities, pickup)

                Events.emit(Events.GAME_EVENTS.WRECKAGE_SALVAGED, {
                    player = player,
                    amount = 1,
                    resourceId = wreckage.resourceType or "scraps",
                    wreckage = entity,
                    wreckageId = entity.id
                })

                local xpBase = 10 -- base XP per salvaged resource
                local salvagingLevel = Skills.getLevel("salvaging")
                local xpGain = xpBase * (1 + salvagingLevel * 0.06) -- mild scaling per level
                local leveledUp = Skills.addXp("salvaging", xpGain)
                player:addXP(xpGain)

                if leveledUp then
                    Notifications.action("Salvaging level up!")
                end

                if wreckage.salvageAmount <= 0 then
                    entity.dead = true
                end
            end
        end
    end
end

return SalvageSystem
