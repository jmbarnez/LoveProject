local Theme = require("src.core.theme")
local Notifications = require("src.ui.notifications")
local Dropdown = require("src.ui.common.dropdown")
local Shop = require("src.ui.docked.shop")

local ShopView = {}

function ShopView.init(state)
    state.categoryDropdown = Dropdown.new({
        x = 0,
        y = 0,
        width = 150,
        optionHeight = 24,
        options = { "All", "Weapons", "Consumables", "Materials" },
        selectedIndex = 1,
        onSelect = function(_, option)
            state.selectedCategory = option
        end
    })
end

function ShopView.draw(state, x, y, w, h, player, mx, my)
    if not state.categoryDropdown then return end

    local searchWidth = 150
    local searchX = x + w - searchWidth
    local dropdownX = x

    state.categoryDropdown:setPosition(dropdownX, y)
    state.categoryDropdown:drawButtonOnly(mx, my)

    local searchIsActive = state.searchActive
    Theme.drawGradientGlowRect(searchX, y, searchWidth, 28, 3,
        Theme.colors.bg0, Theme.colors.bg1,
        searchIsActive and Theme.colors.accent or Theme.colors.border,
        Theme.effects.glowWeak)

    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    if state.searchText == "" and not searchIsActive then
        Theme.setColor(Theme.colors.textDisabled)
        love.graphics.print("Search...", searchX + 6, y + 8)
    else
        Theme.setColor(Theme.colors.text)
        love.graphics.print(state.searchText, searchX + 6, y + 8)
    end

    if searchIsActive and math.fmod(love.timer.getTime(), 1) > 0.5 then
        local textW = love.graphics.getFont():getWidth(state.searchText)
        love.graphics.rectangle("fill", searchX + 6 + textW, y + 4, 2, 20)
    end

    state._searchBar = { x = searchX, y = y, w = searchWidth, h = 28 }

    local contentY = y + 28 + 8
    local contentH = h - 28 - 8
    ShopView.drawContent(state, x, contentY, w, contentH, player)
end

function ShopView.drawContent(state, x, y, w, h, player)
    if not player then return end

    Theme.setColor(Theme.colors.text)
    love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
    love.graphics.print("Shop Items", x, y)

    local shopY = y + 20
    local shopH = h - 20
    ShopView.drawShopItems(state, x, shopY, w, shopH, player)
end

function ShopView.drawShopItems(state, x, y, w, h, player)
    state.shopScroll = 0
    return Shop.drawShopItems(state, x, y, w, h, player)
end

function ShopView.drawBuybackItems(state, x, y, w, h, player)
    return Shop.drawBuybackItems(state, x, y, w, h, player)
end

function ShopView.drawPlayerInventory(state, x, y, w, h, player)
    return Shop.drawPlayerInventoryForSale(state, x, y, w, h, player)
end

local function notify(message)
    if Notifications and Notifications.action then
        Notifications.action(message)
    end
end

function ShopView.purchaseItem(state, item, player, quantity)
    quantity = quantity or 1
    if not player or not item or quantity <= 0 then return false end

    local totalCost = item.price * quantity
    if player:getGC() < totalCost then return false end

    player:spendGC(totalCost)

    local itemId = item.id
    local itemName = item.name

    if player.components and player.components.cargo then
        player.components.cargo:add(itemId, quantity)
    end

    local Inventory = require("src.ui.inventory")
    if Inventory.refresh then Inventory.refresh() end

    local notificationText = quantity > 1 and ("Purchased " .. itemName .. " x" .. quantity) or ("Purchased " .. itemName)
    notify(notificationText)

    return true
end

function ShopView.sellItem(state, item, player, quantity)
    quantity = quantity or 1
    if not player or not item or quantity <= 0 then return false end

    local cargo = player.components and player.components.cargo
    if not cargo or not cargo:has(item.id, quantity) then
        return false
    end

    cargo:remove(item.id, quantity)
    player:addGC(item.price * quantity)

    local notificationText = quantity > 1 and ("Sold " .. item.name .. " x" .. quantity) or ("Sold " .. item.name)
    notify(notificationText)

    table.insert(state.buybackItems, 1, {
        id = item.id,
        price = item.price,
        def = item.def,
        name = item.name,
    })

    if #state.buybackItems > 10 then
        table.remove(state.buybackItems)
    end

    return true
end

function ShopView.drawContextMenu(state, mx, my)
    Shop.drawContextMenu(state, mx, my)
end

function ShopView.hideContextMenu(state)
    Shop.hideContextMenu(state)
end

function ShopView.mousepressed(state, x, y, button, player)
    return Shop.mousepressed(state, x, y, button, player)
end

function ShopView.keypressed(state, key, scancode, isrepeat, player)
    return Shop.keypressed(state, key, scancode, isrepeat, player)
end

function ShopView.textinput(state, text, player)
    return Shop.textinput(state, text, player)
end

return ShopView
