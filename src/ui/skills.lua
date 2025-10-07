local SkillsPanel = {
    visible = false,
    auroraShader = nil
}

local Skills = require("src.core.skills")
local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local AuroraTitle = require("src.shaders.aurora_title")
local Window = require("src.ui.common.window")
local UIUtils = require("src.ui.common.utils")

local function drawSkillBar(x, y, w, h, progress, skillName, level, xp, xpToNext)
    -- Layout with skill name outside progress bar
    local font = Theme.fonts.small
    local skillText = string.format("%s Lv.%d", skillName, level)
    local percentValue = math.max(0, math.min(100, progress * 100))
    local percentText = string.format("%.1f%%", percentValue)
    
    -- Get text metrics
    local skillMetrics = UIUtils.getCachedTextMetrics(skillText, font)
    local percentMetrics = UIUtils.getCachedTextMetrics(percentText, font)
    local skillW = skillMetrics.width
    local percentW = percentMetrics.width
    
    -- Calculate layout - skill name on left, progress bar in middle, percentage on right
    local textPadding = 12
    local barPadding = 8
    local skillX = x + 8
    local barX = x + skillW + textPadding
    local barW = w - skillW - percentW - textPadding * 2 - barPadding * 2
    local barY = y + (h - 8) / 2
    local barH = 8
    local percentX = x + w - percentW - 8
    
    -- Background
    Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.8))
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    
    -- Progress bar background
    Theme.setColor(Theme.withAlpha(Theme.colors.bg2, 0.6))
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)
    
    -- Progress bar fill
    if progress > 0 then
        local fillW = barW * progress
        Theme.setColor(Theme.semantic.modernStatusXP)
        love.graphics.rectangle("fill", barX, barY, fillW, barH, 4, 4)
        
        -- Subtle shimmer effect
        local time = love.timer.getTime()
        local shimmerOffset = (time * 30) % (fillW + 15)
        if fillW > 5 and shimmerOffset >= 0 and shimmerOffset <= fillW - 5 then
            Theme.setColor(Theme.withAlpha(Theme.colors.textHighlight, 0.4))
            love.graphics.rectangle("fill", barX + shimmerOffset, barY, 5, barH, 2, 2)
        end
    end
    
    -- Border
    Theme.setColor(Theme.withAlpha(Theme.colors.border, 0.6))
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    
    -- Skill name and level (outside progress bar)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(skillText, skillX, y + (h - skillMetrics.height) / 2)
    
    -- Progress percentage (on the right)
    Theme.setColor(Theme.colors.accent)
    love.graphics.print(percentText, percentX, y + (h - percentMetrics.height) / 2)
end

function SkillsPanel.init()
    SkillsPanel.window = Window.new({
        title = "Skills",
        width = 600,
        height = 400,
        minWidth = 500,
        minHeight = 300,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        drawContent = SkillsPanel.drawContent,
        onClose = function()
            SkillsPanel.visible = false
            -- Play close sound
            local Sound = require("src.core.sound")
            Sound.triggerEvent('ui_button_click')
        end
    })
end

function SkillsPanel.draw()
    if not SkillsPanel.visible then return end
    if not SkillsPanel.window then SkillsPanel.init() end
    SkillsPanel.window.visible = SkillsPanel.visible
    SkillsPanel.window:draw()
end

function SkillsPanel.drawContent(window, x, y, w, h)
    -- Content area
    local pad = (Theme.ui and Theme.ui.contentPadding) or 16
    local cx, cy = x + pad, y + pad
    local skills = Skills.getAllSkills()

    -- Compact single-column layout
    local barH = 24
    local barSpacing = 4
    local barW = w - pad * 2
    
    -- Draw each skill in a single column
    for i, skill in ipairs(skills) do
        local skillY = cy + (i - 1) * (barH + barSpacing)
        
        -- Only draw if within visible area
        if skillY + barH > y and skillY < y + h then
            drawSkillBar(cx, skillY, barW, barH, skill.progress, skill.name, skill.level, skill.xp, skill.xpToNext)
        end
    end

    -- Compact summary at bottom
    local totalLevels = 0
    local totalXp = 0
    for _, skill in ipairs(skills) do
        totalLevels = totalLevels + skill.level
        totalXp = totalXp + skill.totalXp
    end

    local summaryY = y + h - 20
    local summaryText = string.format("Total: Lv.%d | %d XP", totalLevels, totalXp)
    local font = Theme.fonts.small
    local summaryMetrics = UIUtils.getCachedTextMetrics(summaryText, font)
    local summaryX = x + (w - summaryMetrics.width) / 2
    
    Theme.setColor(Theme.withAlpha(Theme.colors.textHighlight, 0.8))
    love.graphics.print(summaryText, summaryX, summaryY)
end

function SkillsPanel.mousepressed(x, y, button)
    if not SkillsPanel.visible then return false end
    if not SkillsPanel.window then return false end
    local handled = SkillsPanel.window:mousepressed(x, y, button)
    if handled and not SkillsPanel.window.visible then
        SkillsPanel.visible = false
        return true
    end
    return handled
end

function SkillsPanel.mousereleased(x, y, button)
    if not SkillsPanel.visible then return false end
    if not SkillsPanel.window then return false end
    return SkillsPanel.window:mousereleased(x, y, button)
end

function SkillsPanel.mousemoved(x, y, dx, dy)
    if not SkillsPanel.visible then return false end
    if not SkillsPanel.window then return false end
    return SkillsPanel.window:mousemoved(x, y, dx, dy)
end

function SkillsPanel.toggle()
    SkillsPanel.visible = not SkillsPanel.visible
    local ok, UIManager = pcall(require, "src.core.ui_manager")
    if ok and UIManager and UIManager.state and UIManager.state.skills then
        UIManager.state.skills.open = SkillsPanel.visible
    end
end

function SkillsPanel.isVisible()
    return SkillsPanel.visible
end

return SkillsPanel
