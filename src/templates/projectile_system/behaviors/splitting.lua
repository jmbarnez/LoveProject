local BehaviorRegistry = require("src.templates.projectile_system.behavior_registry")
local ProjectileEvents = require("src.templates.projectile_system.event_dispatcher").EVENTS
local State = require("src.game.state")

local function spawnFragments(projectile, payload, config)
    local world = (payload and payload.world) or State.world
    if not world then return end

    local count = config.count or config.fragments or 3
    if count <= 0 then return end

    local spread = config.spread or math.rad(35)
    local speed = config.speed or (projectile.components.velocity and math.sqrt((projectile.components.velocity.x or 0)^2 + (projectile.components.velocity.y or 0)^2)) or 800
    local originAngle = (payload and payload.impactAngle) or (projectile.components.position and projectile.components.position.angle) or 0
    local baseAngle = originAngle - spread * 0.5

    local projectileId = config.projectile or config.projectileId or projectile.projectileType
    local damageScale = config.damageMultiplier or 0.5
    local baseDamage = (projectile.components.damage and projectile.components.damage.value) or config.damage or 1

    local position = projectile.components.position
    if not position then return end

    local optsTemplate = {
        projectile = projectileId,
        damage = baseDamage * damageScale,
        speedOverride = speed,
        kind = projectile.components.renderable and projectile.components.renderable.props and projectile.components.renderable.props.kind,
        impact = projectile.components.bullet and projectile.components.bullet.impact,
        source = projectile.components.bullet and projectile.components.bullet.source,
        sourcePlayerId = projectile.components.bullet and projectile.components.bullet.sourcePlayerId,
        sourceShipId = projectile.components.bullet and projectile.components.bullet.sourceShipId,
        sourceTurretSlot = projectile.components.bullet and projectile.components.bullet.slot,
        sourceTurretId = projectile.components.bullet and projectile.components.bullet.turretId,
        sourceTurretType = projectile.components.bullet and projectile.components.bullet.turretType,
    }

    -- Use delayed require to avoid circular dependency
    local Projectiles = require("src.game.projectiles")
    
    for i = 1, count do
        local frac = (count == 1) and 0.5 or ((i - 1) / math.max(1, count - 1))
        local angle = baseAngle + spread * frac
        local opts = {}
        for k, v in pairs(optsTemplate) do opts[k] = v end
        Projectiles.spawn(position.x, position.y, angle, projectile.components.collidable and projectile.components.collidable.friendly, opts)
    end
end

local function factory(context, config)
    local events = {}

    local function handle(payload)
        if config.on ~= "expire" then
            spawnFragments(context.projectile, payload, config)
        end
    end

    events[ProjectileEvents.HIT] = function(payload)
        if config.trigger == "expire" then return end
        handle(payload)
    end

    events[ProjectileEvents.EXPIRE] = function(payload)
        if config.trigger == "hit" then return end
        spawnFragments(context.projectile, payload, config)
    end

    return { events = events }
end

BehaviorRegistry.register("splitting", factory)

return true
