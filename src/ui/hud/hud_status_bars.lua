local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")
local UIUtils = require("src.ui.common.utils")

-- Liquid-Filled Spiral Energy Display
local function drawLiquidSpiralEnergy(x, y, size, energyPct, time)
    energyPct = math.max(0, math.min(1, energyPct))
    
    local centerX, centerY = x + size * 0.5, y + size * 0.5
    local outerRadius = size * 0.4
    local innerRadius = 1 -- Start from very center (1 pixel from center)
    local spiralWidth = 8 -- Width of the spiral channel
    
    
    -- Inner core circle
    Theme.setColor(Theme.withAlpha(Theme.colors.bg1, 0.8))
    love.graphics.circle("fill", centerX, centerY, innerRadius)
    Theme.setColor(Theme.withAlpha(Theme.colors.border, 0.8))
    love.graphics.circle("line", centerX, centerY, innerRadius)
    
    -- Draw spiral channel (empty groove)
    local totalTurns = 3
    local totalAngle = totalTurns * 2 * math.pi
    local segments = 100
    
    -- Draw spiral channel background
    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.7))
    love.graphics.setLineWidth(spiralWidth + 2)
    for i = 0, segments - 1 do
        local t1 = i / segments
        local t2 = (i + 1) / segments
        local angle1 = totalAngle * t1 - math.pi / 2
        local angle2 = totalAngle * t2 - math.pi / 2
        local radius1 = outerRadius - (outerRadius - innerRadius) * t1
        local radius2 = outerRadius - (outerRadius - innerRadius) * t2
        
        local x1 = centerX + math.cos(angle1) * radius1
        local y1 = centerY + math.sin(angle1) * radius1
        local x2 = centerX + math.cos(angle2) * radius2
        local y2 = centerY + math.sin(angle2) * radius2
        
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -- Draw cyan liquid filling the spiral (from outside in, depletes outside first)
    if energyPct > 0 then
        -- Calculate which segments to draw (start from center, fill outward)
        local totalFilledSegments = math.floor(segments * energyPct)
        local startSegment = segments - totalFilledSegments -- Start from the end (center)
        
        -- Draw solid yellow liquid spiral (no rotation animation)
        local liquidColor = {1.0, 0.9, 0.0, 0.9} -- Bright yellow
        Theme.setColor(liquidColor)
        love.graphics.setLineWidth(spiralWidth)
        
        for i = startSegment, segments - 1 do
            local t1 = i / segments
            local t2 = (i + 1) / segments
            local angle1 = totalAngle * t1 - math.pi / 2 -- No rotation animation
            local angle2 = totalAngle * t2 - math.pi / 2 -- No rotation animation
            local radius1 = outerRadius - (outerRadius - innerRadius) * t1
            local radius2 = outerRadius - (outerRadius - innerRadius) * t2
            
            local x1 = centerX + math.cos(angle1) * radius1
            local y1 = centerY + math.sin(angle1) * radius1
            local x2 = centerX + math.cos(angle2) * radius2
            local y2 = centerY + math.sin(angle2) * radius2
            
            love.graphics.line(x1, y1, x2, y2)
        end
    end
    
    -- Critical energy warning effect - pulses along entire spiral channel
    if energyPct < 0.25 then
        local flash = math.sin(time * 8) * 0.5 + 0.5
        local oldLineWidth = love.graphics.getLineWidth()
        Theme.setColor(Theme.withAlpha(Theme.colors.danger, flash * 0.3))
        love.graphics.setLineWidth(spiralWidth)
        
        -- Draw warning effect along the entire spiral channel
        for i = 0, segments - 1 do
            local t1 = i / segments
            local t2 = (i + 1) / segments
            local angle1 = totalAngle * t1 - math.pi / 2
            local angle2 = totalAngle * t2 - math.pi / 2
            local radius1 = outerRadius - (outerRadius - innerRadius) * t1
            local radius2 = outerRadius - (outerRadius - innerRadius) * t2
            
            local x1 = centerX + math.cos(angle1) * radius1
            local y1 = centerY + math.sin(angle1) * radius1
            local x2 = centerX + math.cos(angle2) * radius2
            local y2 = centerY + math.sin(angle2) * radius2
            
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setLineWidth(oldLineWidth)
    end
    
    --[[
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or oldFont)
    local energyText = string.format("%d%%", math.floor(energyPct * 100))
    local font = love.graphics.getFont()
    local textW = font:getWidth(energyText)
    local textH = font:getHeight()

    -- Black text in center
    Theme.setColor({0, 0, 0, 1}) -- Pure black
    love.graphics.print(energyText, centerX - textW * 0.5, centerY - textH * 0.5)
    if oldFont then love.graphics.setFont(oldFont) end
    ]]
    
    love.graphics.setLineWidth(1)
