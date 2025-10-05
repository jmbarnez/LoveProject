local EntityFactory = require("src.templates.entity_factory")
local NetworkSession = require("src.core.network.session")
local State = require("src.game.state")

local Projectiles = {}

function Projectiles.spawn(x, y, angle, friendly, opts)
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

    local extra_config = {
        angle = angle,
        friendly = friendly,
        damage = opts.damage,
        kind = opts.kind,
        speedOverride = opts.speedOverride or opts.projectileSpeed,
        tracerWidth = opts.tracerWidth,
        coreRadius = opts.coreRadius,
        color = opts.color,
        impact = opts.impact,
        length = opts.length,
        timed_life = opts.timed_life,
        additionalEffects = opts.additionalEffects,
        sourcePlayerId = opts.sourcePlayerId,
        sourceShipId = opts.sourceShipId,
        sourceTurretSlot = opts.sourceTurretSlot,
        sourceTurretId = opts.sourceTurretId,
        sourceTurretType = opts.sourceTurretType,
    }
    extra_config.source = opts.source

    local projectile = EntityFactory.create("projectile", projectile_id, x, y, extra_config)
    if projectile and State.world then
        State.world:addEntity(projectile)
    end
end

return Projectiles
