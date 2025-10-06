local EffectRegistry = require("src.systems.projectile.effect_registry")
local ProjectileEvents = require("src.systems.projectile.event_dispatcher").EVENTS
local Effects = require("src.systems.effects")

local function spawnParticle(config, projectile)
    local position = projectile.components and projectile.components.position
    if not position then return end

    local angle = math.random() * math.pi * 2
    local speed = (config.speed or 120) * (0.5 + math.random())
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed
    local color = config.color or {1.0, 0.8, 0.4, 0.8}

    Effects.add({
        type = config.type or "spark",
        x = position.x + (math.random() - 0.5) * (config.spread or 8),
        y = position.y + (math.random() - 0.5) * (config.spread or 8),
        vx = vx,
        vy = vy,
        t = 0,
        life = config.life or 0.35,
        color = color,
        size = config.size or 2,
    })
end

local function factory(context, config)
    local projectile = context.projectile
    local timer = 0
    local interval = config.interval or 0.08
    local burst = config.burst or 0

    local events = {}

    events[ProjectileEvents.SPAWN] = function()
        if burst and burst > 0 then
            for _ = 1, burst do
                spawnParticle(config, projectile)
            end
        end
    end

    events[ProjectileEvents.UPDATE] = function(payload)
        local dt = (payload and payload.dt) or 0
        timer = timer - dt
        while timer <= 0 do
            spawnParticle(config, projectile)
            timer = timer + interval
        end
    end

    return {
        events = events,
    }
end

EffectRegistry.register("particle_emitter", factory)
EffectRegistry.register("particles", factory)

return true
