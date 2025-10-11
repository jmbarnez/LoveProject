local InteractionSystem = {}

local DEFAULT_INTERACT_RANGE = 50
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 32
local BUTTON_OFFSET_Y = 50
local GC_REWARD_CARDS = 5
local ITEM_REWARD_CARDS = 5

local REWARD_ITEM_POOL = {
  "ore_tritanium",
  "ore_palladium",
  "scraps",
  -- reward_crate_key removed - only obtainable from MILA
}

local function getCargo(player)
  if not player or not player.components then
    return nil
  end
  return player.components.cargo
end

local function hasRequiredKey(player, requiredKey)
  if not requiredKey then
    return true
  end

  local cargo = getCargo(player)
  return cargo and cargo:has(requiredKey, 1) or false
end

local function notifyWarning(message)
  local Notifications = require("src.ui.notifications")
  Notifications.add(message, "warning")
end

local function collectNearbyInteractables(world)
  if not world or not world.get_entities_with_components then
    return {}
  end

  return world:get_entities_with_components("interactable") or {}
end

local function buildRewardDeck()
  local possibleRewards = {}

  for _ = 1, GC_REWARD_CARDS do
    table.insert(possibleRewards, {
      gc = 0,
      item = "gc",
      qty = math.random(150, 400),
    })
  end

  for _ = 1, ITEM_REWARD_CARDS do
    local rewardItem = REWARD_ITEM_POOL[math.random(1, #REWARD_ITEM_POOL)]
    local rewardQty = math.random(3, 12)

    table.insert(possibleRewards, {
      gc = 0,
      item = rewardItem,
      qty = rewardQty,
    })
  end

  return possibleRewards
end

function InteractionSystem.update(_, player, world)
  if not player then
    return
  end

  player._nearbyInteractable = nil

  if not world then
    return
  end

  local playerPos = player.components and player.components.position
  if not playerPos then
    return
  end

  local px, py = playerPos.x, playerPos.y
  local closestObject = nil
  local closestDistanceSq = math.huge

  for _, obj in ipairs(collectNearbyInteractables(world)) do
    local components = obj.components
    local objPos = components and components.position
    local interactable = components and components.interactable

    if objPos and interactable then
      local dx = objPos.x - px
      local dy = objPos.y - py
      local distanceSq = dx * dx + dy * dy
      local range = interactable.range or DEFAULT_INTERACT_RANGE
      local rangeSq = range * range

      if distanceSq <= rangeSq and distanceSq < closestDistanceSq then
        closestObject = obj
        closestDistanceSq = distanceSq
      end
    end
  end

  player._nearbyInteractable = closestObject
end

function InteractionSystem.interact(player)
  if not player then
    return false
  end

  local obj = player._nearbyInteractable
  if not obj then
    return false
  end

  local components = obj.components
  if not components then
    return false
  end

  local interactable = components.interactable
  if not interactable then
    return false
  end

  if not hasRequiredKey(player, interactable.requiresKey) then
    local keyName = interactable.requiresKey or "key"
    notifyWarning("You need a " .. keyName .. " to interact with this object.")
    return false
  end

  local renderable = components.renderable
  if renderable and renderable.type == "reward_crate" then
    local cargo = getCargo(player)
    if not cargo then
      return false
    end

    if not cargo:has("reward_crate_key", 1) then
      notifyWarning("You need a Reward Key to open this crate.")
      return false
    end

    local RewardWheelPanel = require("src.ui.reward_wheel_panel")
    RewardWheelPanel.show(player, buildRewardDeck())

    cargo:remove("reward_crate_key", 1)
    return true
  end

  return false
end

function InteractionSystem.mousepressed(x, y, button, player, camera)
  if button ~= 1 then
    return false
  end

  local obj = player and player._nearbyInteractable
  local components = obj and obj.components
  local interactable = components and components.interactable
  local position = components and components.position

  if not interactable or not position or not camera then
    return false
  end

  local screenX, screenY = camera:worldToScreen(position.x, position.y)
  local buttonX = screenX - BUTTON_WIDTH / 2
  local buttonY = screenY - BUTTON_OFFSET_Y

  if x < buttonX or x > buttonX + BUTTON_WIDTH or y < buttonY or y > buttonY + BUTTON_HEIGHT then
    return false
  end

  if hasRequiredKey(player, interactable.requiresKey) then
    return InteractionSystem.interact(player)
  end

  local keyName = interactable.requiresKey or "key"
  notifyWarning("You need a " .. keyName .. " to interact with this object.")
  return true
end

function InteractionSystem.draw(player, camera)
  local obj = player and player._nearbyInteractable
  local components = obj and obj.components
  local interactable = components and components.interactable
  local position = components and components.position

  if not interactable or not position or not camera then
    return
  end

  local Theme = require("src.core.theme")
  local screenX, screenY = camera:worldToScreen(position.x, position.y)
  local font = (Theme.fonts and Theme.fonts.small) or love.graphics.getFont()
  local colors = Theme.colors or {}

  local hasKey = hasRequiredKey(player, interactable.requiresKey)
  local buttonText = "Open Crate"
  local buttonFill = colors.button or {0.2, 0.6, 0.2, 1.0}

  if interactable.requiresKey and not hasKey then
    buttonText = "Need Reward Key"
    buttonFill = colors.buttonDisabled or {0.6, 0.2, 0.2, 1.0}
  end

  local buttonX = screenX - BUTTON_WIDTH / 2
  local buttonY = screenY - BUTTON_OFFSET_Y

  Theme.setColor(buttonFill)
  love.graphics.rectangle("fill", buttonX, buttonY, BUTTON_WIDTH, BUTTON_HEIGHT, 4, 4)

  Theme.setColor(colors.border or {1, 1, 1, 1})
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", buttonX, buttonY, BUTTON_WIDTH, BUTTON_HEIGHT, 4, 4)

  Theme.setColor(colors.text or {1, 1, 1, 1})
  love.graphics.setFont(font)
  local textWidth = font:getWidth(buttonText)
  local textHeight = font:getHeight()
  love.graphics.print(buttonText, buttonX + (BUTTON_WIDTH - textWidth) / 2, buttonY + (BUTTON_HEIGHT - textHeight) / 2)

  if not hasKey and interactable.requiresKey then
    local reqText = "Requires: " .. (interactable.requiresKey or "key")
    local reqTextWidth = font:getWidth(reqText)
    local reqTextHeight = font:getHeight()
    local reqX = screenX - reqTextWidth / 2
    local reqY = buttonY + BUTTON_HEIGHT + 5

    Theme.setColor({0, 0, 0, 0.7})
    love.graphics.rectangle("fill", reqX - 4, reqY - 2, reqTextWidth + 8, reqTextHeight + 4, 2, 2)

    Theme.setColor(colors.textDisabled or {0.7, 0.7, 0.7, 1.0})
    love.graphics.print(reqText, reqX, reqY)
  end
end

return InteractionSystem
