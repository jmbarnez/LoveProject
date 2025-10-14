-- WorldObject Template: The master blueprint for static or simple world entities.
local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Mineable = require("src.components.mineable")
local Interactable = require("src.components.interactable")
local WindfieldPhysics = require("src.components.windfield_physics")
local Util = require("src.core.util")

local WorldObject = {}
WorldObject.__index = WorldObject

function WorldObject.new(x, y, angle, friendly, config)
    local self = setmetatable({}, WorldObject)
    self.name = config.name or "Unnamed Object"
    self.type = "world_object"
    self.subtype = config.id or "unknown"

    self.components = {
        position = Position.new({ x = x, y = y, angle = 0 }),
    }

    -- Add components based on the data definition
    if config.renderable then
        local renderableProps = config.renderable.props or {}
        if config.visuals then
            renderableProps.visuals = config.visuals
        end
        self.components.renderable = Renderable.new(config.renderable.type, renderableProps)
    end

    if config.collidable and (config.renderable.type ~= "planet") then
        self.components.collidable = Collidable.new(config.collidable)
    end

    if config.interactable then
        self.components.interactable = Interactable.new({
            range = config.interactable.range or 50,
            prompt = config.interactable.prompt or "Click to interact",
            requiresKey = config.interactable.requiresKey
        })
    end

    if config.mineable then
        self.components.mineable = Mineable.new(config.mineable)
        -- Provide simple mining hooks expected by turret system
        function self:startMining(power, cyclesPerResource)
            self.miningPower = power or self.miningPower or 1
            if self.components and self.components.mineable then
                self.components.mineable.isBeingMined = true
                self.components.mineable.activeCyclesPerResource = cyclesPerResource or self.components.mineable.activeCyclesPerResource or 12
            end
        end
        function self:stopMining()
            if self.components and self.components.mineable then
                self.components.mineable.isBeingMined = false
                -- Reset intra-cycle progress slowly handled by system; do not zero here
            end
        end
    end

    if config.windfield_physics then
        local collidableRadius = self.components.collidable and self.components.collidable.radius
        local physicsConfig = {}

        for k, v in pairs(config.windfield_physics) do
            physicsConfig[k] = v
        end

        local derivedRadius = config.windfield_physics.radius or collidableRadius or 20
        physicsConfig.radius = derivedRadius
        physicsConfig.x = x
        physicsConfig.y = y

        self.components.windfield_physics = WindfieldPhysics.new(physicsConfig)
    elseif config.physics then
        -- Legacy support for old physics component
        local collidableRadius = self.components.collidable and self.components.collidable.radius
        local physicsConfig = {}

        for k, v in pairs(config.physics) do
            if k ~= "radius" and k ~= "dragCoefficient" and k ~= "angularDamping" then
                physicsConfig[k] = v
            end
        end

        local derivedRadius = config.physics.radius or collidableRadius or 20
        physicsConfig.mass = physicsConfig.mass or (derivedRadius * 2)
        physicsConfig.x = x
        physicsConfig.y = y
        physicsConfig.colliderType = "circle"
        physicsConfig.bodyType = "dynamic"
        physicsConfig.restitution = 0.3
        physicsConfig.friction = 0.1
        physicsConfig.fixedRotation = false
        physicsConfig.radius = derivedRadius

        self.components.windfield_physics = WindfieldPhysics.new(physicsConfig)
    end

    -- Special procedural generation for asteroid vertices
    if self.components.renderable and self.components.renderable.type == "asteroid" then
        local r = self.components.collidable and self.components.collidable.radius or 30
        local geometry = Util.generateAsteroidGeometry(r, self.components.renderable.props.chunkOptions)
        local vertsNested = geometry.vertices
        self.components.renderable.props.vertices = vertsNested
        if geometry.chunks then
            self.components.renderable.props.chunks = geometry.chunks
        end
        -- Build a flat vertex list for polygon collisions
        local flat = {}
        for _, v in ipairs(vertsNested or {}) do
            table.insert(flat, v[1])
            table.insert(flat, v[2])
        end
        -- Upgrade collidable to polygon using generated hull while keeping radius for broad-phase
        if self.components.collidable then
            self.components.collidable.shape = "polygon"
            self.components.collidable.vertices = flat
        else
            self.components.collidable = Collidable.new({ radius = r, shape = "polygon", vertices = flat })
        end
    end

    return self
end

return WorldObject
