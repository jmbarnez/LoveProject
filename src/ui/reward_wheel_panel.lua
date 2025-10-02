local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Window = require("src.ui.common.window")
local Notifications = require("src.ui.notifications")
local Content = require("src.content.content")

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
    
    -- Give GC reward
    if reward.gc and reward.gc > 0 then
        player:addGC(reward.gc)
    end
    
    -- Give item reward
    if reward.item and reward.qty and reward.qty > 0 then
        local cargo = player.components.cargo
        if cargo then
            local added = player:addItem(reward.item, reward.qty)
            if not added then
                -- Drop as pickup if inventory full
                local ItemPickup = require("src.entities.item_pickup")
                local px, py = player.components.position.x, player.components.position.y
                local pickup = ItemPickup.new(px, py, reward.item, reward.qty)
                if pickup then
                    local world = getWorld()
                    if world then
                        world:addEntity(pickup)
                    end
                end
            end
        end
    end
    
    -- Show notification
    local rewardText = ""
    if reward.gc and reward.gc > 0 then
        rewardText = rewardText .. "+" .. reward.gc .. " GC"
    end
    if reward.item and reward.qty and reward.qty > 0 then
        local itemName = reward.item:gsub("_", " "):gsub("^%l", string.upper)
        if rewardText ~= "" then
            rewardText = rewardText .. ", "
        end
        rewardText = rewardText .. reward.qty .. "x " .. itemName
    end
    
    Notifications.add("Reward: " .. rewardText, "success")
end

-- Helper function to get reward type color
local function getRewardTypeColor(reward)
    if reward.gc and reward.gc > 0 and reward.item and reward.qty and reward.qty > 0 then
        return {0.8, 0.6, 0.2, 1.0} -- Gold for mixed rewards
    elseif reward.gc and reward.gc > 0 then
        return {0.2, 0.8, 0.2, 1.0} -- Green for GC only
    elseif reward.item and reward.qty and reward.qty > 0 then
        return {0.2, 0.4, 0.8, 1.0} -- Blue for items only
    else
        return {0.5, 0.5, 0.5, 1.0} -- Gray for unknown
    end
end

