local EffectRegistry = require("src.systems.projectile.effect_registry")
local function factory(context, config)
    return {
        components = {
            {
                name = "dynamic_light",
                config = {
                    color = config.color or config.tint,
                    radius = config.radius,
                    pulse = config.pulse,
                    intensity = config.intensity,
                    offset = config.offset,
                },
                overwrite = config.overwrite ~= false,
            }
        }
    }
end

EffectRegistry.register("dynamic_light", factory)
EffectRegistry.register("light", factory)

return true
