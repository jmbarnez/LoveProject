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

    self.components = {
        position = Position.new({ x = x, y = y }),
        station = {
            type = config.id,
            name = config.name or "Station"
        }
    }

    if config.id == "hub_station" or config.id == "processing_station" or config.id == "beacon_station" then
        -- Set up station collidable based on config (polygon for structure)
        if config.collidable then
            self.components.collidable = Collidable.new(config.collidable)
        end

        -- Store shield radius for zones (weapons disable, docking, amber ring)
        self.radius = ModelUtil.calculateModelWidth(config.visuals)
        self.shieldRadius = self.radius / 2

        -- Special handling for beacon stations with custom no-spawn radius
        if config.id == "beacon_station" then
            print("Creating beacon station with config:", config.id, "repairable =", config.repairable, "broken =", config.broken)

            if config.no_spawn_radius then
                self.noSpawnRadius = config.no_spawn_radius
            end
            -- Repairable beacon station properties
            if config.repairable then
                self.repairable = true
                self.broken = config.broken or false
                self.repairCost = config.repair_cost or {}

                print("Setting beacon station broken state:", self.broken)

                -- Only apply no-spawn radius when repaired
                if self.broken then
                    self.noSpawnRadius = nil -- No protection when broken
                end

                -- Add repairable component
                self.components.repairable = Repairable.new({
                    broken = self.broken,
                    repairCost = self.repairCost
                })

                print("Created repairable component with broken =", self.components.repairable.broken)
            else
                print("Beacon station config.repairable is false/nil!")
            end
        end

        -- Give the station a massive shield so impacts light up the bubble
        -- without making the station destructible.
        local stationHealth = config.id == "hub_station" and 1000000000 or 500000000
        self.components.health = Health.new({
            hp = stationHealth,
            maxHP = stationHealth,
            shield = stationHealth,
            maxShield = stationHealth,
            energy = 0,
            maxEnergy = 0,
        })

        self.components.renderable = Renderable.new("station", {
            visuals = config.visuals
        })
    end

    return self
end

return Station
