local EngineEffects = {}
local EngineTrail = require("src.effects.engine_trail") -- Assuming this path is correct

function EngineEffects.new(player)
    local self = {}
    self.player = player
    -- Initialize EngineTrail with appropriate default values, or values from the player
    -- For color, you might use player.color or default to white/blue.
    -- For size, a default size like 5 is a good starting point.
    self.engineTrail = EngineTrail.new(player.components.position.x, player.components.position.y, {1, 1, 1, 1}, {0.5, 0.5, 1, 0.5}, 5)

    function self:update(dt)
        local x = self.player.components.position.x
        local y = self.player.components.position.y
        local angle = self.player.components.position.angle -- Assuming physics component holds angle
        local isThrusting = self.player.thrusterState.isThrusting
        local intensity = self.player.thrusterState.forward + self.player.thrusterState.boost -- Or however intensity is calculated
        

        self.engineTrail:update(dt, x, y, angle, isThrusting, intensity)
    end

    function self:draw()
        self.engineTrail:draw()
    end

    return self
end

return EngineEffects