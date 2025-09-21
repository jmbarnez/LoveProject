local Notifications = require("src.ui.notifications")
local Content = require("src.content.content")

local Cargo = {}

-- opts: optional table, e.g., { notify = false }
function Cargo.add(player, itemId, qty, opts)
  if not player then return end
  if not itemId or itemId == '' then return end
  qty = math.max(1, tonumber(qty) or 1)
  player.inventory = player.inventory or {}
  player.inventory_slots = player.inventory_slots or {}
  local currentValue = player.inventory[itemId] or 0
  local currentAmount = (type(currentValue) == "number") and currentValue or 0
  player.inventory[itemId] = currentAmount + qty

  -- Ensure the item has a slot mapping
  local mapped = false
  for i = 1, #player.inventory_slots do
    if player.inventory_slots[i] == itemId then
      mapped = true
      break
    end
  end
  if not mapped then
    for i = 1, 24 do
      if player.inventory_slots[i] == nil then
        player.inventory_slots[i] = itemId
        break
      end
    end
  end

  -- Refresh inventory display
  local Inventory = require("src.ui.inventory")
  if Inventory.refresh then Inventory.refresh() end

  -- Notification
  local def = Content.getItem and Content.getItem(itemId)
  local name = (def and def.name) or tostring(itemId)
  local notify = true
  if type(opts) == 'table' and opts.notify == false then
    notify = false
  end
  if notify and Notifications and Notifications.action then
    Notifications.action(string.format("+%d %s added to cargo", qty, name))
  end
end

return Cargo
