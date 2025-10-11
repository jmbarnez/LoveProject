-- Station Template: The master blueprint for all stations.
local Position = require("src.components.position")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local StationComponent = require("src.components.station")
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
    local visualSize = visuals.size or 1.0

    local hasCustomDockingRadius = config.docking_radius ~= nil
    local hasCustomWeaponDisable = config.weapon_disable_radius ~= nil
    local hasCustomShieldRadius = config.shield_radius ~= nil

    self.components = {
        position = Position.new({ x = x, y = y }),
        station = StationComponent.new({
            type = config.id,
            name = config.name or "Station",
            services = config.station_services,
            description = config.description,
        })
    }

    -- Store descriptive fields on the entity for UI helpers
    self.description = config.description

    -- Determine spatial radii for station safe zones
    self.radius = ModelUtil.calculateModelWidth(visuals)
    if config.radius then
        self.radius = config.radius
    end
    self.dockingRadius = config.docking_radius or (self.radius * 1.2)
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

    if config.collidable then
        local collidableDef = {}
        for k, v in pairs(config.collidable) do
            collidableDef[k] = v
        end

        if collidableDef.vertices and type(collidableDef.vertices) == "table" then
            local scaled = {}
            for i, coord in ipairs(collidableDef.vertices) do
                scaled[i] = coord * visualSize
            end
            collidableDef.vertices = scaled
        end

        if collidableDef.radius then
            collidableDef.radius = collidableDef.radius * visualSize
        end

        self.components.collidable = Collidable.new(collidableDef)

        local collidableRadius = self.components.collidable.radius
        if collidableRadius and collidableRadius > (self.radius or 0) then
            self.radius = collidableRadius
            if not hasCustomDockingRadius then
                self.dockingRadius = self.radius * 1.2
            end
            if not hasCustomWeaponDisable then
                self.weaponDisableRadius = self.radius * 1.5
            end
            if not hasCustomShieldRadius then
                self.shieldRadius = self.radius * 5
            end
        end
    end

    return self
end

function Station:getWeaponDisableRadius()
    return self.weaponDisableRadius or 0
end

return Station
