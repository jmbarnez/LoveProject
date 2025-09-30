-- Station Template: The master blueprint for all stations.
local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Health = require("src.components.health")
local Repairable = require("src.components.repairable")
local ModelUtil = require("src.core.model_util")

local Station = {}
Station.__index = Station

function Station.new(x, y, config)
    local self = setmetatable({}, Station)
    self.tag = "station"
    self.isStation = true

    local visuals = config.visuals or (config.renderable and config.renderable.props and config.renderable.props.visuals)
    visuals = visuals or {}

    self.components = {
        position = Position.new({ x = x, y = y }),
        station = {
            type = config.id,
            name = config.name or "Station",
            services = config.station_services,
            description = config.description,
        }
    }

    -- Store descriptive fields on the entity for UI helpers
    self.description = config.description

    -- Determine spatial radii for station safe zones
    self.radius = ModelUtil.calculateModelWidth(visuals)
    if config.radius then
        self.radius = config.radius
    end
    self.weaponDisableRadius = config.weapon_disable_radius or (self.radius * 1.5)
    self.shieldRadius = config.shield_radius or (self.radius * 5)

    -- Special handling for beacon stations with custom no-spawn radius
    if config.id == "beacon_station" then
        if config.no_spawn_radius then
            self.noSpawnRadius = config.no_spawn_radius
        end
        -- Repairable beacon station properties
        if config.repairable then
            self.repairable = true
            self.broken = config.broken or false
            self.repairCost = config.repair_cost or {}

            -- Only apply no-spawn radius when repaired
            if self.broken then
                self.noSpawnRadius = nil -- No protection when broken
            end

            -- Add repairable component
            self.components.repairable = Repairable.new({
                broken = self.broken,
                repairCost = self.repairCost
            })
        else
            self.repairable = false
        end
    elseif config.no_spawn_radius then
        -- Allow other stations to define custom no-spawn zones directly
        self.noSpawnRadius = config.no_spawn_radius
    end

    self.components.renderable = Renderable.new("station", {
        visuals = visuals
    })

    return self
end

function Station:getWeaponDisableRadius()
    return self.weaponDisableRadius or 0
end

return Station
