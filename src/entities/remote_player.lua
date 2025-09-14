--[[
  Remote Player Entity
  Represents other players in multiplayer games
]]

local EntityFactory = require("src.templates.entity_factory")
local Content = require("src.content.content")
local Log = require("src.core.log")

local RemotePlayer = {}
RemotePlayer.__index = RemotePlayer

function RemotePlayer.new(playerId, x, y, shipId)
    -- Create a ship entity similar to local player but without player-specific methods
    local ship = EntityFactory.create("ship", shipId or "starter_frigate_basic", x, y)
    if not ship then return nil end
    
    -- Set up as remote player
    local self = setmetatable(ship, RemotePlayer)
    self.isRemotePlayer = true
    self.playerId = playerId
    self.lastNetworkUpdate = love.timer.getTime()
    
    -- Network interpolation data
    self.networkPosition = {x = x, y = y}
    self.targetPosition = {x = x, y = y}
    self.networkAngle = 0
    self.targetAngle = 0
    
    -- Override renderable type
    if self.components and self.components.renderable then
        self.components.renderable.type = "remote_player"
        self.components.renderable.color = {0.7, 0.9, 1.0} -- Slightly blue tint for remote players
    end
    
    Log.info("Created remote player:", playerId)
    return self
end

-- Update from network data
function RemotePlayer:updateFromNetwork(data)
    if not data then return end
    
    -- Store target position for interpolation
    self.targetPosition.x = data.x or self.targetPosition.x
    self.targetPosition.y = data.y or self.targetPosition.y
    self.targetAngle = data.angle or self.targetAngle
    
    -- Store velocity for prediction
    self.velocity = {
        x = data.vx or 0,
        y = data.vy or 0
    }
    
    -- Update health and energy
    if self.components.health then
        if data.health then self.components.health.current = data.health end
        if data.maxHealth then self.components.health.max = data.maxHealth end
    end
    
    if self.components.energy and data.energy then
        self.components.energy.current = data.energy
    end
    
    -- Update boost status
    self.isBoosting = data.isBoosting or false
    
    self.lastNetworkUpdate = love.timer.getTime()
end

-- Smooth interpolation between network updates
function RemotePlayer:interpolate(dt)
    if not self.components.position then return end
    
    -- Time since last network update for prediction
    local timeSinceUpdate = love.timer.getTime() - self.lastNetworkUpdate
    local lerpFactor = math.min(dt * 15, 1) -- Faster interpolation for responsiveness
    
    -- Predict position using velocity (client-side prediction)
    local predictedX = self.targetPosition.x
    local predictedY = self.targetPosition.y
    
    if self.velocity and timeSinceUpdate < 0.1 then -- Only predict for recent updates
        predictedX = predictedX + self.velocity.x * timeSinceUpdate
        predictedY = predictedY + self.velocity.y * timeSinceUpdate
    end
    
    -- Interpolate to predicted position
    local pos = self.components.position
    pos.x = pos.x + (predictedX - pos.x) * lerpFactor
    pos.y = pos.y + (predictedY - pos.y) * lerpFactor
    
    -- Update physics body position if it exists
    if self.components.physics and self.components.physics.body then
        self.components.physics.body.x = pos.x
        self.components.physics.body.y = pos.y
        -- Set velocity for smooth physics rendering
        self.components.physics.body.vx = self.velocity and self.velocity.x or 0
        self.components.physics.body.vy = self.velocity and self.velocity.y or 0
    end
    
    -- Interpolate angle with wrapping
    local angleDiff = self.targetAngle - (self.angle or 0)
    if angleDiff > math.pi then
        angleDiff = angleDiff - 2 * math.pi
    elseif angleDiff < -math.pi then
        angleDiff = angleDiff + 2 * math.pi
    end
    
    self.angle = (self.angle or 0) + angleDiff * lerpFactor
    
    -- Update position angle component
    if pos then
        pos.angle = self.angle
    end
    
    -- Update physics body angle
    if self.components.physics and self.components.physics.body then
        self.components.physics.body.angle = self.angle
    end
end

-- Check if this remote player should be removed (timeout)
function RemotePlayer:shouldTimeout()
    return (love.timer.getTime() - self.lastNetworkUpdate) > 5.0
end

return RemotePlayer