end

-- A reusable, stateful component for a single status bar.
local StatusBar = {}
StatusBar.__index = StatusBar

function StatusBar.new(config)
    local self = setmetatable({}, StatusBar)
    self.label = config.label
    self.color = config.color
    self.currentValue = 0
    self.targetValue = 0
    self.maxValue = 0
    self.isFlashing = false
    self.flashTimer = 0
    self.damageTaken = 0
    self.damageDecayTimer = 0
    return self
end

function StatusBar:setValue(target, max)
    local diff = self.targetValue - target
    if diff > 0 then
        -- Damage was taken, so add to the damage indicator
        self.damageTaken = self.damageTaken + diff
        self.damageDecayTimer = 0.5 -- Reset decay timer on new damage
    else
        -- Value increased (regeneration), so subtract from the damage indicator
        self.damageTaken = math.max(0, self.damageTaken + diff)
    end
    self.targetValue = target
    self.maxValue = max
end

function StatusBar:update(dt)
    -- Animate the bar towards its target value for a smooth transition.
    self.currentValue = Util.lerp(self.currentValue, self.targetValue, 1 - math.exp(-10 * dt))

    -- Handle the flashing alert for low status.
    local criticalThreshold = 0.25
    if self.maxValue > 0 and (self.targetValue / self.maxValue) < criticalThreshold then
        self.isFlashing = true
        self.flashTimer = (self.flashTimer + dt * 4) % 2
    else
        self.isFlashing = false
    end

    -- Update damage decay timer
    if self.damageTaken > 0 then
        self.damageDecayTimer = self.damageDecayTimer - dt
        if self.damageDecayTimer <= 0 then
            self.damageTaken = 0
        end
    end
end

function StatusBar:draw(x, y, w, h)
    local pct = math.max(0, math.min(1, self.maxValue > 0 and (self.currentValue / self.maxValue) or 0))
    local targetPct = math.max(0, math.min(1, self.maxValue > 0 and (self.targetValue / self.maxValue) or 0))

    -- Determine the bar's color, applying a flashing effect if needed.
    local barColor = self.color
    if self.isFlashing then
        local flash = 0.5 + 0.5 * math.sin(love.timer.getTime() * 10)
        barColor = Theme.blend(self.color, Theme.semantic.statusHull, flash) -- flash toward red
    end

    -- Draw the "damage taken" bar behind the main bar
    if self.damageTaken > 0 and self.maxValue > 0 then
        local damagePct = self.damageTaken / self.maxValue
        local damageWidth = damagePct * w
        local currentWidth = targetPct * w
        Theme.drawSciFiBar(x + currentWidth, y, math.max(0, damageWidth), h, 1, Theme.semantic.statusHull)
    end

    -- Draw the main bar.
    if self.label == "XP" then
        Theme.drawSimpleBar(x, y, w, h, pct, barColor)
    else
        Theme.drawSciFiBar(x, y, w, h, pct, barColor)
    end

    -- Draw the numerical text overlay (not for XP).
    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
    if self.label ~= "XP" then
        local text = string.format("%d/%d", math.floor(self.targetValue), self.maxValue)
        local font = love.graphics.getFont()
        local metrics = UIUtils.getCachedTextMetrics(text, font)
        local textX = x + (w - metrics.width) / 2
        local textY = y + (h - metrics.height) / 2
        Theme.setColor(Theme.colors.textStatus)
        love.graphics.print(text, textX, textY)
    end
    if oldFont then love.graphics.setFont(oldFont) end
