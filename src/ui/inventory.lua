local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Content = require("src.content.content")
local Input = require("src.core.input")
local Util = require("src.core.util")
local Tooltip = require("src.ui.tooltip")

local Inventory = {}

-- State
Inventory.visible = false
Inventory.windowW = nil
Inventory.windowH = nil
Inventory.windowX = nil
Inventory.windowY = nil
Inventory.dragging = false
Inventory.dragDX = 0
Inventory.dragDY = 0
Inventory._closeButton = nil
Inventory.hoveredItem = nil
Inventory.hoverTimer = 0
Inventory.drag = nil -- { from='inventory', id=string }

-- Defaults
local DEFAULT_W = 520
local DEFAULT_H = 360

function Inventory.init()
  local sw, sh = Viewport.getDimensions()
  Inventory.windowW = Input.getInventoryW and Input.getInventoryW() or DEFAULT_W
  Inventory.windowH = Input.getInventoryH and Input.getInventoryH() or DEFAULT_H
  Inventory.windowX = Input.getInventoryX and Input.getInventoryX() or math.floor((sw - Inventory.windowW) * 0.5)
  Inventory.windowY = Input.getInventoryY and Input.getInventoryY() or math.floor((sh - Inventory.windowH) * 0.5)
  if Input.setInventoryPos then Input.setInventoryPos(Inventory.windowX, Inventory.windowY) end
  if Input.setInventorySize then Input.setInventorySize(Inventory.windowW, Inventory.windowH) end
end

function Inventory.getRect()
  return { x = Inventory.windowX, y = Inventory.windowY, w = Inventory.windowW, h = Inventory.windowH }
end

