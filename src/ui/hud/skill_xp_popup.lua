local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")
local Events = require("src.core.events")

local SkillXpPopup = {
    visible = false,
    alpha = 0,
    timer = 0,
    holdDuration = 2.75,
    fadeDuration = 1.0,
    scale = 0,
    slideY = 0,
    state = {
        skillName = "",
        level = 1,
        maxLevel = 1,
        progress = 0,
        xpInLevel = 0,
        xpToNext = 0,
        xpGained = 0,
        leveledUp = false
    }
}

local subscribed = false

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function subscribe()
    if subscribed then
        return
    end

    if Events and Events.on and Events.GAME_EVENTS and Events.GAME_EVENTS.SKILL_XP_GAINED then
        Events.on(Events.GAME_EVENTS.SKILL_XP_GAINED, function(payload)
            SkillXpPopup.onXpGain(payload)
        end)
        subscribed = true
    end
end

function SkillXpPopup.resubscribe()
    subscribed = false
    subscribe()
end

function SkillXpPopup.onXpGain(payload)
    if not payload then return end

    SkillXpPopup.state.skillName = payload.skillName or payload.skillId or "Unknown Skill"
    SkillXpPopup.state.level = payload.level or 1
    SkillXpPopup.state.maxLevel = payload.maxLevel or SkillXpPopup.state.level
    SkillXpPopup.state.progress = clamp01(payload.progress or 0)
    SkillXpPopup.state.xpInLevel = payload.xpInLevel or 0
    SkillXpPopup.state.xpToNext = payload.xpToNext or 0
    SkillXpPopup.state.xpGained = payload.xpGained or 0
    SkillXpPopup.state.leveledUp = payload.leveledUp or false

    SkillXpPopup.visible = true
    SkillXpPopup.alpha = 1
    SkillXpPopup.scale = 0
    SkillXpPopup.slideY = -20
    SkillXpPopup.timer = 0
end

function SkillXpPopup.update(dt)
    if SkillXpPopup.visible then
        SkillXpPopup.timer = SkillXpPopup.timer + dt

        -- Animation phases
        local totalDuration = SkillXpPopup.holdDuration + SkillXpPopup.fadeDuration
        local animTime = SkillXpPopup.timer

        -- Scale and slide in animation (first 0.3 seconds)
        if animTime <= 0.3 then
            local t = animTime / 0.3
            SkillXpPopup.scale = 1 - math.pow(1 - t, 3) -- Ease out cubic
            SkillXpPopup.slideY = -20 * (1 - t) -- Slide from above
        else
            SkillXpPopup.scale = 1
            SkillXpPopup.slideY = 0
        end

        -- Hold phase
        if animTime <= SkillXpPopup.holdDuration then
            SkillXpPopup.alpha = 1
        else
            -- Fade out phase
            local fadeTime = animTime - SkillXpPopup.holdDuration
            if SkillXpPopup.fadeDuration > 0 then
                SkillXpPopup.alpha = math.max(0, 1 - (fadeTime / SkillXpPopup.fadeDuration))
            else
                SkillXpPopup.alpha = 0
            end

            if SkillXpPopup.alpha <= 0 then
                SkillXpPopup.visible = false
                SkillXpPopup.alpha = 0
                SkillXpPopup.scale = 0
                SkillXpPopup.slideY = 0
            end
        end
    end
end

local function formatXp(value)
    if math.abs(value - math.floor(value + 0.5)) < 0.05 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%.1f", value)
end

local function drawProgressBar(x, y, w, h, progress, alpha)
    local bgColor = Theme.withAlpha(Theme.colors.bg0, 0.65 * alpha)
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    if progress > 0 then
        local fillW = math.floor(w * progress)
        Theme.setColor(Theme.withAlpha(Theme.semantic.modernStatusXP, alpha))
        love.graphics.rectangle("fill", x, y, fillW, h, 4, 4)
    end

    Theme.setColor(Theme.withAlpha(Theme.colors.borderBright, alpha))
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
end

function SkillXpPopup.draw()
    if not SkillXpPopup.visible or SkillXpPopup.alpha <= 0 then
        return
    end

    local sw, sh = Viewport.getDimensions()

    local width = math.min(320, sw - 32)
    local height = 72
    local margin = 16
    local x = sw - width - margin
    local y = 36

    local alpha = SkillXpPopup.alpha
    local scale = SkillXpPopup.scale

    -- Apply scaling and positioning
    love.graphics.push()
    love.graphics.translate(x + width * 0.5, y + height * 0.5)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-width * 0.5, -height * 0.5)

    local bgTop = Theme.withAlpha(Theme.colors.bg2, 0.9 * alpha)
    local bgBottom = Theme.withAlpha(Theme.colors.bg1, 0.9 * alpha)
    local glow = Theme.withAlpha(Theme.colors.accent, 0.4 * alpha)

    Theme.drawGradientGlowRect(0, 0, width, height, 4, bgTop, bgBottom, glow, Theme.effects.glowWeak * alpha)
    Theme.drawEVEBorder(0, 0, width, height, 4, Theme.withAlpha(Theme.colors.borderBright, alpha), 2)

    local oldFont = love.graphics.getFont()
    if Theme.fonts and Theme.fonts.medium then
        love.graphics.setFont(Theme.fonts.medium)
    end

    local title = SkillXpPopup.state.skillName .. " — Lvl " .. SkillXpPopup.state.level
    local titleColor = SkillXpPopup.state.leveledUp and Theme.colors.success or Theme.colors.text
    Theme.setColor(Theme.withAlpha(titleColor, alpha))
    love.graphics.print(title, 16, 12)

    local xpGainText = string.format("+%s XP", formatXp(SkillXpPopup.state.xpGained))
    if Theme.fonts and Theme.fonts.small then
        love.graphics.setFont(Theme.fonts.small)
    end

    local xpGainMetrics = UIUtils.getCachedTextMetrics(xpGainText, love.graphics.getFont())
    Theme.setColor(Theme.withAlpha(Theme.colors.accent, alpha))
    love.graphics.print(xpGainText, width - xpGainMetrics.width - 16, 14)

    local barX = x + 14
    local barY = y + height - 28
    local barW = width - 28
    local barH = 12

    drawProgressBar(barX, barY, barW, barH, SkillXpPopup.state.progress, alpha)

    local infoText
    if SkillXpPopup.state.maxLevel and SkillXpPopup.state.level >= SkillXpPopup.state.maxLevel and SkillXpPopup.state.xpToNext <= 0 then
        infoText = "Max level reached"
    elseif SkillXpPopup.state.xpToNext > 0 then
        local xpInLevel = formatXp(SkillXpPopup.state.xpInLevel)
        local xpToNext = formatXp(SkillXpPopup.state.xpToNext)
        local percent = string.format("%.1f%%", SkillXpPopup.state.progress * 100)
        infoText = string.format("%s / %s XP (%s)", xpInLevel, xpToNext, percent)
    else
        infoText = string.format("Total XP: %s", formatXp(SkillXpPopup.state.xpInLevel))
    end

    Theme.setColor(Theme.withAlpha(Theme.colors.textSecondary or Theme.colors.text, alpha))
    love.graphics.print(infoText, barX, barY + barH + 4)

    if oldFont then
        love.graphics.setFont(oldFont)
    end

    love.graphics.pop()
end

subscribe()

return SkillXpPopup
