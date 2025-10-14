local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Window = require("src.ui.common.window")
local Notifications = require("src.ui.notifications")
local Content = require("src.content.content")
local Game = require("src.game")

local RewardWheelPanel = {}
RewardWheelPanel.__index = RewardWheelPanel

RewardWheelPanel.visible = false
RewardWheelPanel.window = nil
RewardWheelPanel.scrolling = false
RewardWheelPanel.scrollStartTime = 0
RewardWheelPanel.scrollDuration = 2.0
RewardWheelPanel.selectedReward = nil
RewardWheelPanel.rewards = {}
RewardWheelPanel.player = nil
RewardWheelPanel.currentCardIndex = 1
RewardWheelPanel.cardScrollTime = 0.15
RewardWheelPanel.finalRewardIndex = 1
RewardWheelPanel.showingResult = false
RewardWheelPanel.claimButton = nil

function RewardWheelPanel.init()
    RewardWheelPanel.window = Window.new({
        title = "Reward Crate",
        width = 500,
        height = 400,
        minWidth = 400,
        minHeight = 350,
        useLoadPanelTheme = true,
        bottomBarHeight = 60,
        draggable = true,
        resizable = false,
        closable = false, -- Remove close button
        drawContent = RewardWheelPanel.drawContent,
        onClose = function()
            RewardWheelPanel.visible = false
        end
    })
end

