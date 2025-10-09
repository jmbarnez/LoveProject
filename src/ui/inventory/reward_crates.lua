--[[
    Inventory Reward Crates
    
    Handles reward crate logic including:
    - Reward crate generation
    - Reward selection
    - Reward distribution
    - Crate opening animations
]]

local Content = require("src.content.content")
local Notifications = require("src.ui.notifications")

local RewardCrates = {}

function RewardCrates.pickCrateReward()
    local candidates = {}
    for _, item in ipairs(Content.items or {}) do
        if item.id ~= "reward_crate_key" then
            table.insert(candidates, item)
        end
    end
    
    if #candidates == 0 then
        return nil, 0
    end
    
    local choice = candidates[math.random(1, #candidates)]
    local maxStack = (choice.stack and choice.stack > 0) and choice.stack or 1
    local qty = 1
    
    if maxStack > 1 then
        qty = math.random(1, math.min(maxStack, 3))
    end
    
    return choice, qty
end

function RewardCrates.openRewardCrate(player, crateItem)
    if not player or not crateItem then
        return false, "Invalid player or crate"
    end
    
    if not player.components or not player.components.cargo then
        return false, "No cargo system"
    end
    
    local cargo = player.components.cargo
    
    -- Check if player has the crate
    if not cargo:hasItem(crateItem.id) then
        return false, "Crate not in inventory"
    end
    
    -- Generate reward
    local reward, quantity = RewardCrates.pickCrateReward()
    if not reward then
        return false, "No rewards available"
    end
    
    -- Remove crate from inventory
    if not cargo:removeItem(crateItem.id, 1) then
        return false, "Failed to remove crate"
    end
    
    -- Add reward to inventory
    if cargo:addItem(reward.id, quantity) then
        Notifications.add("Opened crate! Received " .. (reward.name or reward.id) .. " x" .. quantity, "success")
        return true
    else
        -- If we can't add the reward, give back the crate
        cargo:addItem(crateItem.id, 1)
        return false, "Inventory full"
    end
end

function RewardCrates.generateRewardCrate(rewardTier)
    rewardTier = rewardTier or "common"
    
    local crateItem = {
        id = "reward_crate_" .. rewardTier,
        name = "Reward Crate (" .. rewardTier:gsub("^%l", string.upper) .. ")",
        type = "container",
        rarity = rewardTier,
        value = RewardCrates.getCrateValue(rewardTier),
        description = "A mysterious crate that may contain valuable rewards.",
        icon = "reward_crate",
        stack = 1,
        use = function(item, player)
            return RewardCrates.openRewardCrate(player, item)
        end
    }
    
    return crateItem
end

function RewardCrates.getCrateValue(tier)
    local values = {
        common = 100,
        uncommon = 250,
        rare = 500,
        epic = 1000,
        legendary = 2500
    }
    
    return values[tier] or 100
end

function RewardCrates.getRewardTiers()
    return {
        "common",
        "uncommon", 
        "rare",
        "epic",
        "legendary"
    }
end

function RewardCrates.getTierProbability(tier)
    local probabilities = {
        common = 0.5,
        uncommon = 0.3,
        rare = 0.15,
        epic = 0.04,
        legendary = 0.01
    }
    
    return probabilities[tier] or 0
end

function RewardCrates.selectRandomTier()
    local tiers = RewardCrates.getRewardTiers()
    local probabilities = {}
    
    for _, tier in ipairs(tiers) do
        table.insert(probabilities, RewardCrates.getTierProbability(tier))
    end
    
    local random = math.random()
    local cumulative = 0
    
    for i, tier in ipairs(tiers) do
        cumulative = cumulative + probabilities[i]
        if random <= cumulative then
            return tier
        end
    end
    
    return "common" -- Fallback
end

function RewardCrates.generateRandomCrate()
    local tier = RewardCrates.selectRandomTier()
    return RewardCrates.generateRewardCrate(tier)
end

function RewardCrates.canOpenCrate(player, crateItem)
    if not player or not crateItem then
        return false, "Invalid player or crate"
    end
    
    if not player.components or not player.components.cargo then
        return false, "No cargo system"
    end
    
    local cargo = player.components.cargo
    
    -- Check if player has the crate
    if not cargo:hasItem(crateItem.id) then
        return false, "Crate not in inventory"
    end
    
    -- Check if inventory has space
    if not cargo:hasSpace() then
        return false, "Inventory full"
    end
    
    return true
end

function RewardCrates.getCrateRewards(tier)
    tier = tier or "common"
    
    local rewards = {}
    for _, item in ipairs(Content.items or {}) do
        if item.id ~= "reward_crate_key" and item.rarity == tier then
            table.insert(rewards, item)
        end
    end
    
    return rewards
end

function RewardCrates.getCrateDescription(tier)
    local descriptions = {
        common = "A basic reward crate containing common items.",
        uncommon = "An uncommon reward crate with better items.",
        rare = "A rare reward crate with valuable items.",
        epic = "An epic reward crate with very valuable items.",
        legendary = "A legendary reward crate with extremely rare items."
    }
    
    return descriptions[tier] or "A mysterious reward crate."
end

function RewardCrates.createCrateKey()
    return {
        id = "reward_crate_key",
        name = "Reward Crate Key",
        type = "key",
        rarity = "rare",
        value = 500,
        description = "A key that can be used to open reward crates.",
        icon = "key",
        stack = 1
    }
end

function RewardCrates.useCrateKey(player, keyItem)
    if not player or not keyItem then
        return false, "Invalid player or key"
    end
    
    if not player.components or not player.components.cargo then
        return false, "No cargo system"
    end
    
    local cargo = player.components.cargo
    
    -- Check if player has the key
    if not cargo:hasItem(keyItem.id) then
        return false, "Key not in inventory"
    end
    
    -- Generate a random crate
    local crate = RewardCrates.generateRandomCrate()
    
    -- Remove key from inventory
    if not cargo:removeItem(keyItem.id, 1) then
        return false, "Failed to remove key"
    end
    
    -- Add crate to inventory
    if cargo:addItem(crate.id, 1) then
        Notifications.add("Used key! Received " .. (crate.name or crate.id), "success")
        return true
    else
        -- If we can't add the crate, give back the key
        cargo:addItem(keyItem.id, 1)
        return false, "Inventory full"
    end
end

return RewardCrates
