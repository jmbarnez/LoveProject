local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")
local ConstructionSystem = require("src.systems.construction")

local ConstructionButton = {}

local buttonState = {
    visible = true,
    rect = nil,
    hover = false,
    active = false
}

local menuState = {
    visible = false,
    rect = nil,
    optionRects = {},
    options = {
        {
            id = "holographic_turret",
            name = "Holographic Turret",
            description = "A holographic defense turret",
            cost = { energy = 50 },
            buildTime = 3,
            icon = "combat_laser"
        }
    }
}

local function getScale()
    if Viewport.getUIScale then
        return Viewport.getUIScale() or 1
    end
    return 1
end

local function drawConstructionGlyph(cx, cy, size, color, emphasized)
    local accent = color or Theme.colors.accent
    local innerScale = emphasized and 1.05 or 1

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(innerScale, innerScale)
    love.graphics.rotate(math.rad(-12))

    local hammerWidth = size * 0.55
    local hammerHeight = size * 0.65
    local handleWidth = math.max(2, size * 0.12)
    local wrenchRadius = size * 0.18

    Theme.setColor(Theme.withAlpha(accent, 0.14))
    love.graphics.rectangle("fill", -hammerWidth * 0.5, -hammerHeight * 0.5, hammerWidth, hammerHeight)

    Theme.setColor(Theme.withAlpha(accent, 0.85))
    love.graphics.setLineWidth(math.max(1, size * 0.06))

    -- Hammer head outline
    love.graphics.rectangle("line", -hammerWidth * 0.5, -hammerHeight * 0.5, hammerWidth, hammerHeight * 0.42)

    -- Hammer handle
    love.graphics.rectangle("fill", -handleWidth * 0.5, -hammerHeight * 0.1, handleWidth, hammerHeight * 0.75)

    -- Wrench ring
    love.graphics.circle("line", wrenchRadius * 1.4, hammerHeight * 0.15, wrenchRadius)
    love.graphics.arc("line", "open", wrenchRadius * 1.4, hammerHeight * 0.15, math.rad(-40), math.rad(80), wrenchRadius)

    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

local function getMenuLayout()
    local scale = getScale()
    local layout = {
        width = math.floor(320 * scale + 0.5),
        padding = math.floor(16 * scale + 0.5),
        headerHeight = math.floor(52 * scale + 0.5),
        optionHeight = math.floor(88 * scale + 0.5),
        optionSpacing = math.floor(12 * scale + 0.5),
        anchorGap = math.floor(14 * scale + 0.5)
    }

    local count = #menuState.options
    local verticalSpacing = count > 0 and (count - 1) * layout.optionSpacing or 0
    layout.height = layout.padding * 2 + layout.headerHeight + count * layout.optionHeight + verticalSpacing

    return layout
end

local function getMenuRect()
    local sw, sh = Viewport.getDimensions()
    local layout = getMenuLayout()
    local anchor = buttonState.rect or {
        x = sw - layout.width - 20,
        y = sh - layout.optionHeight - 20,
        w = layout.optionHeight,
        h = layout.optionHeight
    }

    local x = anchor.x + anchor.w - layout.width
    local y = anchor.y - layout.height - layout.anchorGap

    x = math.max(16, math.min(sw - layout.width - 16, x))

    if y < 16 then
        y = math.min(sh - layout.height - 16, anchor.y + anchor.h + layout.anchorGap)
    end

    return x, y, layout.width, layout.height, layout
end

local resourceColors = {
    energy = Theme.colors.capacitor,
    credits = Theme.colors.accentGold,
    metal = Theme.colors.armor,
    alloy = Theme.colors.hull
}

local function getResourceColor(resource)
    return resourceColors[resource] or Theme.colors.textSecondary
end