end

-- Main module for managing HUD (player) status bars.
local HUDStatusBars = {}
local initialized = false
local bars = {}

-- Energy animation state
local energyAnimation = {
    current = 0,
    target = 0,
    lastUpdate = 0
}

local bossState = {
    entity = nil,
    label = nil,
    hp = 0,
    maxHp = 1,
    shield = 0,
    maxShield = 0,
    smoothHp = 0,
    smoothShield = 0,
    displayTimer = 0,
}

local BOSS_BAR_RANGE = 2000
local BOSS_BAR_RANGE_SQ = BOSS_BAR_RANGE * BOSS_BAR_RANGE
local BOSS_BAR_HOLD_TIME = 0.8
local BOSS_BAR_FADE_TIME = 0.4

local function drawBossMeter(x, y, w, h, pct, color, text, alpha)
    local clampedPct = math.max(0, math.min(1, pct or 0))
    
    -- Background - black with cyan border
    Theme.setColor({0.0, 0.0, 0.0, 0.8 * alpha})
    love.graphics.rectangle('fill', x, y, w, h, 8, 8)

    -- Fill bar - normal health/shield colors
    local fillColor = {color[1], color[2], color[3], (color[4] or 1) * alpha}
    Theme.setColor(fillColor)
    love.graphics.rectangle('fill', x, y, w * clampedPct, h, 8, 8)

    -- Border - cyan theme color
    Theme.setColor({0.5, 0.7, 0.9, 0.8 * alpha})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, w, h, 8, 8)
    love.graphics.setLineWidth(1)

    -- Text - white for readability
    local prevFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    Theme.setColor({1.0, 1.0, 1.0, alpha})
    love.graphics.print(text, x + (w - textWidth) / 2, y + (h - textHeight) / 2)
    if prevFont then love.graphics.setFont(prevFont) end
end

