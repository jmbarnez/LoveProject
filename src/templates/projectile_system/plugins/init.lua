local PluginRegistry = require("src.templates.projectile_system.plugin_registry")

PluginRegistry.register("default", function(context)
    local config = context.config or {}
    if config.trail and not config.effects then
        context.addEffect({
            type = "trail",
            interval = config.trail.interval,
            color = config.trail.color,
            size = config.trail.size,
            particleType = config.trail.particleType,
            life = config.trail.life,
            burstOnSpawn = config.trail.burstOnSpawn,
        })
    end

    if config.explosion and not config.effects then
        context.addEffect({
            type = "explosion",
            power = config.explosion.power,
            spawnDebris = config.explosion.spawnDebris,
            onHit = config.explosion.onHit,
            onExpire = config.explosion.onExpire,
            onSpawn = config.explosion.onSpawn,
        })
    end
end)

PluginRegistry.register("explosive", function(context)
    local config = context.config or {}
    if not config.explosionPower then return end

    context.addEffect({
        type = "explosion",
        power = config.explosionPower,
        spawnDebris = config.explosionDebris,
        onHit = config.explosionOnHit,
        onExpire = config.explosionOnExpire,
        onSpawn = config.explosionOnSpawn,
    })
end)

PluginRegistry.register("trail", function(context)
    local config = context.config or {}
    if not config.trailColor then return end

    context.addEffect({
        type = "trail",
        color = config.trailColor,
        interval = config.trailInterval,
        size = config.trailSize,
        life = config.trailLife,
        particleType = config.trailParticle,
    })
end)

return true
