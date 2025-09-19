local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local TimedLife = require("src.components.timed_life")

local ItemPickup = {}

-- Creates a lightweight, non-collidable item pickup that magnetically moves to the player.
function ItemPickup.new(x, y, itemId, qty, sizeScale, vx, vy)
  local self = { components = {} }
  self.components.position = Position.new({ x = x, y = y })
  self.components.renderable = Renderable.new({
    type = "item_pickup",
    props = {
      itemId = itemId or "stones",
      qty = qty or 1,
      sizeScale = sizeScale or 0.7,
    }
  })
  -- Tag component for systems to query
  self.components.item_pickup = { itemId = itemId or "stones", qty = qty or 1 }
  -- Velocity for initial explosion spread
  self.components.velocity = { vx = vx or 0, vy = vy or 0 }
  -- Optional: expire after some time if uncollected
  self.components.timed_life = TimedLife.new(180)

  -- Expose top-level for convenience
  self.itemId = itemId or "stones"
  self.qty = qty or 1

  return self
end
return ItemPickup
