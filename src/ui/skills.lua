local SkillsPanel = {
    x = nil,
    y = nil,
    dragging = false,
    dragDX = 0,
    dragDY = 0,
    closeDown = false,
    visible = false,
    -- Aurora shader for title effect (initialized on first use)
    auroraShader = nil
}

local Skills = require("src.core.skills")
local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local AuroraTitle = require("src.shaders.aurora_title")

local function pointInRect(px, py, r)
    -- Handle nil values gracefully
    if px == nil or py == nil or r == nil or r.x == nil or r.y == nil or r.w == nil or r.h == nil then
        return false
    end
    return px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
end

local function drawSkillBar(x, y, w, h, progress, skillName, level, xp, xpToNext)
    -- Enhanced background
    Theme.drawGradientGlowRect(x, y, w, h, 4,
        Theme.colors.bg2, Theme.colors.bg1,
        Theme.colors.border, Theme.effects.glowWeak * 0.5)

    -- Enhanced progress fill with animation
    if progress > 0 then
        local fillW = w * progress
        local time = love.timer.getTime()
        local shimmerOffset = (time * 50) % (fillW + 20)
        
        Theme.drawGradientGlowRect(x, y, fillW, h, 4,
            Theme.colors.primary, Theme.colors.accent,
            Theme.colors.accent, Theme.effects.glowWeak * 1.2)
        
        -- Shimmer effect
        if fillW > 10 then
            local shimmerX = x + shimmerOffset - 10
            if shimmerX >= x and shimmerX <= x + fillW - 10 then
                Theme.setColor(Theme.withAlpha(Theme.colors.textHighlight, 0.3))
                love.graphics.rectangle("fill", shimmerX, y, 10, h)
            end
        end
    end

    -- Border
    Theme.drawEVEBorder(x, y, w, h, 0, Theme.colors.border, 0)

    -- Text
    local font = love.graphics.getFont()
    local levelText = string.format("%s - Lvl %d", skillName, level)
    local xpText = string.format("%d/%d XP", xp, xpToNext)

    Theme.setColor(Theme.colors.text)
    love.graphics.print(levelText, x + 8, y + 4)

    Theme.setColor(Theme.colors.textSecondary)
    local xpTextWidth = font:getWidth(xpText)
    love.graphics.print(xpText, x + w - xpTextWidth - 8, y + 4 + font:getHeight())


    -- Progress percentage
    local percentValue = math.max(0, math.min(100, progress * 100))
    local percentText = string.format("%.1f%%", percentValue)
    local percentW = font:getWidth(percentText)
    Theme.setColor(Theme.colors.accent)
    love.graphics.print(percentText, x + w - percentW - 8, y + 4)
end

