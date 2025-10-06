local BehaviorRegistry = require("src.templates.projectile_system.behavior_registry")
local ProjectileEvents = require("src.templates.projectile_system.event_dispatcher").EVENTS
local State = require("src.game.state")

-- Local function to create projectiles without circular dependency
local function createProjectile(x, y, angle, friendly, config)
    local speed = config.speedOverride or 700
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed
    
    return {
        tag = "bullet",
        projectileType = config.projectile or config.projectileId or "gun_bullet",
        components = {
            bullet = {
                source = config.source,
                impact = config.impact,
                slot = config.sourceTurretSlot,
                turretId = config.sourceTurretId,
                turretType = config.sourceTurretType,
                sourcePlayerId = config.sourcePlayerId,
                sourceShipId = config.sourceShipId,
            },
            position = { x = x, y = y, angle = angle },
            velocity = { x = vx, y = vy },
            collidable = {
                radius = 2,
                friendly = friendly,
            },
            damage = { value = config.damage or 1 },
            renderable = {
                visible = true,
                layer = "projectiles",
                renderer = "fields", -- Use the fields renderer for area denial
                props = {
                    kind = config.kind or "area_field",
                    radius = 40,
                    coreRadius = 20,
                    color = {0.2, 0.6, 1.0, 0.4}, -- Blue area field
                }
            },
            timed_life = {
                duration = 3.0
            }
        }
    }
end

local function spawn_field(projectile, payload, config)
    local position = projectile.components and projectile.components.position
    if not position then return end

    local world = (payload and payload.world) or State.world
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
        impact = projectile.components.bullet and projectile.components.bullet.impact,
        source = projectile.components.bullet and projectile.components.bullet.source,
        sourcePlayerId = projectile.components.bullet and projectile.components.bullet.sourcePlayerId,
        sourceShipId = projectile.components.bullet and projectile.components.bullet.sourceShipId,
        sourceTurretSlot = projectile.components.bullet and projectile.components.bullet.slot,
        sourceTurretId = projectile.components.bullet and projectile.components.bullet.turretId,
        sourceTurretType = projectile.components.bullet and projectile.components.bullet.turretType,
    }

    local friendly = projectile.components.collidable and projectile.components.collidable.friendly
    local fieldProjectile = createProjectile(position.x, position.y, 0, friendly, opts)
    if fieldProjectile and world then
        world:addEntity(fieldProjectile)
    end
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
