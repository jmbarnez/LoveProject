-- WorldObject Template: The master blueprint for static or simple world entities.
local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Mineable = require("src.components.mineable")
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

    -- Special procedural generation for asteroid vertices
    if self.components.renderable and self.components.renderable.type == "asteroid" then
        local r = self.components.collidable and self.components.collidable.radius or 30
        local vertsNested = Util.generateAsteroidVertices(r)
        self.components.renderable.props.vertices = vertsNested
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
