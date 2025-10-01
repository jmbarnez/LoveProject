local EffectRegistry = require("src.templates.projectile_system.effect_registry")
local Events = require("src.templates.projectile_system.event_dispatcher").EVENTS
local Effects = require("src.systems.effects")

local function factory(context, config)
    local projectile = context.projectile
    local interval = config.interval or 0.05
    local timer = 0
    local color = config.color or {0.5, 0.8, 1.0, 0.4}
    local size = config.size or 1.2
    local particleType = config.particleType or 'spark'

    local function spawn_trail()
        local pos = projectile.components.position
        if not pos then return end

        local particle = {
            type = particleType,
            x = pos.x,
            y = pos.y,
            vx = 0,
            vy = 0,
            t = 0,
            life = config.life or 0.3,
            color = color,
            size = size,
        }
        Effects.add(particle)
    end

    local events = {}

    events[Events.UPDATE] = function(payload)
        timer = timer + (payload and payload.dt or 0)
        if timer >= interval then
            timer = timer - interval
            spawn_trail()
        end
    end

    events[Events.SPAWN] = function()
        if config.burstOnSpawn then
            spawn_trail()
        end
    end

    events[Events.EXPIRE] = function()
        timer = 0
    end

    return {
        events = events,
    }
end

EffectRegistry.register("trail", factory)

return true