local function updateBossBar(dt, player, world)
    bossState.displayTimer = math.max(0, bossState.displayTimer - dt)

    if not (world and world.get_entities_with_components and player and player.components and player.components.position) then
        if bossState.displayTimer <= 0 then
            bossState.entity = nil
            bossState.label = nil
        end
        bossState.smoothHp = Util.lerp(bossState.smoothHp or 0, 0, 1 - math.exp(-8 * dt))
        bossState.smoothShield = Util.lerp(bossState.smoothShield or 0, 0, 1 - math.exp(-8 * dt))
        return
    end

    local playerPos = player.components.position
    local nearest, nearestDistSq = nil, nil
    local candidates = world:get_entities_with_components("health", "position")
    for _, entity in ipairs(candidates) do
        if (entity.isBoss or entity.shipId == 'boss_drone') and not entity.dead then
            local pos = entity.components.position
            if pos then
                local dx = pos.x - playerPos.x
                local dy = pos.y - playerPos.y
                local distSq = dx * dx + dy * dy
                if not nearestDistSq or distSq < nearestDistSq then
                    nearest = entity
                    nearestDistSq = distSq
                end
            end
        end
    end

    if nearest and nearestDistSq and nearestDistSq <= BOSS_BAR_RANGE_SQ then
        local h = nearest.components.health
        if h then
            local hp = h.hp or h.current or 0
            local maxHp = h.maxHP or h.max or math.max(1, hp)
            local shield = h.shield or 0
            local maxShield = h.maxShield or 0

            if bossState.entity ~= nearest then
                bossState.smoothHp = hp
                bossState.smoothShield = shield
            end

            bossState.entity = nearest
            bossState.label = nearest.name or nearest.displayName or "Boss Threat"
            bossState.hp = hp
            bossState.maxHp = math.max(1, maxHp)
            bossState.shield = shield
            bossState.maxShield = math.max(0, maxShield)
            bossState.displayTimer = BOSS_BAR_HOLD_TIME
        end
    elseif bossState.entity then
        -- Check if current boss is still in range
        local currentBossPos = bossState.entity.components and bossState.entity.components.position
        local inRange = false
        if currentBossPos then
            local dx = currentBossPos.x - playerPos.x
            local dy = currentBossPos.y - playerPos.y
            local distSq = dx * dx + dy * dy
            inRange = distSq <= BOSS_BAR_RANGE_SQ
        end
        
        if not inRange then
            -- Player is outside range, hide boss HUD immediately
            bossState.entity = nil
            bossState.label = nil
            bossState.displayTimer = 0
        else
            local h = bossState.entity.components and bossState.entity.components.health
            if (not h) or (h.hp or h.current or 0) <= 0 or bossState.entity.dead then
                bossState.entity = nil
            end
        end
    end

    local targetHp = bossState.entity and bossState.hp or 0
    local targetShield = bossState.entity and bossState.shield or 0
    bossState.smoothHp = Util.lerp(bossState.smoothHp or targetHp, targetHp, 1 - math.exp(-8 * dt))
    bossState.smoothShield = Util.lerp(bossState.smoothShield or targetShield, targetShield, 1 - math.exp(-8 * dt))

    if bossState.displayTimer <= 0 and not bossState.entity then
        bossState.label = nil
        bossState.hp = 0
        bossState.shield = 0
        bossState.maxShield = 0
    end
end

local function drawBossBar()
    if bossState.displayTimer <= 0 and not bossState.entity then
        return
    end

    local alpha = 1
    if not bossState.entity then
        alpha = math.max(0, math.min(1, bossState.displayTimer / BOSS_BAR_FADE_TIME))
        if alpha <= 0 then return end
    end

    local sw, sh = Viewport.getDimensions()
    local barWidth = math.min(sw - 160, 360) -- Half the original width (720 -> 360)
    local panelPadding = 14 -- Half the original padding (28 -> 14)
    local barHeight = 12 -- Half the original height (24 -> 12)
    local barCount = (bossState.maxShield or 0) > 0 and 2 or 1
    local panelHeight = barCount * (barHeight + 7) + 28 -- Half the original spacing and padding
    local panelWidth = barWidth + panelPadding * 2
    local panelX = math.floor((sw - panelWidth) * 0.5)
    local panelY = math.max(12, math.floor(sh * 0.02)) -- Much closer to top (0.08 -> 0.02)

    -- Panel background - black with cyan border
    Theme.setColor({0.0, 0.0, 0.0, 0.85 * alpha})
    love.graphics.rectangle('fill', panelX, panelY, panelWidth, panelHeight, 6, 6)
    Theme.setColor({0.5, 0.7, 0.9, 0.8 * alpha})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', panelX, panelY, panelWidth, panelHeight, 6, 6)
    love.graphics.setLineWidth(1)

    local label = bossState.label or "Boss Threat"
    local prevFont = love.graphics.getFont()
    local titleFont = (Theme.fonts and (Theme.fonts.small or Theme.fonts.normal)) or prevFont -- Use smaller font
    if titleFont then love.graphics.setFont(titleFont) end
    local font = love.graphics.getFont()
    local labelWidth = font:getWidth(label)
    local labelHeight = font:getHeight()
    Theme.setColor({1.0, 1.0, 1.0, alpha})
    love.graphics.print(label, panelX + (panelWidth - labelWidth) / 2, panelY + 6) -- Reduced padding
    if prevFont then love.graphics.setFont(prevFont) end

    local barX = panelX + panelPadding
    local barY = panelY + labelHeight + 12 -- Reduced spacing
    local hullPct = (bossState.maxHp or 1) > 0 and math.max(0, math.min(1, (bossState.smoothHp or 0) / bossState.maxHp)) or 0
    local shieldPct = (bossState.maxShield or 0) > 0 and math.max(0, math.min(1, (bossState.smoothShield or 0) / math.max(1, bossState.maxShield))) or 0

    if (bossState.maxShield or 0) > 0 then
        local shieldText = string.format("Shield %d / %d", math.floor(math.max(0, bossState.shield or 0)), math.floor(math.max(0, bossState.maxShield or 0)))
        drawBossMeter(barX, barY, barWidth, barHeight, shieldPct, {0.5, 0.7, 0.9, 1.0}, shieldText, alpha)
        barY = barY + barHeight + 7 -- Half the original spacing (14 -> 7)
    end

    local hullText = string.format("Hull %d / %d", math.floor(math.max(0, bossState.hp or 0)), math.floor(math.max(1, bossState.maxHp or 1)))
    drawBossMeter(barX, barY, barWidth, barHeight, hullPct, {0.9, 0.4, 0.6, 1.0}, hullText, alpha)
