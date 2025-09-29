local Theme = require("src.core.theme")
local Util = require("src.core.util")

local ResourceNodeBars = {}

local MINING_FULL = {1.0, 0.82, 0.25, 0.95}
local MINING_EMPTY = {1.0, 0.34, 0.14, 0.9}
local SALVAGE_FULL = {0.42, 1.0, 0.62, 0.95}
local SALVAGE_EMPTY = {1.0, 0.62, 0.2, 0.9}

local function mixColor(fullColor, emptyColor, pct)
    pct = Util.clamp01(pct)
    local inv = 1 - pct
    local r = (fullColor[1] or 1) * pct + (emptyColor[1] or 1) * inv
    local g = (fullColor[2] or 1) * pct + (emptyColor[2] or 1) * inv
    local b = (fullColor[3] or 1) * pct + (emptyColor[3] or 1) * inv
    local a = (fullColor[4] or 1) * pct + (emptyColor[4] or 1) * inv
    return r, g, b, a
end

local function drawBar(entity, pct, opts)
    if not entity then return end

    opts = opts or {}
    local components = entity.components or {}
    local radius = opts.radius
        or (components.collidable and components.collidable.radius)
        or entity.radius
        or 24
    local pos = components.position
    local angle = (pos and pos.angle) or 0

    local barWidth = math.max(opts.minWidth or 48, radius * (opts.widthScale or 1.6))
    local barHeight = opts.height or 5
    local offset = opts.offset or 16
    local backgroundAlpha = opts.shadowAlpha or 0.65

    local x0 = -barWidth * 0.5
    local y0 = -(radius + offset)

    love.graphics.push()
    love.graphics.rotate(-angle)

    Theme.setColor(Theme.withAlpha(Theme.colors.shadow, backgroundAlpha))
    love.graphics.rectangle('fill', x0, y0, barWidth, barHeight, 2, 2)

    local r, g, b, a = opts.colorFromPct(pct)
    love.graphics.setColor(r, g, b, a or 1)
    love.graphics.rectangle('fill', x0, y0, barWidth * pct, barHeight, 2, 2)

    local borderColor = opts.borderColor or Theme.withAlpha(Theme.colors.borderBright, 0.55)
    Theme.setColor(borderColor)
    love.graphics.rectangle('line', x0, y0, barWidth, barHeight, 2, 2)

    love.graphics.pop()
end

function ResourceNodeBars.drawMiningBar(entity, opts)
    opts = opts or {}
    local components = entity and entity.components
    local mineable = components and components.mineable
    if not mineable then return end

    local maxDurability = mineable.maxDurability or mineable.durability or 0
    if maxDurability <= 0 then return end

    local durability = math.max(0, mineable.durability or maxDurability)
    local pct = Util.clamp01(durability / maxDurability)

    if not (opts.force or mineable.isBeingMined or opts.isHovered or pct < 1) then
        return
    end

    drawBar(entity, pct, {
        radius = opts.radius,
        minWidth = opts.minWidth or 56,
        widthScale = opts.widthScale or 1.9,
        offset = opts.offset or 18,
        height = opts.height or 5,
        shadowAlpha = 0.7,
        borderColor = Theme.withAlpha(Theme.colors.borderBright, 0.55),
        colorFromPct = function(progress)
            return mixColor(MINING_FULL, MINING_EMPTY, progress)
        end
    })
end

function ResourceNodeBars.drawSalvageBar(entity, opts)
    opts = opts or {}
    local components = entity and entity.components
    local wreckage = components and components.wreckage
    if not wreckage then return end

    local maxAmount = wreckage.maxSalvageAmount or wreckage.salvageAmount or 0
    if maxAmount <= 0 then return end

    local remaining = math.max(0, wreckage.salvageAmount or maxAmount)
    local pct = Util.clamp01(remaining / maxAmount)

    if not (opts.force or wreckage.isBeingSalvaged or opts.isHovered or pct < 1) then
        return
    end

    drawBar(entity, pct, {
        radius = opts.radius,
        minWidth = opts.minWidth or 52,
        widthScale = opts.widthScale or 1.7,
        offset = opts.offset or 14,
        height = opts.height or 5,
        shadowAlpha = 0.68,
        borderColor = Theme.withAlpha(Theme.colors.borderBright, 0.5),
        colorFromPct = function(progress)
            return mixColor(SALVAGE_FULL, SALVAGE_EMPTY, progress)
        end
    })
end

return ResourceNodeBars
