local Notifications = require("src.ui.notifications")
local Content = require("src.content.content")

local Cargo = {}

-- opts: optional table, e.g., { notify = false }
function Cargo.add(player, itemId, qty, opts)
  if not player then return end
  if not itemId or itemId == '' then return end
  qty = math.max(1, tonumber(qty) or 1)
  player.inventory = player.inventory or {}
  player.inventory[itemId] = (player.inventory[itemId] or 0) + qty
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