local function drawInfoPill(text, x, y, color, font)
    font = font or Theme.getFont("small") -- Use small instead of xsmall for better readability
    local previousFont = love.graphics.getFont()
    Theme.setFont("small")

    local metrics = UIUtils.getCachedTextMetrics(text, font)
    local textWidth = metrics.width
    local textHeight = metrics.height
    local paddingX = 10
    local paddingY = 3
    local pillWidth = textWidth + paddingX * 2
    local pillHeight = textHeight + paddingY * 2

    local fillColor = Theme.withAlpha(color, 0.22)
    Theme.drawGradientGlowRect(
        x,
        y,
        pillWidth,
        pillHeight,
        pillHeight * 0.5,
        fillColor,
        Theme.colors.bg0,
        color,
        Theme.effects.glowWeak * 1.2,
        false
    )

    Theme.setColor(color)
    love.graphics.print(text, x + paddingX, y + paddingY)

    if previousFont then love.graphics.setFont(previousFont) end
    return pillWidth, pillHeight
end

local function drawMenuOption(option, rect, hovered, active)
    local accent = Theme.colors.accent
    local topColor = active and Theme.withAlpha(accent, 0.28) or Theme.colors.bg2
    local bottomColor = hovered and Theme.withAlpha(accent, 0.12) or Theme.colors.bg1
    local glow = Theme.effects.glowWeak

    if hovered then
        glow = Theme.effects.glowMedium
    end
    if active then
        glow = Theme.effects.glowStrong
    end

    Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 6, topColor, bottomColor, accent, glow, false)
    Theme.drawEVEBorder(rect.x, rect.y, rect.w, rect.h, 6, Theme.colors.border, 1)

    if active then
        Theme.setColor(Theme.withAlpha(accent, 0.9))
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4)
        love.graphics.setLineWidth(1)
    end

    local iconSize = rect.h - 28
    local iconX = rect.x + 16
    local iconY = rect.y + (rect.h - iconSize) * 0.5

    Theme.drawGradientGlowRect(
        iconX,
        iconY,
        iconSize,
        iconSize,
        6,
        Theme.colors.bg2,
        Theme.colors.bg0,
        Theme.colors.border,
        Theme.effects.glowWeak,
        false
    )

    drawConstructionGlyph(iconX + iconSize * 0.5, iconY + iconSize * 0.5, iconSize * 0.75, accent, hovered or active)

    local textX = iconX + iconSize + 16
    local textWidth = rect.w - (textX - rect.x) - 16
    local previousFont = love.graphics.getFont()

    Theme.setFont("medium")
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.printf(option.name or "", textX, rect.y + 10, textWidth, "left")

    if option.description and option.description ~= "" then
        Theme.setFont("small")
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.printf(option.description, textX, rect.y + 36, textWidth, "left")
    end

    local pillFont = Theme.getFont("small")
    local pillY = rect.y + rect.h - (pillFont:getHeight() + 12)
    local pillX = textX

    local costEntries = {}
    if option.cost then
        for resource, amount in pairs(option.cost) do
            costEntries[#costEntries + 1] = { resource = resource, amount = amount }
        end
        table.sort(costEntries, function(a, b)
            return a.resource < b.resource
        end)
    end

    for _, entry in ipairs(costEntries) do
        local label = string.format("%d %s", entry.amount, entry.resource:gsub("^%l", string.upper))
        local color = getResourceColor(entry.resource)
        local pillWidth = drawInfoPill(label, pillX, pillY, color, pillFont)
        pillX = pillX + pillWidth + 8
    end

    if option.buildTime then
        local buildLabel = string.format("%ss Build", option.buildTime)
        drawInfoPill(buildLabel, pillX, pillY, Theme.colors.info, pillFont)
    end

    if previousFont then love.graphics.setFont(previousFont) end
end

function ConstructionButton.draw()
    if not buttonState.visible then return end

    local sw, sh = Viewport.getDimensions()
    local scale = getScale()
    local buttonSize = math.floor(54 * scale + 0.5)
    local margin = math.floor(20 * scale + 0.5)
    local x = sw - buttonSize - margin
    local y = sh - buttonSize - margin

    local mx, my = Viewport.getMousePosition()
    buttonState.hover = UIUtils.pointInRect(mx, my, {
        x = x, y = y, w = buttonSize, h = buttonSize
    })

    local accent = Theme.colors.accent
    local topColor = buttonState.active and Theme.withAlpha(accent, 0.35) or Theme.colors.bg2
    local bottomColor = buttonState.hover and Theme.withAlpha(accent, 0.16) or Theme.colors.bg1
    local glow = buttonState.active and Theme.effects.glowStrong or (buttonState.hover and Theme.effects.glowMedium or Theme.effects.glowWeak)

    Theme.drawGradientGlowRect(x, y, buttonSize, buttonSize, 8, topColor, bottomColor, accent, glow, false)
    Theme.drawEVEBorder(x, y, buttonSize, buttonSize, 8, Theme.colors.border, 2)

    if buttonState.active then
        Theme.setColor(Theme.withAlpha(accent, 0.75))
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 3, y + 3, buttonSize - 6, buttonSize - 6)
        love.graphics.setLineWidth(1)
    end

    drawConstructionGlyph(x + buttonSize * 0.5, y + buttonSize * 0.5, buttonSize * 0.6, accent, buttonState.hover or buttonState.active)

    buttonState.rect = { x = x, y = y, w = buttonSize, h = buttonSize }

    -- Draw construction menu if visible
    if menuState.visible then
        ConstructionButton.drawMenu()
    end
