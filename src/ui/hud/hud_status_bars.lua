local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")

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
    
    -- Critical energy warning effect
    if energyPct < 0.25 then
        local flash = math.sin(time * 8) * 0.5 + 0.5
        Theme.setColor(Theme.withAlpha(Theme.colors.danger, flash * 0.2))
        love.graphics.circle("fill", centerX, centerY, outerRadius)
    end
    
    -- Energy percentage text in center - REMOVED
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
        local textWidth = font:getWidth(text)
        local textX = x + (w - textWidth) / 2
        local textY = y + (h - font:getHeight()) / 2
        Theme.setColor(Theme.colors.text)
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

local function initialize()
    bars = {
        hull = StatusBar.new({ label = "Hull", color = Theme.semantic.statusHull }),
        shield = StatusBar.new({ label = "Shield", color = Theme.semantic.statusShield }),
        energy = StatusBar.new({ label = "Capacitor", color = Theme.semantic.statusCapacitor }),
        xp = StatusBar.new({ label = "XP", color = Theme.semantic.modernStatusXP }),
    }
    initialized = true
end

function HUDStatusBars.update(dt, player)
    if not initialized then initialize() end
    if not player or not player.components or not player.components.health then return end

    local h = player.components.health
    bars.hull:setValue(h.hp or 0, h.maxHP or (h.hp or 0))
    bars.shield:setValue(h.shield or 0, h.maxShield or (h.shield or 0))
    bars.energy:setValue(h.energy or 0, h.maxEnergy or (h.energy or 0))
    bars.xp:setValue(player.xp or 0, (player.level or 1) * 100)

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
end

function HUDStatusBars.draw(player)
    if not initialized then initialize() end

    local sw, sh = Viewport.getDimensions()
    local s = math.min(sw / 1920, sh / 1080)

    local barWidth = 250
    local barHeight, gap = math.floor(18 * s), math.floor(4 * s)

    -- Circular cyan liquid energy display at top center
    local energySize = 120 * s -- Double the size
    local energyX = (sw - energySize) * 0.5 -- Center horizontally
    local energyY = gap -- Top of screen
    
    -- Use animated energy percentage for smooth filling
    local energyPct = energyAnimation.current
    
    drawLiquidSpiralEnergy(energyX, energyY, energySize, energyPct, love.timer.getTime())
    
    -- Player speed display underneath energy spiral
    if player and player.components and player.components.physics and player.components.physics.body then
        local body = player.components.physics.body
        local speed = math.sqrt(body.vx * body.vx + body.vy * body.vy)
        local speedText = string.format("Speed: %.1f", speed)
        
        local oldFont = love.graphics.getFont()
        if Theme.fonts and Theme.fonts.small then love.graphics.setFont(Theme.fonts.small) end
        
        local font = love.graphics.getFont()
        local textW = font:getWidth(speedText)
        local speedX = (sw - textW) * 0.5 -- Center horizontally
        local speedY = energyY + energySize + gap -- Below energy spiral
        
        Theme.setColor(Theme.colors.text)
        love.graphics.print(speedText, speedX, speedY)
        
        if oldFont then love.graphics.setFont(oldFont) end
    end

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
end

return HUDStatusBars
