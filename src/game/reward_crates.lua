local Pickups = require("src.systems.pickups")

local RewardCrates = {}

function RewardCrates.tryCollect(playerEntity, activeWorld)
    if not playerEntity or not activeWorld then return false end
    if playerEntity.docked then return false end
    if not playerEntity.components or not playerEntity.components.position then return false end
    if not Pickups or not Pickups.findNearestPickup then return false end

    local pickup = Pickups.findNearestPickup(activeWorld, playerEntity, "reward_crate", 280)
    if not pickup or pickup.dead then return false end

    local result = Pickups.collectPickup(playerEntity, pickup)
    if not result then return false end

    Pickups.notifySingleResult(result)
    return true
end

return RewardCrates
