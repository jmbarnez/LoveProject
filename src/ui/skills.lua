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
    local font = Theme.fonts.small
    local levelText = string.format("%s - Lvl %d", skillName, level)

    Theme.setColor(Theme.colors.text)
    love.graphics.print(levelText, x + 8, y + 4)

    -- Modern progress bar
    local barY = y + h - 18
    Theme.drawModernBar(x + 8, barY, w - 16, 10, progress, Theme.semantic.modernStatusXP)

    -- Progress percentage
    local percentValue = math.max(0, math.min(100, progress * 100))
    local percentText = string.format("%.1f%%", percentValue)
    local percentMetrics = UIUtils.getCachedTextMetrics(percentText, font)
    local percentW = percentMetrics.width
    Theme.setColor(Theme.colors.accent)
    love.graphics.print(percentText, x + w - percentW - 8, y + 4)
end

function SkillsPanel.init()
    SkillsPanel.window = Window.new({
        title = "Skills",
        width = 900,
        height = 750,
        minWidth = 750,
        minHeight = 600,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        drawContent = SkillsPanel.drawContent,
        onClose = function()
            SkillsPanel.visible = false
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

    -- Draw each skill
    local numColumns = 3
    local columnWidth = (w - pad * (numColumns + 1)) / numColumns
    local barH = 40
    for i, skill in ipairs(skills) do
        local col = (i - 1) % numColumns
        local row = math.floor((i - 1) / numColumns)
        local skillX = cx + col * (columnWidth + pad)
        local skillY = cy + row * (barH + 15)

        -- Progress bar
        drawSkillBar(skillX, skillY, columnWidth, barH, skill.progress, skill.name, skill.level, skill.xp, skill.xpToNext)
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