end

function ConstructionButton.drawMenu()
    if not menuState.visible then return end

    local x, y, menuWidth, menuHeight, layout = getMenuRect()

    Theme.drawGradientGlowRect(
        x,
        y,
        menuWidth,
        menuHeight,
        8,
        Theme.colors.bg2,
        Theme.colors.bg1,
        Theme.colors.accent,
        Theme.effects.glowWeak * 0.6,
        false
    )
    Theme.drawEVEBorder(x, y, menuWidth, menuHeight, 8, Theme.colors.border, 2)

    local previousFont = love.graphics.getFont()
    Theme.setFont("medium")
    local titleFont = Theme.getFont("medium")
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print("Construction", x + layout.padding, y + layout.padding)

    Theme.setColor(Theme.withAlpha(Theme.colors.accent, 0.4))
    love.graphics.rectangle(
        "fill",
        x + layout.padding,
        y + layout.padding + titleFont:getHeight() + 6,
        menuWidth - layout.padding * 2,
        1
    )

    local optionY = y + layout.padding + layout.headerHeight
    local mx, my = Viewport.getMousePosition()
    menuState.optionRects = menuState.optionRects or {}

    for index, option in ipairs(menuState.options) do
        local optionRect = {
            x = x + layout.padding,
            y = optionY + (index - 1) * (layout.optionHeight + layout.optionSpacing),
            w = menuWidth - layout.padding * 2,
            h = layout.optionHeight
        }

        menuState.optionRects[index] = optionRect

        local hovered = UIUtils.pointInRect(mx, my, optionRect)
        local active = ConstructionSystem.isInConstructionMode() and ConstructionSystem.getSelectedItem() == option.id
        drawMenuOption(option, optionRect, hovered, active)
    end

    for i = #menuState.options + 1, #menuState.optionRects do
        menuState.optionRects[i] = nil
    end

    if previousFont then love.graphics.setFont(previousFont) end

    menuState.rect = { x = x, y = y, w = menuWidth, h = menuHeight }
end

function ConstructionButton.mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Check construction button click
    if buttonState.rect and UIUtils.pointInRect(mx, my, buttonState.rect) then
        menuState.visible = not menuState.visible
        buttonState.active = menuState.visible
        return true
    end
    
    -- Check menu option clicks
    if menuState.visible and menuState.rect then
        if menuState.optionRects then
            for index, optionRect in ipairs(menuState.optionRects) do
                if optionRect and UIUtils.pointInRect(mx, my, optionRect) then
                    local option = menuState.options[index]
                    if option then
                        ConstructionButton.selectOption(option)
                        return true
                    end
                end
            end
        end

        if not UIUtils.pointInRect(mx, my, menuState.rect) then
            menuState.visible = false
            buttonState.active = false
            return true
        end
    end

    return false
end

function ConstructionButton.selectOption(option)
    if option.id == "holographic_turret" then
        ConstructionSystem.startConstruction("holographic_turret")
        print("Started holographic turret construction")
        menuState.visible = false
        buttonState.active = false
    end
end

function ConstructionButton.isMenuVisible()
    return menuState.visible
end

function ConstructionButton.closeMenu()
    menuState.visible = false
    buttonState.active = false
    -- Play close sound
    local Sound = require("src.core.sound")
    Sound.triggerEvent('ui_button_click')
end

return ConstructionButton