function Inventory.draw(player)
  if not Inventory.visible or not player then return end

  local x, y, w, h = Inventory.windowX, Inventory.windowY, Inventory.windowW, Inventory.windowH

  -- Window
  Theme.drawGradientGlowRect(x, y, w, h, 8,
    Theme.colors.bg1, Theme.colors.bg0,
    Theme.colors.accent, Theme.effects.glowWeak)
  Theme.drawEVEBorder(x, y, w, h, 8, Theme.colors.border, 6)

  -- Title bar
  local titleH = 24
  Theme.drawGradientGlowRect(x, y, w, titleH, 8,
    Theme.colors.bg3, Theme.colors.bg2,
    Theme.colors.accent, Theme.effects.glowWeak)
  
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  local font = love.graphics.getFont()
  local textWidth = font:getWidth("Cargo")
  local textHeight = font:getHeight()
  love.graphics.print("Cargo", x + (w - textWidth) / 2, y + (titleH - textHeight) / 2)
  love.graphics.setFont(Theme.fonts and Theme.fonts.normal or love.graphics.getFont())

  -- Close button
  local closeSize = 20
  local closeX = x + w - 22
  local closeY = y + 2
  Inventory._closeButton = { x = closeX, y = closeY, w = closeSize, h = closeSize }
  local mx, my = Viewport.getMousePosition()
  local closeHover = mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize
  Theme.drawCloseButton(Inventory._closeButton, closeHover)

  -- Grid layout
  local slotSize = 72
  local padding = 8
  local startY = y + titleH + 8
  local contentW = w - 16
  local cols = math.floor(contentW / (slotSize + padding))
  if cols < 1 then cols = 1 end
  local startX = x + (w - cols * (slotSize + padding) + padding) / 2

  local items = {}
  if player and player.inventory then
    for id, qty in pairs(player.inventory) do
      table.insert(items, { id = id, qty = qty })
    end
  end

  -- Sort by name
  table.sort(items, function(a,b)
    local an = (Content.getItem(a.id) and Content.getItem(a.id).name) or (Content.getTurret(a.id) and Content.getTurret(a.id).name) or a.id
    local bn = (Content.getItem(b.id) and Content.getItem(b.id).name) or (Content.getTurret(b.id) and Content.getTurret(b.id).name) or b.id
    return an < bn
  end)

  love.graphics.push()
  love.graphics.setScissor(x, y + titleH, w, h - titleH)

  Inventory._slotRects = {}
  for i, it in ipairs(items) do
    local index = i - 1
    local row = math.floor(index / cols)
    local col = index % cols
    local sx = startX + col * (slotSize + padding)
    local sy = startY + row * (slotSize + padding)
    local dx = math.floor(sx + 0.5)
    local dy = math.floor(sy + 0.5)

    -- Slot background
    Theme.drawGradientGlowRect(dx, dy, slotSize, slotSize, 4,
      Theme.colors.bg1, Theme.colors.bg0, Theme.colors.border, Theme.effects.glowWeak)

    -- Get item definition
    local def = Content.getItem(it.id) or Content.getTurret(it.id)
    local name = (def and def.name) or it.id
    local value = (def and def.value) or 0

    -- Icon
    if def and def.icon and type(def.icon) == "userdata" then
      Theme.setColor({1,1,1,1})
      local scale = math.min((slotSize - 8) / def.icon:getWidth(), (slotSize - 8) / def.icon:getHeight())
      love.graphics.draw(def.icon, dx + 4, dy + 4, 0, scale, scale)
    else
      Theme.setColor(Theme.colors.text)
      love.graphics.printf(name, dx + 4, dy + slotSize/2 - 7, slotSize - 8, "center")
    end

    -- Name
    Theme.setColor(Theme.colors.text)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.printf(name, dx, dy + slotSize - 20, slotSize, "center")

    -- Quantity
    Theme.setColor(Theme.colors.accent)
    love.graphics.setFont(Theme.fonts and Theme.fonts.small or love.graphics.getFont())
    love.graphics.printf(Util.formatNumber(it.qty), dx, dy + 2, slotSize - 4, "right")

  Inventory._slotRects[i] = { x = dx, y = dy, w = slotSize, h = slotSize, id = it.id }

    -- Check for hover
    if mx >= dx and mx <= dx + slotSize and my >= dy and my <= dy + slotSize then
      if Inventory.hoveredItem and Inventory.hoveredItem.id == it.id then
        Inventory.hoverTimer = Inventory.hoverTimer + love.timer.getDelta()
      else
        Inventory.hoveredItem = { id = it.id, def = def }
        Inventory.hoverTimer = 0
      end
    end
  end

  love.graphics.setScissor()
  love.graphics.pop()

  -- Draw bottom bar
  local barH = 24
  local barY = y + h - barH
  Theme.drawGradientGlowRect(x, barY, w, barH, 8, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak)

  -- GC balance
  local gcBalance = player:getGC()
  local gcText = Util.formatNumber(gcBalance)
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  local textWidth = font:getWidth(gcText)
  local textHeight = font:getHeight()
  local padding = 8
  local startX = x + padding
  local startY = barY + (barH - textHeight) / 2
  Theme.setColor(Theme.colors.accentGold)
  love.graphics.print(gcText, startX, startY)
  Theme.drawCurrencyToken(startX + textWidth + 4, barY + (barH - 16) / 2, 16)

  -- Item count
  local itemCount = 0
  if player.inventory then
    for _, _ in pairs(player.inventory) do
      itemCount = itemCount + 1
    end
  end
  local itemText = itemCount .. " items"
  love.graphics.setFont(Theme.fonts and Theme.fonts.medium or love.graphics.getFont())
  local itemTextWidth = font:getWidth(itemText)
  startX = x + w - itemTextWidth - padding
  Theme.setColor(Theme.colors.textSecondary)
  love.graphics.print(itemText, startX, startY)

  -- Draw dragged item ghost (if dragging from inventory)
  if Inventory.drag then
    local UI = require("src.core.ui")
    local mx, my = Viewport.getMousePosition()
    local id = Inventory.drag.id
    local tdef = Content.getTurret(id)
    if tdef and UI and UI.drawTurretIcon then
      local drawSize = 52
      local dx = mx - drawSize / 2
      local dy = my - drawSize / 2
      Theme.setColor({1,1,1,0.9})
      UI.drawTurretIcon(tdef.type or tdef.kind or "gun", (tdef.tracer and tdef.tracer.color), dx + 4, dy + 4, drawSize - 8)
    end
  end

