local BehaviorRegistry = require("src.systems.projectile.behavior_registry")
local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS

local function spawn_field(projectile, payload, config)
    local position = projectile.components and projectile.components.position
    if not position then return end

    local world = payload and payload.world
    if not world then return end

    local radius = config.radius or 140
    local duration = config.duration or 2.5
    local damage = config.damage or (projectile.components.damage and projectile.components.damage.value * (config.damageMultiplier or 0.25)) or 5

    local opts = {
        projectile = config.projectile or config.projectileId or projectile.projectileType,
        speedOverride = 0,
        damage = damage,
        kind = "area_field",
        tracerWidth = radius * 2,
        coreRadius = radius,
        color = config.color or {0.35, 0.85, 1.0, 0.35},
        timed_life = { duration = duration },
        additionalEffects = config.effects,
        behaviors = config.fieldBehaviors or {},
        impact = projectile.components.projectile and projectile.components.projectile.impact,
        source = projectile.components.projectile and projectile.components.projectile.source,
        sourcePlayerId = projectile.components.projectile and projectile.components.projectile.sourcePlayerId,
        sourceShipId = projectile.components.projectile and projectile.components.projectile.sourceShipId,
        sourceTurretSlot = projectile.components.projectile and projectile.components.projectile.slot,
        sourceTurretId = projectile.components.projectile and projectile.components.projectile.turretId,
        sourceTurretType = projectile.components.projectile and projectile.components.projectile.turretType,
    }

    local friendly = projectile.components.collidable and projectile.components.collidable.friendly
    
    -- Use delayed require to avoid circular dependency
    local Projectiles = require("src.game.projectiles")
    Projectiles.spawn(position.x, position.y, 0, friendly, opts)
end

local function factory(context, config)
    local events = {}

    events[ProjectileEvents.HIT] = function(payload)
        if config.trigger == "expire" then return end
        spawn_field(context.projectile, payload, config)
    end

    events[ProjectileEvents.EXPIRE] = function(payload)
        if config.trigger == "hit" then return end
        spawn_field(context.projectile, payload, config)
    end

    return {
        events = events,
    }
end

BehaviorRegistry.register("area_denial", factory)
BehaviorRegistry.register("area", factory)
BehaviorRegistry.register("area_control", factory)

return true
