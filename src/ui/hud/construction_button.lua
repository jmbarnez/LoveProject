local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")

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

function ConstructionButton.draw()
    if not buttonState.visible then return end
    
    local sw, sh = Viewport.getDimensions()
    local buttonSize = 48
    local margin = 16
    local x = sw - buttonSize - margin
    local y = sh - buttonSize - margin
    
    local mx, my = Viewport.getMousePosition()
    buttonState.hover = UIUtils.pointInRect(mx, my, {
        x = x, y = y, w = buttonSize, h = buttonSize
    })
    
    -- Button background
    local bgColor = buttonState.hover and Theme.colors.bg1 or Theme.colors.bg2
    Theme.setColor(bgColor)
    love.graphics.rectangle('fill', x, y, buttonSize, buttonSize)
    
    -- Button border
    local borderColor = buttonState.active and Theme.colors.accent or Theme.colors.border
    Theme.drawEVEBorder(x, y, buttonSize, buttonSize, 6, borderColor, 2)
    
    -- Construction icon (hammer/wrench symbol)
    local iconSize = 24
    local iconX = x + (buttonSize - iconSize) / 2
    local iconY = y + (buttonSize - iconSize) / 2
    
    Theme.setColor(Theme.colors.text)
    love.graphics.setLineWidth(3)
    
    -- Draw hammer/wrench icon
    local centerX = iconX + iconSize / 2
    local centerY = iconY + iconSize / 2
    
    -- Hammer head
    love.graphics.rectangle('fill', centerX - 8, centerY - 12, 16, 8)
    -- Hammer handle
    love.graphics.rectangle('fill', centerX - 2, centerY - 4, 4, 16)
    -- Wrench head
    love.graphics.rectangle('fill', centerX - 6, centerY + 4, 12, 4)
    love.graphics.rectangle('fill', centerX - 2, centerY + 8, 4, 8)
    
    love.graphics.setLineWidth(1)
    
    buttonState.rect = { x = x, y = y, w = buttonSize, h = buttonSize }
    
    -- Draw construction menu if visible
    if menuState.visible then
        ConstructionButton.drawMenu()
    end
end

function ConstructionButton.drawMenu()
    if not menuState.visible then return end
    
    local sw, sh = Viewport.getDimensions()
    local menuWidth = 280
    local menuHeight = 120
    local x = sw - menuWidth - 16
    local y = sh - menuHeight - 80  -- Above the button
    
    -- Menu background
    Theme.drawGradientGlowRect(x, y, menuWidth, menuHeight, 6,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak * 0.2)
    Theme.drawEVEBorder(x, y, menuWidth, menuHeight, 6, Theme.colors.border, 2)
    
    -- Menu title
    local titleFont = Theme.fonts and Theme.fonts.medium or love.graphics.getFont()
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(titleFont)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.print("Construction", x + 16, y + 16)
    
    -- Draw options
    local optionY = y + 50
    local optionHeight = 50
    local optionSpacing = 8
    
    for i, option in ipairs(menuState.options) do
        local optionX = x + 16
        local optionW = menuWidth - 32
        local optionRect = {
            x = optionX,
            y = optionY + (i - 1) * (optionHeight + optionSpacing),
            w = optionW,
            h = optionHeight
        }
        
        local mx, my = Viewport.getMousePosition()
        local hover = UIUtils.pointInRect(mx, my, optionRect)
        
        -- Option background
        local bgColor = hover and Theme.colors.bg1 or Theme.colors.bg0
        Theme.setColor(bgColor)
        love.graphics.rectangle('fill', optionRect.x, optionRect.y, optionRect.w, optionRect.h)
        
        -- Option border
        Theme.drawEVEBorder(optionRect.x, optionRect.y, optionRect.w, optionRect.h, 4, Theme.colors.border, 1)
        
        -- Option icon
        local iconSize = 32
        local iconX = optionRect.x + 8
        local iconY = optionRect.y + (optionHeight - iconSize) / 2
        
        -- Draw simple turret icon
        Theme.setColor(Theme.colors.accent)
        love.graphics.rectangle('fill', iconX, iconY, iconSize, iconSize)
        Theme.setColor(Theme.colors.text)
        love.graphics.rectangle('line', iconX, iconY, iconSize, iconSize)
        
        -- Option text
        local textFont = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
        love.graphics.setFont(textFont)
        Theme.setColor(Theme.colors.text)
        love.graphics.print(option.name, iconX + iconSize + 8, iconY + 8)
        
        -- Cost display
        local costText = "Cost: "
        local costParts = {}
        for resource, amount in pairs(option.cost) do
            if resource == "energy" then
                table.insert(costParts, string.format("%d Energy", amount))
            else
                table.insert(costParts, string.format("%d %s", amount, resource))
            end
        end
        costText = costText .. table.concat(costParts, ", ")
        
        -- Add build time
        if option.buildTime then
            costText = costText .. " (" .. option.buildTime .. "s)"
        end
        
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print(costText, iconX + iconSize + 8, iconY + 24)
    end
    
    if oldFont then love.graphics.setFont(oldFont) end
    
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
        local optionY = menuState.rect.y + 50
        local optionHeight = 50
        local optionSpacing = 8
        
        for i, option in ipairs(menuState.options) do
            local optionRect = {
                x = menuState.rect.x + 16,
                y = optionY + (i - 1) * (optionHeight + optionSpacing),
                w = menuState.rect.w - 32,
                h = optionHeight
            }
            
            if UIUtils.pointInRect(mx, my, optionRect) then
                ConstructionButton.selectOption(option)
                return true
            end
        end
        
        -- Click outside menu closes it
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
        local ConstructionSystem = require("src.systems.construction")
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
end

return ConstructionButton
