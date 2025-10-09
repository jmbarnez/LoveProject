local Theme = require("src.core.theme")
local Content = require("src.content.content")
local PlayerRef = require("src.core.player_ref")

local CargoActions = {}

local function resolvePlayer(player)
    if player then return player end
    if PlayerRef.get then
        return PlayerRef.get()
    end
    return nil
end

function CargoActions.dropItem(player, itemId)
    player = resolvePlayer(player)
    if not player or not player.components or not player.components.cargo then return false end
    local cargo = player.components.cargo
    if not cargo:has(itemId, 1) then return false end

    local def = Content.getItem(itemId) or Content.getTurret(itemId)
    local itemName = def and def.name or itemId
    cargo:remove(itemId, 1)

    local position = player.components.position
    if not position then return false end

    local playerX, playerY = position.x, position.y
    local ATTRACT_RADIUS = 600
    local dropDistance = ATTRACT_RADIUS + 50

    local angle = math.random() * math.pi * 2
    local dropX = playerX + math.cos(angle) * dropDistance
    local dropY = playerY + math.sin(angle) * dropDistance

    local ItemPickup = require("src.entities.item_pickup")
    local pickup = ItemPickup.new(dropX, dropY, itemId, 1, 0.3, math.random(-50, 50), math.random(-50, 50))

    local Game = require("src.game")
    if Game.world and pickup then
        Game.world:addEntity(pickup)
    end

    for _ = 1, 3 do
        Theme.createParticle(
            dropX + math.random(-8, 8),
            dropY + math.random(-8, 8),
            {0.6, 0.6, 0.6, 1.0},
            (math.random() * 2 - 1) * 20,
            (math.random() * 2 - 1) * 20,
            nil,
            0.7
        )
    end

    local Notifications = require("src.ui.notifications")
    Notifications.add("Dropped " .. itemName, "info")
    return true
end

function CargoActions.useItem(player, itemId)
    player = resolvePlayer(player)
    if not player or not player.components or not player.components.cargo then return false end
    local cargo = player.components.cargo
    if not cargo:has(itemId, 1) then return false end

    local item = Content.getItem(itemId)
    if not item or not (item.consumable or item.type == "consumable") then return false end

    if itemId == "node_wallet" then
        local PortfolioManager = require("src.managers.portfolio")
        local success, message = PortfolioManager.useNodeWallet()
        local Notifications = require("src.ui.notifications")
        if success then
            cargo:remove(itemId, 1)
            Notifications.add("🔓 WALLET DECRYPTED • NODES ADDED", "success")
        else
            Notifications.add("⚠️ " .. (message or "FAILED TO PROCESS NODE WALLET"), "error")
        end
        return true
    end

    return false
end

return CargoActions
