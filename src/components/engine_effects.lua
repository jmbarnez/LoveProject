local EngineEffects = {}
local EngineTrail = require("src.components.engine_trail")

function EngineEffects.new(player)
    local self = {}
    self.player = player
    -- Initialize EngineTrail component with appropriate default values
    self.engineTrail = EngineTrail.new({
        color1 = {1, 1, 1, 1},
        color2 = {0.5, 0.5, 1, 0.5},
        size = 5
    })

    function self:update(dt)
        local x = self.player.components.position.x
        local y = self.player.components.position.y
        local angle = self.player.components.position.angle -- Assuming physics component holds angle
        local playerState = self.player.components and self.player.components.player_state
        local thrusterState = playerState and playerState.thruster_state or {}
        local isThrusting = thrusterState.isThrusting
        local intensity = (thrusterState.forward or 0) + (thrusterState.boost or 0) -- Or however intensity is calculated
        
        -- Update position and thrust state using new component API
        self.engineTrail:updatePosition(x, y, angle)
        self.engineTrail:updateThrustState(isThrusting, intensity)
        self.engineTrail:update(dt)
    end

    function self:draw()
        self.engineTrail:draw()
    end

    return self
end

return EngineEffects