function RewardWheelPanel.drawContent(self, x, y, w, h)
    local centerX = x + w * 0.5
    local centerY = y + h * 0.5
    
    -- Draw background
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Draw title
    love.graphics.setFont(Theme.fonts.large)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("🎁 REWARD SELECTOR 🎁", x + 20, y + 20, w - 40, "center")
    
    -- Draw side cards (smaller, dimmed)
    local sideCardWidth = 70
    local sideCardHeight = 100
    local centerCardWidth = 160
    local centerCardHeight = 200
    local cardSpacing = 8
    
    -- Draw left side cards
    for i = 1, math.min(3, #RewardWheelPanel.rewards) do
        local cardX = x + 20 + (i - 1) * (sideCardWidth + cardSpacing)
        local cardY = centerY - sideCardHeight * 0.5
        
        local reward = RewardWheelPanel.rewards[i]
        local cardColor = getRewardTypeColor(reward)
        
        -- Dimmed background
        Theme.setColor(cardColor[1] * 0.3, cardColor[2] * 0.3, cardColor[3] * 0.3, 0.6)
        love.graphics.rectangle("fill", cardX, cardY, sideCardWidth, sideCardHeight, 6, 6)
        
        -- Border
        Theme.setColor(cardColor[1] * 0.6, cardColor[2] * 0.6, cardColor[3] * 0.6, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cardX, cardY, sideCardWidth, sideCardHeight, 6, 6)
        
        -- Type indicator
        love.graphics.setFont(Theme.fonts.small)
        Theme.setColor(Theme.colors.textSecondary)
        if reward.gc and reward.gc > 0 then
            love.graphics.printf("💰", cardX + 2, cardY + 8, sideCardWidth - 4, "center")
        elseif reward.item and reward.qty and reward.qty > 0 then
            love.graphics.printf("📦", cardX + 2, cardY + 8, sideCardWidth - 4, "center")
        end
    end
    
    -- Draw right side cards
    for i = math.max(1, #RewardWheelPanel.rewards - 2), #RewardWheelPanel.rewards do
        if i > 3 then -- Skip if already drawn on left
            local cardX = x + w - 20 - sideCardWidth - ((#RewardWheelPanel.rewards - i) * (sideCardWidth + cardSpacing))
            local cardY = centerY - sideCardHeight * 0.5
            
            local reward = RewardWheelPanel.rewards[i]
            local cardColor = getRewardTypeColor(reward)
            
            -- Dimmed background
            Theme.setColor(cardColor[1] * 0.3, cardColor[2] * 0.3, cardColor[3] * 0.3, 0.6)
            love.graphics.rectangle("fill", cardX, cardY, sideCardWidth, sideCardHeight, 6, 6)
            
            -- Border
            Theme.setColor(cardColor[1] * 0.6, cardColor[2] * 0.6, cardColor[3] * 0.6, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cardX, cardY, sideCardWidth, sideCardHeight, 6, 6)
            
            -- Type indicator
            love.graphics.setFont(Theme.fonts.small)
            Theme.setColor(Theme.colors.textSecondary)
            if reward.gc and reward.gc > 0 then
                love.graphics.printf("💰", cardX + 2, cardY + 8, sideCardWidth - 4, "center")
            elseif reward.item and reward.qty and reward.qty > 0 then
                love.graphics.printf("📦", cardX + 2, cardY + 8, sideCardWidth - 4, "center")
            end
        end
    end
    
    -- Draw center card (the main one)
    local centerCardX = centerX - centerCardWidth * 0.5
    local centerCardY = centerY - centerCardHeight * 0.5
    
    if RewardWheelPanel.currentCardIndex and RewardWheelPanel.rewards[RewardWheelPanel.currentCardIndex] then
        local reward = RewardWheelPanel.rewards[RewardWheelPanel.currentCardIndex]
        local cardColor = getRewardTypeColor(reward)
        
        -- Glow effect
        Theme.setColor(cardColor[1], cardColor[2], cardColor[3], 0.3)
        love.graphics.rectangle("fill", centerCardX - 8, centerCardY - 8, centerCardWidth + 16, centerCardHeight + 16, 12, 12)
        
        -- Main card background
        Theme.setColor(cardColor[1], cardColor[2], cardColor[3], 1.0)
        love.graphics.rectangle("fill", centerCardX, centerCardY, centerCardWidth, centerCardHeight, 10, 10)
        
        -- Card border
        Theme.setColor(Theme.colors.border)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", centerCardX, centerCardY, centerCardWidth, centerCardHeight, 10, 10)
        
        -- Card content
        love.graphics.setFont(Theme.fonts.small)
        Theme.setColor(Theme.colors.text)
        
        local rewardText = ""
        if reward.gc and reward.gc > 0 then
            rewardText = rewardText .. "💰\n" .. reward.gc .. " GC"
        end
        if reward.item and reward.qty and reward.qty > 0 then
            local itemName = reward.item:gsub("_", " "):gsub("^%l", string.upper)
            -- Truncate long item names
            if #itemName > 12 then
                itemName = itemName:sub(1, 9) .. "..."
            end
            if rewardText ~= "" then
                rewardText = rewardText .. "\n\n"
            end
            rewardText = rewardText .. "📦\n" .. reward.qty .. "x " .. itemName
        end
        
        -- Calculate text area within card
        local textX = centerCardX + 12
        local textY = centerCardY + 50
        local textWidth = centerCardWidth - 24
        local textHeight = centerCardHeight - 80
        
        love.graphics.printf(rewardText, textX, textY, textWidth, "center")
    end
    
    -- Draw status and controls
    love.graphics.setFont(Theme.fonts.medium)
    Theme.setColor(Theme.colors.text)
    
    if RewardWheelPanel.scrolling then
        local dots = string.rep(".", math.floor((love.timer.getTime() * 4) % 4))
        love.graphics.printf("Selecting reward" .. dots, x + 20, y + h - 80, w - 40, "center")
    elseif RewardWheelPanel.showingResult then
        Theme.setColor(Theme.colors.accent)
        love.graphics.printf("🎉 You won this reward! 🎉", x + 20, y + h - 80, w - 40, "center")
        
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
