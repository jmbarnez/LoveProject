local Projectile = require("src.systems.projectile.projectile")
local NetworkSession = require("src.core.network.session")
local State = require("src.game.state")

local Projectiles = {}

function Projectiles.spawn(x, y, angle, friendly, opts, world)
    local Settings = require("src.core.settings")
    local networkingSettings = Settings.getNetworkingSettings()
    local manager = State.networkManager or NetworkSession.getManager()

    if networkingSettings and networkingSettings.host_authoritative_projectiles then
        if manager and manager:isMultiplayer() and not manager:isHost() then
            return
        end
    end

    local projectile_id = (opts and opts.projectile) or "gun_bullet"
    opts = opts or {}

    -- If we have a definition from embedded projectile, use it as the base
    local base_config = {}
    if opts.definition and type(opts.definition) == "table" then
        -- Use the embedded projectile definition as base
        base_config = opts.definition
    else
        -- Fallback to Content system for projectile definitions
        local Content = require("src.content.content")
        local projectileDef = Content.getProjectile(projectile_id)
        if projectileDef then
            base_config = projectileDef
        end
    end

    -- Merge with runtime options, with runtime options taking precedence
    local extra_config = {}
    
    -- Copy base config first
    for k, v in pairs(base_config) do
        extra_config[k] = v
    end
    
    -- Override with runtime options
    extra_config.angle = angle
    extra_config.friendly = friendly
    extra_config.damage = opts.damage or base_config.damage
    extra_config.kind = opts.kind or base_config.kind
    extra_config.speedOverride = opts.speedOverride or opts.projectileSpeed or opts.vx or opts.vy
    extra_config.tracerWidth = opts.tracerWidth
    extra_config.coreRadius = opts.coreRadius
    extra_config.color = opts.color
    extra_config.impact = opts.impact
    extra_config.length = opts.length
    extra_config.timed_life = opts.timed_life
    extra_config.additionalEffects = opts.additionalEffects
    extra_config.sourcePlayerId = opts.sourcePlayerId
    extra_config.sourceShipId = opts.sourceShipId
    extra_config.sourceTurretSlot = opts.sourceTurretSlot
    extra_config.sourceTurretId = opts.sourceTurretId
    extra_config.sourceTurretType = opts.sourceTurretType
    extra_config.source = opts.source
    extra_config.targetX = opts.targetX
    extra_config.targetY = opts.targetY
    extra_config.targetAngle = opts.targetAngle

    -- Handle velocity override if provided
    if opts.vx and opts.vy then
        extra_config.vx = opts.vx
        extra_config.vy = opts.vy
        extra_config.speedOverride = math.sqrt(opts.vx * opts.vx + opts.vy * opts.vy)
    end

    local projectile = Projectile.new(x, y, angle, friendly, extra_config, world)
    if projectile and world then
        world:addEntity(projectile)
    end
end

return Projectiles
