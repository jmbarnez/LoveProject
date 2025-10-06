local EffectRegistry = require("src.templates.projectile_system.effect_registry")
local DynamicLight = require("src.components.dynamic_light")

local function factory(context, config)
    local projectile = context.projectile
    local lightComponent = DynamicLight.new({
        color = config.color or config.tint or {1.0, 0.85, 0.4, 0.9},
        radius = config.radius or 24,
        pulse = config.pulse,
        intensity = config.intensity or 1.0,
        offset = config.offset,
    })

    return {
        components = {
            {
                name = "dynamic_light",
                component = lightComponent,
                force = config.overwrite ~= false,
            }
        }
    }
end

EffectRegistry.register("dynamic_light", factory)
EffectRegistry.register("light", factory)

return true