function RewardWheelPanel.show(player, rewards)
    RewardWheelPanel.player = player
    RewardWheelPanel.rewards = rewards
    RewardWheelPanel.scrolling = true
    RewardWheelPanel.scrollStartTime = love.timer.getTime()
    RewardWheelPanel.selectedReward = nil
    RewardWheelPanel.currentCardIndex = 1
    RewardWheelPanel.finalRewardIndex = math.random(1, #rewards)
    RewardWheelPanel.showingResult = false
    RewardWheelPanel.visible = true
    RewardWheelPanel.window.visible = true
end

function RewardWheelPanel.hide()
    RewardWheelPanel.visible = false
    if RewardWheelPanel.window then
        RewardWheelPanel.window.visible = false
    end
end

function RewardWheelPanel.update(dt)
    if not RewardWheelPanel.visible then return end
    
    if RewardWheelPanel.scrolling then
        local currentTime = love.timer.getTime()
        local elapsed = currentTime - RewardWheelPanel.scrollStartTime
        local progress = math.min(elapsed / RewardWheelPanel.scrollDuration, 1.0)
        
        -- Calculate which card should be showing based on time
        local totalCards = #RewardWheelPanel.rewards
        local cardIndex = math.floor(elapsed / RewardWheelPanel.cardScrollTime) + 1
        
        if cardIndex > totalCards then
            cardIndex = ((cardIndex - 1) % totalCards) + 1
        end
        
        RewardWheelPanel.currentCardIndex = cardIndex
        
        if progress >= 1.0 then
            -- Scrolling finished - show final reward
            RewardWheelPanel.scrolling = false
            RewardWheelPanel.currentCardIndex = RewardWheelPanel.finalRewardIndex
            RewardWheelPanel.selectedReward = RewardWheelPanel.rewards[RewardWheelPanel.finalRewardIndex]
            RewardWheelPanel.showingResult = true
        end
    end
end

function RewardWheelPanel.claimReward()
    if not RewardWheelPanel.showingResult or not RewardWheelPanel.selectedReward then return end
    
    -- Give rewards to player
    RewardWheelPanel.giveRewards()
    
    -- Close panel
    RewardWheelPanel.hide()
end

function RewardWheelPanel.mousepressed(x, y, button)
    if not RewardWheelPanel.visible or not RewardWheelPanel.showingResult or button ~= 1 then return false end
    
        -- Check if claim button was clicked using standard button system
        if RewardWheelPanel.claimButton then
            local Viewport = require("src.core.viewport")
            local mx, my = Viewport.getMousePosition()
            local clicked = Theme.handleButtonClick(RewardWheelPanel.claimButton, mx, my)
            
            if clicked then
                RewardWheelPanel.claimReward()
                return true
            end
        end
    
    return false
end

function RewardWheelPanel.giveRewards()
    if not RewardWheelPanel.player or not RewardWheelPanel.selectedReward then return end
    
    local player = RewardWheelPanel.player
    local reward = RewardWheelPanel.selectedReward
    
    -- Give item reward (including GC as an item)
    if reward.item and reward.qty and reward.qty > 0 then
        if reward.item == "gc" then
            -- Handle GC as currency
            player:addGC(reward.qty)
        else
            -- Handle regular items
        local cargo = player.components.cargo
        if cargo then
            local added = player:addItem(reward.item, reward.qty)
            if not added then
                -- Drop as pickup if cargo hold is full
                local ItemPickup = require("src.entities.item_pickup")
                local px, py = player.components.position.x, player.components.position.y
                local pickup = ItemPickup.new(px, py, reward.item, reward.qty)
                if pickup then
                    local world = Game.world
                    if world then
                        world:addEntity(pickup)
                        end
                    end
                end
            end
        end
    end
    
    -- Show notification
    local rewardText = ""
    if reward.item and reward.qty and reward.qty > 0 then
        if reward.item == "gc" then
            rewardText = "+" .. reward.qty .. " GC"
        else
        local itemName = reward.item:gsub("_", " "):gsub("^%l", string.upper)
            rewardText = "+" .. reward.qty .. "x " .. itemName
        end
    end
    
    Notifications.add("Reward: " .. rewardText, "success")
end

-- Helper function to get reward type color with more vibrant colors
local function getRewardTypeColor(reward)
    if reward.item and reward.qty and reward.qty > 0 then
        -- Different colors based on item type
        local itemName = reward.item:lower()
        if itemName == "gc" then
            return {0.2, 1.0, 0.4, 1.0} -- Bright green for GC
        elseif itemName:find("ore") or itemName:find("mineral") then
            return {0.8, 0.4, 0.2, 1.0} -- Orange for ores/minerals
        elseif itemName:find("scrap") or itemName:find("junk") then
            return {0.6, 0.6, 0.6, 1.0} -- Silver for scrap
        elseif itemName:find("module") or itemName:find("shield") then
            return {0.2, 0.6, 1.0, 1.0} -- Cyan for modules
        elseif itemName:find("key") or itemName:find("crate") then
            return {0.8, 0.2, 0.8, 1.0} -- Purple for keys/crates
        else
            return {0.2, 0.4, 0.8, 1.0} -- Blue for other items
        end
    else
        return {0.5, 0.5, 0.5, 1.0} -- Gray for unknown
    end
end

function RewardWheelPanel.drawContent(self, x, y, w, h)
    local centerX = x + w * 0.5
    local centerY = y + h * 0.5
    
    -- Skip background drawing to let cards show through
    
    -- Draw title
    love.graphics.setFont(Theme.fonts.large)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("🎁 REWARD SELECTOR 🎁", x + 20, y + 20, w - 40, "center")
    
    -- Draw side cards (smaller, dimmed)
    local sideCardWidth = 80
    local sideCardHeight = 100
    local centerCardWidth = 160
    local centerCardHeight = 200
    local cardSpacing = 10
    
    -- Draw left side cards
    for i = 1, math.min(5, #RewardWheelPanel.rewards) do
        local cardX = x + 20 + (i - 1) * (sideCardWidth + cardSpacing)
        local cardY = centerY - sideCardHeight * 0.5
        
        local reward = RewardWheelPanel.rewards[i]
        local cardColor = getRewardTypeColor(reward)
        
        -- Black background
        love.graphics.setColor(0.0, 0.0, 0.0, 1.0) -- Pure black
        love.graphics.rectangle("fill", cardX, cardY, sideCardWidth, sideCardHeight, 8, 8)
        
        -- Colored border
        Theme.setColor(cardColor[1], cardColor[2], cardColor[3], 1.0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", cardX, cardY, sideCardWidth, sideCardHeight, 8, 8)
        
        -- Draw item icon or GC symbol
        local iconSize = 32
        local iconX = cardX + (sideCardWidth - iconSize) * 0.5
        local iconY = cardY + 12
        
        if reward.item and reward.qty and reward.qty > 0 then
            -- Draw item icon with safer fallback
            local success, item = pcall(function() return Content.getItem(reward.item) end)
            if success and item and item.icon and type(item.icon) == "userdata" then
                love.graphics.setColor(0.9, 0.9, 0.9, 0.9) -- Light gray instead of white
                love.graphics.draw(item.icon, iconX, iconY, 0, iconSize / 128, iconSize / 128)
            else
                -- Fallback to emoji
                love.graphics.setFont(Theme.fonts.large)
                Theme.setColor(0.9, 0.9, 0.9, 0.9) -- Light gray instead of white
                love.graphics.printf("📦", iconX - 8, iconY - 8, iconSize + 16, "center")
            end
        end
        
        -- Draw amount underneath
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0) -- White text for visibility
        local amountText = ""
        if reward.item and reward.qty and reward.qty > 0 then
            amountText = tostring(reward.qty) .. "x"
        end
        love.graphics.printf(amountText, cardX + 2, iconY + iconSize + 4, sideCardWidth - 4, "center")
    end
    
    -- Draw right side cards
    local rightCardStart = 6
    for i = rightCardStart, #RewardWheelPanel.rewards do
        local rightIndex = i - rightCardStart + 1
        local cardX = x + w - 20 - (rightIndex * (sideCardWidth + cardSpacing))
            local cardY = centerY - sideCardHeight * 0.5
            
            local reward = RewardWheelPanel.rewards[i]
            local cardColor = getRewardTypeColor(reward)
            
        -- Black background
        love.graphics.setColor(0.0, 0.0, 0.0, 1.0) -- Pure black
        love.graphics.rectangle("fill", cardX, cardY, sideCardWidth, sideCardHeight, 8, 8)
        
        -- Colored border
        Theme.setColor(cardColor[1], cardColor[2], cardColor[3], 1.0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", cardX, cardY, sideCardWidth, sideCardHeight, 8, 8)
        
        -- Draw item icon or GC symbol
        local iconSize = 32
        local iconX = cardX + (sideCardWidth - iconSize) * 0.5
        local iconY = cardY + 12
        
            if reward.gc and reward.gc > 0 then
            -- Draw GC icon
            Theme.drawCurrencyToken(iconX, iconY, iconSize)
            elseif reward.item and reward.qty and reward.qty > 0 then
            -- Draw item icon with safer fallback
            local success, item = pcall(function() return Content.getItem(reward.item) end)
            if success and item and item.icon and type(item.icon) == "userdata" then
                love.graphics.setColor(0.9, 0.9, 0.9, 0.9) -- Light gray instead of white
                love.graphics.draw(item.icon, iconX, iconY, 0, iconSize / 128, iconSize / 128)
            else
                -- Fallback to emoji
                love.graphics.setFont(Theme.fonts.large)
                Theme.setColor(0.9, 0.9, 0.9, 0.9) -- Light gray instead of white
                love.graphics.printf("📦", iconX - 8, iconY - 8, iconSize + 16, "center")
            end
        end
        
        -- Draw amount underneath
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0) -- White text for visibility
        local amountText = ""
        if reward.item and reward.qty and reward.qty > 0 then
            amountText = tostring(reward.qty) .. "x"
        end
        love.graphics.printf(amountText, cardX + 2, iconY + iconSize + 4, sideCardWidth - 4, "center")
    end
    
    -- Draw center card (the main one) - positioned between left and right cards
    local centerCardX = centerX - centerCardWidth * 0.5
    local centerCardY = centerY - centerCardHeight * 0.5
    
    if RewardWheelPanel.currentCardIndex and RewardWheelPanel.rewards[RewardWheelPanel.currentCardIndex] then
        local reward = RewardWheelPanel.rewards[RewardWheelPanel.currentCardIndex]
        local cardColor = getRewardTypeColor(reward)
        
        -- Subtle glow effect
        Theme.setColor(cardColor[1], cardColor[2], cardColor[3], 0.2)
        love.graphics.rectangle("fill", centerCardX - 6, centerCardY - 6, centerCardWidth + 12, centerCardHeight + 12, 14, 14)
        
        -- Black background
        love.graphics.setColor(0.0, 0.0, 0.0, 1.0) -- Pure black
        love.graphics.rectangle("fill", centerCardX, centerCardY, centerCardWidth, centerCardHeight, 12, 12)
        
        -- Colored border
        Theme.setColor(cardColor[1], cardColor[2], cardColor[3], 1.0)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", centerCardX, centerCardY, centerCardWidth, centerCardHeight, 12, 12)
        
        -- Draw large item icon or GC symbol
        local iconSize = 80
        local iconX = centerCardX + (centerCardWidth - iconSize) * 0.5
        local iconY = centerCardY + 20
        
        if reward.item and reward.qty and reward.qty > 0 then
            -- Draw large item icon
            local item = Content.getItem(reward.item)
            if item and item.icon then
                love.graphics.setColor(1, 1, 1, 1.0)
                love.graphics.draw(item.icon, iconX, iconY, 0, iconSize / 128, iconSize / 128)
            else
                -- Fallback to emoji
                love.graphics.setFont(Theme.fonts.large)
                Theme.setColor(0.9, 0.9, 0.9, 1.0) -- Light gray instead of white
                love.graphics.printf("📦", iconX - 20, iconY - 20, iconSize + 40, "center")
            end
        end
        
        -- Draw amount underneath icon
        love.graphics.setFont(Theme.fonts.medium)
        Theme.setColor(0.9, 0.9, 0.9, 1.0) -- Light gray instead of white
        local amountText = ""
        if reward.item and reward.qty and reward.qty > 0 then
            if reward.item == "gc" then
                amountText = tostring(reward.qty) .. " GC"
            else
                amountText = tostring(reward.qty) .. "x"
            end
        end
        love.graphics.printf(amountText, centerCardX + 12, iconY + iconSize + 8, centerCardWidth - 24, "center")
        
    end
    
    -- Draw claim button when showing result
    if RewardWheelPanel.showingResult then
        -- Draw claim button using standard button system
        local buttonWidth = 120
        local buttonHeight = 40
        local buttonX = centerX - buttonWidth * 0.5
        local buttonY = y + h - 50
        
        -- Create button object for click handling
        RewardWheelPanel.claimButton = {_rect = {x = buttonX, y = buttonY, w = buttonWidth, h = buttonHeight}}
        
        -- Get hover state
        local Viewport = require("src.core.viewport")
        local mx, my = Viewport.getMousePosition()
        local hover = Theme.handleButtonClick(RewardWheelPanel.claimButton, mx, my)
        
        -- Draw styled button
        Theme.drawStyledButton(buttonX, buttonY, buttonWidth, buttonHeight, "CLAIM", hover, love.timer.getTime())
    end
end

return RewardWheelPanel
