local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Items = require("src.ui.cargo.items")
local Actions = require("src.ui.cargo.actions")

local ContextMenu = {}

local MENU_WIDTH = 180
local OPTION_HEIGHT = 24

function ContextMenu.hide(state)
    state.contextMenu.visible = false
end

function ContextMenu.showForItem(state, item, index, screenX, screenY)
    local def = Items.getItemDefinition(item)
    if not def then return false end

    local menu = state.contextMenu
    menu.visible = true
    menu.x = screenX
    menu.y = screenY
    menu.item = item
    menu.index = index
    menu.options = {}

    if def.consumable or def.type == "consumable" then
        menu.options[#menu.options + 1] = { name = "Use", action = "use" }
    end

    menu.options[#menu.options + 1] = { name = "Drop", action = "drop" }

    if #menu.options == 0 then
        menu.visible = false
        return false
    end

    return true
end

local function executeOption(action, player, item)
    if not item then return false end
    if action == "use" then
        return Actions.useItem(player, item.id)
    elseif action == "drop" then
        return Actions.dropItem(player, item.id)
    end
    return false
end

function ContextMenu.handleMousePress(state, mx, my, button, player)
    local menu = state.contextMenu
    if not menu.visible then return false end

    if button ~= 1 and button ~= 2 then
        return false
    end

    local h = 8 + (#menu.options * OPTION_HEIGHT) + 8

    for index, option in ipairs(menu.options) do
        local optionY = menu.y + 8 + (index - 1) * OPTION_HEIGHT
        if mx >= menu.x and mx <= menu.x + MENU_WIDTH and my >= optionY and my <= optionY + OPTION_HEIGHT then
            executeOption(option.action, player, menu.item)
            menu.visible = false
            return true
        end
    end

    menu.visible = false
    return true
end

function ContextMenu.draw(state)
    local menu = state.contextMenu
    if not menu.visible then return end

    local x, y = menu.x, menu.y
    local w = MENU_WIDTH
    local h = 8 + (#menu.options * OPTION_HEIGHT) + 8

    local screenW, screenH = Viewport.getDimensions()
    if x + w > screenW then x = screenW - w end
    if y + h > screenH then y = screenH - h end

    Theme.drawGradientGlowRect(x, y, w, h, 6, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local mx, my = Viewport.getMousePosition()
    Theme.setFont("small")
    for index, option in ipairs(menu.options) do
        local optionY = y + 8 + (index - 1) * OPTION_HEIGHT
        local hover = mx >= x and mx <= x + w and my >= optionY and my <= optionY + OPTION_HEIGHT
        if hover then
            Theme.setColor(Theme.colors.bg3)
            love.graphics.rectangle("fill", x + 4, optionY, w - 8, OPTION_HEIGHT)
        end
        Theme.setColor(hover and Theme.colors.textHighlight or Theme.colors.text)
        love.graphics.print(option.name, x + 12, optionY + (OPTION_HEIGHT - 12) * 0.5)
    end
end

return ContextMenu