end

local function initialize()
    bars = {
        hull = StatusBar.new({ label = "Hull", color = Theme.semantic.statusHull }),
        shield = StatusBar.new({ label = "Shield", color = Theme.semantic.statusShield }),
        energy = StatusBar.new({ label = "Capacitor", color = Theme.semantic.statusCapacitor }),
        xp = StatusBar.new({ label = "XP", color = Theme.semantic.modernStatusXP }),
    }
    initialized = true
end

function HUDStatusBars.update(dt, player, world)
    if not initialized then initialize() end
    if not player or not player.components or not player.components.health then return end

    local h = player.components.health
    bars.hull:setValue(h.hp or 0, h.maxHP or (h.hp or 0))
    bars.shield:setValue(h.shield or 0, h.maxShield or (h.shield or 0))
    bars.energy:setValue(h.energy or 0, h.maxEnergy or (h.energy or 0))
    if player.components.progression then
        bars.xp:setValue(player.components.progression.xp or 0, (player.components.progression.level or 1) * 100)
    end

    -- Update energy animation
    local targetEnergyPct = (h.energy or 0) / math.max(1, h.maxEnergy or h.energy or 1)
    energyAnimation.target = targetEnergyPct
    
    -- Smooth animation with snap-to-target to avoid never reaching 0%/100%
    local animationSpeed = 1.5 -- Lower = slower animation
    local diff = energyAnimation.target - energyAnimation.current
    energyAnimation.current = energyAnimation.current + diff * animationSpeed * dt
    
    -- Snap when very close to target so full/empty shows completely
    if math.abs(energyAnimation.target - energyAnimation.current) < 0.005 then
        energyAnimation.current = energyAnimation.target
    end
    
    -- Clamp to prevent overshoot
    energyAnimation.current = math.max(0, math.min(1, energyAnimation.current))

    for _, bar in pairs(bars) do
        bar:update(dt)
    end

    updateBossBar(dt, player, world)
end

function HUDStatusBars.draw(player, world)
    if not initialized then initialize() end

    local sw, sh = Viewport.getDimensions()
    local s = math.min(sw / 1920, sh / 1080)

    local barWidth = 250
    local barHeight, gap = math.floor(18 * s), math.floor(4 * s)


    -- Hull and Shield at bottom-center
    local centerX = sw / 2
    local hullX = centerX - barWidth - gap
    local shieldX = centerX + gap
    local bottomY = sh - barHeight - 12

    bars.hull:draw(hullX, bottomY, barWidth, barHeight)
    bars.shield:draw(shieldX, bottomY, barWidth, barHeight)

    -- XP bar at the bottom of the screen
    local xpBarHeight = 4
    local xpBarY = sh - xpBarHeight
    bars.xp:draw(0, xpBarY, sw, xpBarHeight)

    drawBossBar()
end

return HUDStatusBars
