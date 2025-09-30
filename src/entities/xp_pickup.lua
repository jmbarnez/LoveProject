local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local TimedLife = require("src.components.timed_life")

local ExperiencePickup = {}

local DEFAULT_LIFETIME = 150

function ExperiencePickup.new(x, y, amount, sizeScale, vx, vy)
    local self = { components = {} }

    self.components.position = Position.new({ x = x, y = y })
    self.components.renderable = Renderable.new({
        type = "xp_pickup",
        props = {
            amount = amount or 0,
            sizeScale = sizeScale or 1.0,
        }
    })
    self.components.xp_pickup = { amount = amount or 0 }
    self.components.velocity = { vx = vx or 0, vy = vy or 0 }
    self.components.timed_life = TimedLife.new(DEFAULT_LIFETIME)

    self.amount = amount or 0

    return self
end

return ExperiencePickup
