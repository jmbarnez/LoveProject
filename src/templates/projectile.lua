local Position = require("src.components.position")
local Velocity = require("src.components.velocity")
local Renderable = require("src.components.renderable")
local Collidable = require("src.components.collidable")
local Damage = require("src.components.damage")
local TimedLife = require("src.components.timed_life")
local EventDispatcher = require("src.templates.projectile_system.event_dispatcher")
local EffectManager = require("src.templates.projectile_system.effect_manager")
local PluginRegistry = require("src.templates.projectile_system.plugin_registry")

require("src.templates.projectile_system.effects.init")
require("src.templates.projectile_system.plugins.init")

local Projectile = {}
Projectile.__index = Projectile
local ProjectileEvents = EventDispatcher.EVENTS

function Projectile.new(x, y, angle, friendly, config)
    local self = setmetatable({}, Projectile)
    self.tag = "bullet" -- Keep tag for compatibility with some legacy checks

    -- Set projectile type for network synchronization
    self.projectileType = config.id or "gun_bullet"

    local speed = config.speedOverride or (config.physics and config.physics.speed) or 700
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed

    self.components = {
        bullet = { 
            source = config.source, -- Track shooter to avoid self-hit
            impact = config.impact  -- Pass impact effects for collision visuals
        },
        position = Position.new({ x = x, y = y, angle = angle }),
        velocity = Velocity.new({ x = vx, y = vy }),
        collidable = (config.collidable and config.collidable.radius == 0) and nil or Collidable.new({
            radius = (config.collidable and config.collidable.radius) or (config.renderable and config.renderable.props and config.renderable.props.radius) or 2,
            friendly = friendly,
        }),
        renderable = Renderable.new(
            (config.renderable and config.renderable.type) or "bullet",
            (function()
                local props = (config.renderable and config.renderable.props) or {}
                -- Allow callers to override the visual kind (e.g., 'salvaging_laser')
                if config.kind then props.kind = config.kind end
                -- Override visuals if provided
                if config.tracerWidth then props.tracerWidth = config.tracerWidth end
                if config.coreRadius then props.coreRadius = config.coreRadius end
                if config.color then props.color = config.color end
                -- Default bullet color to blue if no color specified and not a laser
                local kind = props.kind or config.kind or 'bullet'
                if not props.color and kind ~= 'laser' and kind ~= 'salvaging_laser' then
                    props.color = {0.35, 0.7, 1.0, 1.0}
                end
                -- Override length/maxLength for all projectile types
                if config.length then props.length = config.length end
                if config.maxLength then props.maxLength = config.maxLength end
                -- Keep a copy of the intended max beam length for lasers (combat), mining, and salvaging beams
                if props.kind == "laser" or props.kind == "salvaging_laser" or props.kind == "mining_laser" then
                    props.maxLength = props.maxLength or props.length
                end
                -- For beam types (laser/mining/salvaging), ensure angle is set in props for collision system/rendering
                if props.kind == "laser" or props.kind == "salvaging_laser" or props.kind == "mining_laser" then
                    props.angle = angle
                end
                return props
            end)()
        ),
        -- Create Damage component for projectiles. Allow lasers to have damage if provided in config.
        damage = (function()
            local hasDamage = config.damage ~= nil
            if hasDamage then
                local dmgValue = config.damage or 1
                return Damage.new(dmgValue)
            end
            return nil
        end)(),
        timed_life = TimedLife.new(
            (config.timed_life and config.timed_life.duration) or 2.0
        ),
        -- Add max range tracking
        max_range = (function()
            if config.maxRange and config.maxRange > 0 then
                return {
                    maxDistance = config.maxRange,
                    traveledDistance = 0,
                    startX = x,
                    startY = y,
                    kind = config.kind or 'bullet'
                }
            end
            return nil
        end)(),
    }


    local dispatcher = EventDispatcher.new()
    self.event_dispatcher = dispatcher
    self.components.projectile_events = dispatcher:asComponent()

    local effectManager = EffectManager.new(self, dispatcher)
    self.effect_manager = effectManager

    function self:addEffect(effectDefinition)
        return effectManager:addEffect(effectDefinition)
    end


    local pluginContext = {
        projectile = self,
        config = config,
        dispatcher = dispatcher,
        events = dispatcher,
        manager = effectManager,
        addEffect = function(effectDefinition)
            return effectManager:addEffect(effectDefinition)
        end,
    }

    PluginRegistry.apply("default", pluginContext)

    if config.plugin then
        PluginRegistry.apply(config.plugin, pluginContext)
    end

    if config.kind and config.kind ~= config.plugin then
        PluginRegistry.apply(config.kind, pluginContext)
    end

    effectManager:loadConfig(config.effects or {})
    effectManager:loadConfig(config.additionalEffects or {})

    dispatcher:emit(ProjectileEvents.SPAWN, {
        projectile = self,
        config = config,
    })

    return self
end

return Projectile
