local Position = require("src.components.position")
local Collidable = require("src.components.collidable")
local LootContainerComponent = require("src.components.loot_container")
local Renderable = require("src.components.renderable")
local TimedLife = require("src.components.timed_life")

local LootContainer = {}

-- items: array of { id = string, qty = number }
function LootContainer.new(x, y, items, sizeScale)
    local self = {
        components = {}
    }
    sizeScale = sizeScale or 1.0
    self.components.position = Position.new({ x = x, y = y })
    self.components.collidable = Collidable.new({ radius = 20 * sizeScale })
    self.components.lootContainer = LootContainerComponent.new({ items = items or {}, entity = self })
    self.components.renderable = Renderable.new({ type = "lootContainer", props = { sizeScale = sizeScale } })
    self.components.timed_life = TimedLife.new(180)
    -- Expose items at top-level as expected by UI window
    self.items = {}
    for _, stack in ipairs(items or {}) do
        table.insert(self.items, { id = stack.id, qty = stack.qty })
    end
    -- Basic click hit-test; Input uses this to open window
    function self:mousepressed(wx, wy, button)
        if button ~= 1 then return false end
        local px, py = self.components.position.x, self.components.position.y
        local r = (self.components.collidable and self.components.collidable.radius) or 35
        local dx, dy = wx - px, wy - py
        return (dx*dx + dy*dy) <= (r*r)
    end
    return self
end

return LootContainer