function SkillsPanel.draw()
    if not SkillsPanel.visible then return end

    local sw, sh = Viewport.getDimensions()
    local w, h = 300, 250
    local defaultX = math.floor((sw - w) * 0.5)
    local defaultY = 120
    local x = SkillsPanel.x or defaultX
    local y = SkillsPanel.y or defaultY

    -- Enhanced panel background
    Theme.drawGradientGlowRect(x, y, w, h, 8,
        Theme.colors.bg1, Theme.colors.bg0,
        Theme.colors.accent, Theme.effects.glowWeak)
    Theme.drawEVEBorder(x, y, w, h, 8, Theme.colors.border, 6)

    -- Enhanced title bar with effects
    local titleH = 32
    Theme.drawGradientGlowRect(x, y, w, titleH, 8,
        Theme.colors.bg3, Theme.colors.bg2,
        Theme.colors.accent, Theme.effects.glowWeak * 1.2)
    
    -- Animated accent line
    local time = love.timer.getTime()
    local pulseAlpha = 0.4 + 0.2 * math.sin(time * 2)
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, pulseAlpha))
    love.graphics.rectangle("fill", x, y + titleH - 2, w, 2)
    
    -- Aurora title effect with smaller font
    love.graphics.setFont(Theme.fonts.small)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth("Skills")

    -- Initialize aurora shader if needed
    if not SkillsPanel.auroraShader then
      SkillsPanel.auroraShader = AuroraTitle.new()
    end

    if SkillsPanel.auroraShader then
      SkillsPanel.auroraShader:send("time", love.timer.getTime())
      love.graphics.setShader(SkillsPanel.auroraShader)
      Theme.setColor(1, 1, 1, 1)
      love.graphics.print("Skills", x + 12, y + 8)
      love.graphics.setShader()
    else
      -- Fallback to static aurora-like color
      Theme.setColor({0.4, 0.8, 1.0, 1.0})  -- Cyan aurora color
      love.graphics.print("Skills", x + 12, y + 8)
    end

    love.graphics.setFont(Theme.fonts.normal)

    -- Close button
    local closeRect = { x = x + w - 26, y = y + 2, w = 24, h = 24 }
    local mx, my = Viewport.getMousePosition()
    local closeHover = mx >= closeRect.x and mx <= closeRect.x + closeRect.w and my >= closeRect.y and my <= closeRect.y + closeRect.h
    Theme.drawCloseButton(closeRect, closeHover)
    SkillsPanel.closeRect = closeRect

    -- Title bar rect for dragging
    SkillsPanel.titleRect = { x = x, y = y, w = w, h = 32 }

    -- Content area
    local cx, cy = x + 16, y + 48
    local skills = Skills.getAllSkills()

    -- Draw each skill
    for i, skill in ipairs(skills) do
        local skillY = cy + (i - 1) * 55
        local barW = w - 32
        local barH = 40

        -- Progress bar
        drawSkillBar(cx, skillY, barW, barH, skill.progress, skill.name, skill.level, skill.xp, skill.xpToNext)
    end

    -- Total skills summary at bottom
    local totalLevels = 0
    local totalXp = 0
    for _, skill in ipairs(skills) do
        totalLevels = totalLevels + skill.level
        totalXp = totalXp + skill.totalXp
    end

    local summaryY = y + h - 30
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print(string.format("Total Lvl: %d | Total XP: %d", totalLevels, totalXp), cx, summaryY)
end

function SkillsPanel.mousepressed(x, y, button)
    if not SkillsPanel.visible then return false end

    -- Handle close button
    if SkillsPanel.closeRect and pointInRect(x, y, SkillsPanel.closeRect) then
        SkillsPanel.closeDown = true
        return true, false
    end

    -- Handle dragging on title bar
    if SkillsPanel.titleRect and pointInRect(x, y, SkillsPanel.titleRect) then
        SkillsPanel.dragging = true
        -- Use current panel position (or default) to calculate drag offset
        local sw, sh = Viewport.getDimensions()
        local w, h = 600, 400
        local defaultX = math.floor((sw - w) * 0.5)
        local defaultY = 120
        local curX = SkillsPanel.x or defaultX
        local curY = SkillsPanel.y or defaultY
        SkillsPanel.dragDX = curX - x
        SkillsPanel.dragDY = curY - y
        return true, false
    end

    return false
end

function SkillsPanel.mousereleased(x, y, button)
    local consumed, shouldClose = false, false
    if button == 1 then
        if SkillsPanel.dragging then
            SkillsPanel.dragging = false
            consumed = true
        end
        if SkillsPanel.closeDown then
            if SkillsPanel.closeRect and pointInRect(x, y, SkillsPanel.closeRect) then
                shouldClose = true
                SkillsPanel.visible = false
            end
            SkillsPanel.closeDown = false
            consumed = true
        end
    end
    return consumed, shouldClose
end

function SkillsPanel.mousemoved(x, y, dx, dy)
    if SkillsPanel.dragging then
        SkillsPanel.x = x + (SkillsPanel.dragDX or 0)
        SkillsPanel.y = y + (SkillsPanel.dragDY or 0)
        return true
    end
    return false
end

function SkillsPanel.toggle()
    SkillsPanel.visible = not SkillsPanel.visible
end

function SkillsPanel.isVisible()
    return SkillsPanel.visible
end

return SkillsPanel
