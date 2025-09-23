-- Entity Factory: A universal utility for creating any entity type from data.
local Content = require("src.content.content")
local Normalizer = require("src.content.normalizer")
local Builder = require("src.templates.builder")
local Log = require("src.core.log")
local Util = require("src.core.util")

-- A registry for entity blueprints/templates.
local entity_templates = {
    ship = require("src.templates.ship"),
    projectile = require("src.templates.projectile"),
    world_object = require("src.templates.world_object"),
    station = require("src.templates.station"),
    warp_gate = require("src.templates.warp_gate"),
}

local EntityFactory = {}

---
-- Creates a base entity instance from a template and a configuration.
-- This is the core, generic creation function.
---
function EntityFactory.create(entityType, entityId, x, y, extraConfig)
    local template = entity_templates[entityType]
    if not template then
        Log.warn("EntityFactory - No template for type", tostring(entityType))
        return nil
    end

    local config
    if entityType == "ship" then
        config = Content.getShip(entityId)
    elseif entityType == "projectile" then
        config = Content.getProjectile(entityId)
    elseif entityType == "world_object" or entityType == "station" then
        config = Content.getWorldObject(entityId)
        if entityId == "beacon_station" then
            print("EntityFactory getting beacon_station config:", config and config.id or "nil", "repairable =", config and config.repairable or "nil")
        end
    elseif entityType == "warp_gate" then
        -- Warp gates use their own config system
        config = extraConfig or {
            name = "Warp Gate",
            interactionRange = 150,
            isActive = true,
            activationCost = 0,
            requiresPower = false
        }
    end

    if not config then
        Log.warn("EntityFactory - No content data for", tostring(entityType), "'" .. tostring(entityId) .. "'")
        return nil
    end

    -- Deep copy the config to prevent shared data issues
    config = Util.deepCopy(config)

    -- The 'friendly' flag and angle are passed in the extraConfig for projectiles
    local friendly = (extraConfig and extraConfig.friendly) or false
    local angle = (extraConfig and extraConfig.angle) or 0

    -- Normalize to canonical schema
    if entityType == "ship" then
        config = Normalizer.normalizeShip(config)
    elseif entityType == "projectile" then
        config = Normalizer.normalizeProjectile(config)
    elseif entityType == "world_object" or entityType == "station" then
        config = Normalizer.normalizeWorldObject(config)
    elseif entityType == "warp_gate" then
        -- Warp gates don't need normalization as they use their own config
    end

    -- Merge extraConfig into normalized config (flags like isEnemy)
    if extraConfig then
        for k, v in pairs(extraConfig) do
            config[k] = v
        end
    end
    local entity
    if entityType == "ship" then
        entity = Builder.buildShip(config, x, y, { angle = angle, friendly = friendly })
    elseif entityType == "projectile" then
        entity = Builder.buildProjectile(config, x, y, angle, friendly, extraConfig)
    elseif entityType == "world_object" then
        entity = Builder.buildWorldObject(config, x, y, { angle = angle, friendly = friendly })
    elseif entityType == "station" then
        entity = Builder.buildStation(config, x, y, { angle = angle, friendly = friendly })
    else
        -- Fallback to template constructor
        entity = template.new(x, y, config)
    end

    return entity
end

---
-- Specialized creation functions for different ship roles.
---

-- Create a player ship
function EntityFactory.createPlayer(shipId, x, y)
  local config = {
    isPlayer = true,
    energyRegen = 20, -- units per second
  }
  return EntityFactory.create("ship", shipId, x, y, config)
end

-- Create an enemy ship
function EntityFactory.createEnemy(shipId, x, y)
    local shipConfig = Content.getShip(shipId)
    local config = {
        isEnemy = true,
        bounty = (shipConfig and shipConfig.bounty) or 25,
        xpReward = (shipConfig and shipConfig.xpReward) or 50,
        energyRegen = 35, -- Faster regen than player (20) for aggressive firing,
        shipId = shipId, -- Store ship ID for quest tracking
    }
    local enemy = EntityFactory.create("ship", shipId, x, y, config)
    if enemy and enemy.components then
        -- Mark bosses for special handling
        if shipId == 'boss_drone' then
            enemy.isBoss = true
        end
        -- Make enemy drones a bit larger than base, but smaller than before
        local rend = enemy.components.renderable
        if rend and rend.props and rend.props.visuals then
            local visuals = rend.props.visuals
            visuals.size = (visuals.size or 1.0) * 1.5
        end
        if enemy.components.collidable then
            enemy.components.collidable.radius = (enemy.components.collidable.radius or 10) * 1.5
        end
        if enemy.components.physics and enemy.components.physics.body then
            enemy.components.physics.body.radius = (enemy.components.physics.body.radius or 10) * 1.5
        end
        -- Clear any cached shield radius so it recomputes using new visuals size
        enemy.shieldRadius = nil
        enemy._shieldRadiusVisualSize = nil
    end
    return enemy
end

-- Create an NPC/freighter ship
function EntityFactory.createFreighter(shipId, x, y)
    local shipConfig = Content.getShip(shipId)
    local config = {
        isFreighter = true,
        bounty = (shipConfig and shipConfig.bounty) or 100, -- Higher bounty for valuable cargo
        xpReward = (shipConfig and shipConfig.xpReward) or 200,
    }
    return EntityFactory.create("ship", shipId, x, y, config)
end

return EntityFactory
