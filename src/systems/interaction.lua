local InteractionSystem = {}

local function getPlayer()
  local PlayerRef = require("src.core.player_ref")
  return PlayerRef.get()
end

local function getWorld()
  local Game = require("src.game")
  return Game.world
end

function InteractionSystem.update(dt, player, world)
  if not player or not world then return end
  
  local playerPos = player.components.position
  if not playerPos then return end
  
  local px, py = playerPos.x, playerPos.y
  
  -- Find nearby interactable objects
  local nearbyObjects = world:get_entities_with_components("interactable")
  local closestObject = nil
  local closestDistance = math.huge
  
  for _, obj in ipairs(nearbyObjects) do
    if obj.components.position and obj.components.interactable then
      local objPos = obj.components.position
      local dx = objPos.x - px
      local dy = objPos.y - py
      local distance = math.sqrt(dx * dx + dy * dy)
      
      if distance <= (obj.components.interactable.range or 50) and distance < closestDistance then
        closestObject = obj
        closestDistance = distance
      end
    end
  end
  
  
  -- Store the closest object for rendering
  player._nearbyInteractable = closestObject
end

function InteractionSystem.interact(player)
  if not player or not player._nearbyInteractable then return false end
  
  local obj = player._nearbyInteractable
  local interactable = obj.components.interactable
  
  if not interactable then return false end
  
  -- Check if object requires a key
  if interactable.requiresKey then
    local cargo = player.components.cargo
    if not cargo or not cargo:has(interactable.requiresKey, 1) then
      local Notifications = require("src.ui.notifications")
      Notifications.add("You need a " .. (interactable.requiresKey or "key") .. " to interact with this object.", "warning")
      return false
    end
  end
  
  -- Handle reward crate interaction (world object)
  if obj.components.renderable and obj.components.renderable.type == "reward_crate" then
    local cargo = player.components.cargo
    if not cargo then return false end
    
    -- Check for reward key
    if not cargo:has("reward_crate_key", 1) then
      local Notifications = require("src.ui.notifications")
      Notifications.add("You need a Reward Key to open this crate.", "warning")
      return false
    end
    
    -- Generate multiple possible rewards for the wheel
    local possibleRewards = {}
    
    -- Add GC-only rewards (half the cards) - now as items
    for i = 1, 5 do
      table.insert(possibleRewards, {
        gc = 0,
        item = "gc",
        qty = math.random(150, 400)
      })
    end
    
    -- Add item-only rewards (half the cards)
    local rewardItems = {
      "ore_tritanium", "ore_palladium", "stones", "scraps", "reward_crate_key"
    }
    for i = 1, 5 do
      local rewardItem = rewardItems[math.random(1, #rewardItems)]
      local rewardQty = math.random(3, 12)
      table.insert(possibleRewards, {
        gc = 0,
        item = rewardItem,
        qty = rewardQty
      })
    end
    
    -- Show reward wheel panel
    local RewardWheelPanel = require("src.ui.reward_wheel_panel")
    RewardWheelPanel.show(player, possibleRewards)
    
    -- Consume the key
    cargo:remove("reward_crate_key", 1)
    
    return true
  end
  
  return false
end


function InteractionSystem.mousepressed(x, y, button, player, camera)
  if not player or not player._nearbyInteractable or button ~= 1 then return false end
  
  local obj = player._nearbyInteractable
  local interactable = obj.components.interactable
  
  if not interactable then return false end
  
  local Viewport = require("src.core.viewport")
  local screenX, screenY = camera:worldToScreen(obj.components.position.x, obj.components.position.y)
  
  -- Check if click is on the button
  local buttonWidth = 120
  local buttonHeight = 32
  local buttonX = screenX - buttonWidth/2
  local buttonY = screenY - 50
  
  if x >= buttonX and x <= buttonX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
    -- Check if player has the required key
    local hasKey = true
    if interactable.requiresKey then
      local cargo = player.components.cargo
      hasKey = cargo and cargo:has(interactable.requiresKey, 1)
    end
    
    if hasKey then
      return InteractionSystem.interact(player)
    else
      -- Show warning message
      local Notifications = require("src.ui.notifications")
      local keyName = interactable.requiresKey or "key"
      Notifications.add("You need a " .. keyName .. " to open this crate.", "warning")
      return true
    end
  end
  
  return false
end

function InteractionSystem.draw(player, camera)
  if not player or not player._nearbyInteractable then return end
  
  local obj = player._nearbyInteractable
  local interactable = obj.components.interactable
  
  if not interactable then return end
  
  local Viewport = require("src.core.viewport")
  local Theme = require("src.core.theme")
  
  local screenX, screenY = camera:worldToScreen(obj.components.position.x, obj.components.position.y)
  local font = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
  local padding = 8
  
  -- Check if player has the required key
  local hasKey = true
  local buttonText = "Open Crate"
  local buttonColor = Theme.colors.button or {0.2, 0.6, 0.2, 1.0}
  
  if interactable.requiresKey then
    local cargo = player.components.cargo
    hasKey = cargo and cargo:has(interactable.requiresKey, 1)
    
    if not hasKey then
      buttonText = "Need Reward Key"
      buttonColor = Theme.colors.buttonDisabled or {0.6, 0.2, 0.2, 1.0}
    end
  end
  
  -- Draw button
  local buttonWidth = 120
  local buttonHeight = 32
  local buttonX = screenX - buttonWidth/2
  local buttonY = screenY - 50
  
  -- Button background
  Theme.setColor(buttonColor)
  love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 4, 4)
  
  -- Button border
  Theme.setColor(Theme.colors.border)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 4, 4)
  
  -- Button text
  Theme.setColor(Theme.colors.text)
  love.graphics.setFont(font)
  local textWidth = font:getWidth(buttonText)
  local textHeight = font:getHeight()
  local textX = buttonX + (buttonWidth - textWidth) / 2
  local textY = buttonY + (buttonHeight - textHeight) / 2
  love.graphics.print(buttonText, textX, textY)
  
  -- Show requirements if no key
  if not hasKey and interactable.requiresKey then
    local reqText = "Requires: " .. (interactable.requiresKey or "key")
    local reqTextWidth = font:getWidth(reqText)
    local reqTextHeight = font:getHeight()
    local reqX = screenX - reqTextWidth/2
    local reqY = buttonY + buttonHeight + 5
    
    -- Requirements background
    Theme.setColor({0, 0, 0, 0.7})
    love.graphics.rectangle("fill", reqX - 4, reqY - 2, reqTextWidth + 8, reqTextHeight + 4, 2, 2)
    
    -- Requirements text
    Theme.setColor(Theme.colors.textDisabled or {0.7, 0.7, 0.7, 1.0})
    love.graphics.print(reqText, reqX, reqY)
  end
end

return InteractionSystem