end

function Inventory.mousepressed(x, y, button, player)
  print("Inventory.mousepressed called:", x, y, button, "visible:", Inventory.visible)
  if not Inventory.visible then return false end

  -- Debug slot rectangles
  print("Inventory: _slotRects exists:", Inventory._slotRects and "yes" or "no")
  if Inventory._slotRects then
    print("Inventory: Number of slot rects:", #Inventory._slotRects)
    for i, slot in ipairs(Inventory._slotRects) do
      print("  Slot", i, "id:", slot.id, "rect:", slot.x, slot.y, slot.w, slot.h)
      if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
        print("  --> HIT DETECTED on slot", i, slot.id)
      end
    end
  end

  if button == 1 then
    -- Close button
    if Inventory._closeButton then
      local btn = Inventory._closeButton
      if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        return true, true
      end
    end

    -- Title bar drag
    local titleRect = { x = Inventory.windowX, y = Inventory.windowY, w = Inventory.windowW, h = 32 }
    if x >= titleRect.x and x <= titleRect.x + titleRect.w and y >= titleRect.y and y <= titleRect.y + titleRect.h then
      Inventory.dragging = true
      Inventory.dragDX = x - Inventory.windowX
      Inventory.dragDY = y - Inventory.windowY
      return true, false
    end
    -- Check for left-click on consumable items (use instead of drag)
    print("Inventory: Checking left-click consumables, player exists:", player and "yes" or "no")
    if Inventory._slotRects and player then
      print("Inventory: Starting slot iteration for left-click")
      for _, slot in ipairs(Inventory._slotRects) do
        if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
          print("Inventory: Left-click hit detected on:", slot.id)
          -- Check if this is a consumable item
          local itemDef = Content.getItem(slot.id)
          print("Inventory: Item definition:", itemDef and itemDef.id or "nil", "consumable:", itemDef and itemDef.consumable or "nil")
          if itemDef then
            print("Inventory: Full item definition:")
            for k, v in pairs(itemDef) do
              print("  ", k, "=", v)
            end
          end
          if itemDef and (itemDef.consumable or itemDef.type == "consumable") then
            -- Use the item instead of starting drag
            print("Inventory: Calling useItem for consumable:", slot.id)
            local result = Inventory.useItem(player, slot.id)
            print("Inventory: useItem returned:", result)
            return true, false
          else
            -- Non-consumable items can be dragged
            print("Inventory: Starting drag for non-consumable:", slot.id)
            Inventory.drag = { from = 'inventory', id = slot.id }
            return true, false
          end
        end
      end
      print("Inventory: No slot hits detected for left-click")
    else
      print("Inventory: Skipping left-click check - no slotRects or no player")
    end
  elseif button == 2 then  -- Right-click to use item
    if Inventory._slotRects and player then
      for _, slot in ipairs(Inventory._slotRects) do
        if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
          Inventory.useItem(player, slot.id)
          return true, false
        end
      end
    end
  end
  return false, false
end

function Inventory.mousereleased(x, y, button, player)
  if not Inventory.visible then return false end
  if button == 1 and Inventory.dragging then
    Inventory.dragging = false
    return true, false
  end
  if button == 1 and Inventory.drag then
    -- Cancel drag if not handled by Equipment
    Inventory.drag = nil
    return true, false
  end
  return false, false
end

function Inventory.mousemoved(x, y, dx, dy)
  if not Inventory.visible then return false end
  if Inventory.dragging then
    local sw, sh = Viewport.getDimensions()
    Inventory.windowX = math.max(0, math.min(sw - Inventory.windowW, x - Inventory.dragDX))
    Inventory.windowY = math.max(0, math.min(sh - Inventory.windowH, y - Inventory.dragDY))
    if Input.setInventoryPos then Input.setInventoryPos(Inventory.windowX, Inventory.windowY) end
    return true
  end
  return false
end

function Inventory.update(dt)
  if not Inventory.visible then return end

  -- Clear hover if mouse is no longer over the item
  if Inventory.hoveredItem then
    local mx, my = Viewport.getMousePosition()
    local stillHovering = false
    
    -- Check if mouse is still over one of the slots
    if Inventory._slotRects then
      for _, slot in ipairs(Inventory._slotRects) do
        if mx >= slot.x and mx <= slot.x + slot.w and my >= slot.y and my <= slot.y + slot.h then
          stillHovering = true
          break
        end
      end
    end
    
    if not stillHovering then
      Inventory.hoveredItem = nil
      Inventory.hoverTimer = 0
    end
  end
end

function Inventory.keypressed(key)
  if not Inventory.visible then return false end
  return false
end

function Inventory.textinput(text)
  if not Inventory.visible then return false end
  return false
end

-- Use/consume an item
function Inventory.useItem(player, itemId)
  print("Inventory.useItem called with:", player and "player" or "nil", itemId)

  -- If no player provided, try to get current player
  if not player then
    local PlayerRef = require("src.core.player_ref")
    player = PlayerRef.get()
    print("Inventory.useItem: Got player from PlayerRef:", player and "found" or "nil")
  end

  if not player or not player.inventory or not player.inventory[itemId] or player.inventory[itemId] <= 0 then
    print("Inventory.useItem: Invalid player or no item in inventory")
    print("  player:", player and "exists" or "nil")
    print("  inventory:", player and player.inventory and "exists" or "nil")
    print("  item count:", player and player.inventory and player.inventory[itemId] or "nil")
    return false
  end

  local item = Content.getItem(itemId)
  print("Inventory.useItem: Item definition:", item and item.id or "nil")
  if not item then
    print("Inventory.useItem: No item definition found")
    return false
  end

  -- Check if item is consumable
  if not (item.consumable or item.type == "consumable") then
    print("Inventory.useItem: Item is not consumable")
    return false
  end

  print("Inventory.useItem: Processing consumable item:", itemId)

  -- Handle specific item types
  if itemId == "node_wallet" then
    print("Inventory.useItem: Starting node_wallet hack minigame")
    local HackMinigame = require("src.ui.hack_minigame")

    -- Start hack minigame with random difficulty based on player's skill/items
    local difficulty = math.random(1, 3)  -- Easy to medium for now

    HackMinigame.show(difficulty,
      -- On success
      function()
        local PortfolioManager = require("src.managers.portfolio")
        local success, message = PortfolioManager.useNodeWallet()

        if success then
          -- Remove one node wallet from inventory
          player.inventory[itemId] = player.inventory[itemId] - 1
          if player.inventory[itemId] <= 0 then
            player.inventory[itemId] = nil
          end

          -- Show success notification with fitting hacker theme
          local Notifications = require("src.ui.notifications")

          -- Extract node info from the original message
          local nodeInfo = message:match("Connected to: (.+)")
          if nodeInfo then
            Notifications.action("🔓 NEURAL NETWORK BREACHED • ACCESS GRANTED TO " .. nodeInfo:upper())
          else
            Notifications.action("🔓 NEURAL NETWORK BREACHED • WALLET DECRYPTED SUCCESSFULLY")
          end
        end

        HackMinigame.hide()
      end,

      -- On failure
      function(reason)
        local Notifications = require("src.ui.notifications")
        local failureMessages = {
          ["Time's up!"] = "⚠️ INTRUSION DETECTED • NEURAL LINK SEVERED",
          ["Wrong sequence!"] = "❌ SECURITY PROTOCOL ACTIVATED • INCORRECT PATHWAY",
        }
        local message = failureMessages[reason] or "⚠️ NETWORK BREACH FAILED • " .. (reason or "UNKNOWN ERROR"):upper()
        Notifications.action(message)
        HackMinigame.hide()
      end
    )

    return true  -- Don't process normally, minigame will handle it
  end

  -- Add more consumable items here as needed
  return false
end

return Inventory
