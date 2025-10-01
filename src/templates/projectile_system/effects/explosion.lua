local EffectRegistry = require("src.templates.projectile_system.effect_registry")
local Events = require("src.templates.projectile_system.event_dispatcher").EVENTS
local Effects = require("src.systems.effects")

local function trigger_explosion(projectile, power, spawnDebris)
    local pos = projectile.components.position
    if not pos then return end

    Effects.createExplosion(pos.x, pos.y, power, spawnDebris)
end

local function factory(context, config)
    local projectile = context.projectile
    local damageComponent = projectile.components.damage
    local power = config.power
        or (damageComponent and damageComponent.value)
        or 5
    local spawnDebris = config.spawnDebris or false

    local events = {}

    if config.onSpawn then
        events[Events.SPAWN] = function()
            trigger_explosion(projectile, power, spawnDebris)
        end
    end

    if config.onHit ~= false then
        events[Events.HIT] = function()
            trigger_explosion(projectile, power, spawnDebris)
        end
    end

    if config.onExpire ~= false then
        events[Events.EXPIRE] = function()
            trigger_explosion(projectile, power, spawnDebris)
        end
    end

    return {
        events = events,
    }
end

EffectRegistry.register("explosion", factory)

return true
