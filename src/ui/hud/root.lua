local Util = require("src.core.util")
local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")
local Events = require("src.core.events")
local Settings = require("src.core.settings")
local IconSystem = require("src.core.icon_system")
local RepairSystem = require("src.systems.repair_system")

-- Import modular HUD components
local StatusBars = require("src.ui.hud.hud_status_bars")
local Minimap = require("src.ui.hud.minimap")
local Hotbar = require("src.ui.hud.hotbar")
local Crosshair = require("src.ui.hud.crosshair")
local ExperienceNotification = require("src.ui.hud.experience_notification")
local ConstructionButton = require("src.ui.hud.construction_button")

local UI = {}

local function getDocking(player)
  return player and player.components and player.components.docking_status
end

local dockPromptState = {
  visible = false,
  dockRect = nil,
}

local warpPromptState = {
  visible = false,
  warpRect = nil,
}

local cratePromptState = {
  visible = false,
  collectRect = nil,
  pickup = nil,
}

local beaconRepairPromptState = {
  visible = false,
  buttonRect = nil,
  station = nil,
  canRepair = false,
}

local function clampColorComponent(value)
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

local function lightenColor(color, delta)
  local baseR = (color and color[1]) or 0
  local baseG = (color and color[2]) or 0
  local baseB = (color and color[3]) or 0
  local r = clampColorComponent(baseR + delta)
  local g = clampColorComponent(baseG + delta)
  local b = clampColorComponent(baseB + delta)
  local a = (color and color[4]) or 1
  return { r, g, b, a }
end

local function getItemDisplayName(itemId)
  local def = Content.getItem(itemId)
  if def and def.name then
    return def.name
  end

  local pretty = tostring(itemId or "")
  pretty = pretty:gsub("_", " ")
  return pretty:gsub("^%l", string.upper)
end

local function drawBeaconRepairPopup(station, player, screenX, screenY, sw, sh)
  local requirements = (station.components.repairable and station.components.repairable.repairCost) or {}
  local hasAllMaterials = RepairSystem.hasAllMaterials(player, requirements)

  beaconRepairPromptState.visible = true
  beaconRepairPromptState.station = station
  beaconRepairPromptState.canRepair = hasAllMaterials

  local paddingX, paddingY = 18, 14
  local headerSpacing = 8
  local rowSpacing = 6
  local statusSpacing = 10
  local buttonSpacing = 14
  local instructionSpacing = 6
  local iconSize = 28
  local buttonWidth, buttonHeight = 160, 36

  local headerFont = (Theme.fonts and Theme.fonts.medium) or love.graphics.getFont()
  local textFont = (Theme.fonts and Theme.fonts.small) or love.graphics.getFont()
  local buttonFont = (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
  local oldFont = love.graphics.getFont()

  local headerHeight = headerFont:getHeight()
  local textHeight = textFont:getHeight()

  local panelWidth = 240
  panelWidth = math.max(panelWidth, headerFont:getWidth("Repair Beacon") + paddingX * 2)

  local totalRowHeight = 0
  for _, req in ipairs(requirements) do
    local itemName = getItemDisplayName(req.item)
    local nameWidth = textFont:getWidth(itemName)
    local playerCount = RepairSystem.getPlayerItemCount(player, req.item)
    local countText = string.format("%d / %d", playerCount, req.amount)
    local countWidth = textFont:getWidth(countText)
    local rowHeight = math.max(iconSize, textHeight)
    totalRowHeight = totalRowHeight + rowHeight
    panelWidth = math.max(panelWidth, iconSize + 8 + nameWidth + 8 + countWidth + paddingX * 2)
  end
  if #requirements > 1 then
    totalRowHeight = totalRowHeight + (#requirements - 1) * rowSpacing
  end

  local statusText = hasAllMaterials and "Materials Ready" or "Missing Materials"
  panelWidth = math.max(panelWidth, textFont:getWidth(statusText) + paddingX * 2)

  local binding = Settings.getBindingValue and Settings.getBindingValue("repair_beacon", "primary") or "r"
  local bindingLabel = UIUtils.formatKeyLabel(binding, "R")
  local instructionText
  if hasAllMaterials then
    instructionText = string.format("Press [%s] or Click to Repair", bindingLabel)
  else
    instructionText = "Gather required resources"
  end
  panelWidth = math.max(panelWidth, textFont:getWidth(instructionText) + paddingX * 2)

  local panelHeight = paddingY * 2 + headerHeight
  if #requirements > 0 then
    panelHeight = panelHeight + headerSpacing + totalRowHeight
  else
    panelHeight = panelHeight + headerSpacing
  end
  panelHeight = panelHeight + statusSpacing + textHeight
  panelHeight = panelHeight + buttonSpacing + buttonHeight
  panelHeight = panelHeight + instructionSpacing + textHeight

  local panelX = math.floor(screenX - panelWidth * 0.5 + 0.5)
  local panelY = math.floor(screenY - panelHeight - 60 + 0.5)
  panelX = math.max(8, math.min(sw - panelWidth - 8, panelX))
  panelY = math.max(8, math.min(sh - panelHeight - 8, panelY))

  Theme.drawGradientGlowRect(panelX, panelY, panelWidth, panelHeight, 6,
    Theme.colors.bg2, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak * 0.2)
  Theme.drawEVEBorder(panelX, panelY, panelWidth, panelHeight, 6, Theme.colors.border, 2)

  local triCx = math.floor(screenX + 0.5)
  local triY = panelY + panelHeight
  Theme.setColor(Theme.colors.bg2)
  love.graphics.polygon('fill', triCx - 8, triY, triCx + 8, triY, triCx, triY + 10)
  Theme.setColor(Theme.colors.border)
  love.graphics.line(triCx - 8, triY, triCx, triY + 10)
  love.graphics.line(triCx + 8, triY, triCx, triY + 10)

  local currentY = panelY + paddingY
  love.graphics.setFont(headerFont)
  Theme.setColor(Theme.colors.textHighlight)
  love.graphics.print("Repair Beacon", panelX + paddingX, currentY)
  currentY = currentY + headerHeight + headerSpacing

  love.graphics.setFont(textFont)
  Theme.setColor(Theme.colors.text)

  if #requirements > 0 then
    for index, req in ipairs(requirements) do
      local rowHeight = math.max(iconSize, textHeight)
      local iconX = panelX + paddingX
      local iconY = currentY + (rowHeight - iconSize) * 0.5
      IconSystem.drawIconAny({ Content.getItem(req.item), req.item }, iconX, iconY, iconSize, 1.0)

      local itemName = getItemDisplayName(req.item)
      local textY = currentY + (rowHeight - textHeight) * 0.5
      Theme.setColor(Theme.colors.text)
      love.graphics.print(itemName, iconX + iconSize + 8, textY)

      local playerCount = RepairSystem.getPlayerItemCount(player, req.item)
      local countText = string.format("%d / %d", playerCount, req.amount)
      local countColor = playerCount >= req.amount and Theme.colors.success or Theme.colors.danger
      Theme.setColor(countColor)
      local countWidth = textFont:getWidth(countText)
      local countX = panelX + panelWidth - paddingX - countWidth
      love.graphics.print(countText, countX, textY)

      currentY = currentY + rowHeight
      if index < #requirements then
        currentY = currentY + rowSpacing
      end
    end
  end

  currentY = currentY + statusSpacing
  Theme.setColor(hasAllMaterials and Theme.colors.success or Theme.colors.danger)
  love.graphics.print(statusText, panelX + paddingX, currentY)
  currentY = currentY + textHeight + buttonSpacing

  local buttonX = math.floor(panelX + (panelWidth - buttonWidth) * 0.5 + 0.5)
  local buttonY = currentY
  local mouseX, mouseY = Viewport.getMousePosition()
  local hover = UIUtils.pointInRect(mouseX, mouseY, {
    x = buttonX,
    y = buttonY,
    w = buttonWidth,
    h = buttonHeight,
  })

  local baseColor = hasAllMaterials and {0, 0.6, 0, 1} or {0.6, 0, 0, 1}
  local hoverColor = lightenColor(baseColor, 0.15)
  local activeColor = lightenColor(baseColor, 0.25)

  love.graphics.setFont(buttonFont)
  beaconRepairPromptState.buttonRect = UIUtils.drawButton(buttonX, buttonY, buttonWidth, buttonHeight,
    "Repair", hover, false, {
      font = buttonFont,
      bg = baseColor,
      hoverBg = hoverColor,
      activeBg = activeColor,
      textColor = Theme.colors.text,
    })

  currentY = currentY + buttonHeight + instructionSpacing
  love.graphics.setFont(textFont)
  Theme.setColor(Theme.colors.textSecondary)
  love.graphics.print(instructionText, panelX + paddingX, currentY)

  if oldFont then
    love.graphics.setFont(oldFont)
  end
end

-- Helper function to check if player has required turret type
local function hasRequiredTurret(player, requiredType)
  if not player.components or not player.components.equipment or not player.components.equipment.grid then
    return false
  end
  
  for _, gridData in ipairs(player.components.equipment.grid) do
    if gridData.type == "turret" and gridData.module and gridData.module.kind == requiredType then
      return true
    end
  end
  return false
end

function UI.drawHUD(player, world, enemies, hub, wreckage, lootDrops, camera, remotePlayers, remotePlayerSnapshots)
  -- Draw modular HUD components
  StatusBars.draw(player, world)
  -- System mouse cursor remains hidden during gameplay; custom reticle is drawn instead

  -- Draw targeting overlays and gameplay cursor when not over UI
  local UIManager = require("src.core.ui_manager")
  local overUI = UIManager.isMouseOverUI and UIManager.isMouseOverUI() or false

  if not overUI then
    Crosshair.draw(player, world, camera)
  end
  Minimap.draw(player, world, enemies, hub, wreckage, lootDrops, remotePlayers, world:get_entities_with_components("mineable"), remotePlayerSnapshots)
  Hotbar.draw(player)
  ExperienceNotification.draw()
  ConstructionButton.draw()
end


function UI.drawHelpers(player, world, hub, camera)
  local docking = getDocking(player)
  dockPromptState.visible = false
  dockPromptState.dockRect = nil
  dockPromptState.toggleRect = nil
  dockPromptState.station = nil
  dockPromptState.stationName = nil
  warpPromptState.visible = false
  warpPromptState.warpRect = nil
  cratePromptState.visible = false
  cratePromptState.collectRect = nil
  cratePromptState.pickup = nil
  beaconRepairPromptState.visible = false
  beaconRepairPromptState.buttonRect = nil
  beaconRepairPromptState.station = nil
  beaconRepairPromptState.canRepair = false

  -- Helper tooltip above stations (docking prompt and repair requirements)
  do
    -- Check all stations for tooltip display
    local all_stations = world:get_entities_with_components("station")
    for _, station in ipairs(all_stations) do
      if station and station.components and station.components.position and not (docking and docking.docked) then
        local sx, sy = station.components.position.x, station.components.position.y
        local sw, sh = Viewport.getDimensions()
        local camScale = camera and camera.scale or 1
        local camX = (camera and camera.x) or 0
        local camY = (camera and camera.y) or 0

        -- Calculate distance to player
        local dx = sx - player.components.position.x
        local dy = sy - player.components.position.y
        local distance = math.sqrt(dx * dx + dy * dy)

        -- World -> screen
        local screenX = (sx - camX) * camScale + sw * 0.5
        local screenY = (sy - camY) * camScale + sh * 0.5

        -- Only draw if on-screen and close enough
        local helperRange = 500
        if station.radius then
          helperRange = math.max(helperRange, station.radius + 150)
        end
        -- Also consider weapon disabled radius for docking UI
        if station.weaponDisableRadius then
          helperRange = math.max(helperRange, station.weaponDisableRadius + 150)
        end
        if distance < helperRange then
          local text = nil

          -- Check station type and show appropriate tooltip
          if station.components.station and station.components.station.type == "beacon_station" then
            if station.components.repairable and station.components.repairable.broken then
              drawBeaconRepairPopup(station, player, screenX, screenY, sw, sh)
              text = nil
            elseif station.broken then
              -- Fallback: if station has broken property but no repairable component
              text = "REPAIR REQUIRED:\n✗ ore_tritanium: 0/25\n✗ ore_palladium: 0/15\n✗ scraps: 0/50\n\n✗ Insufficient materials"
            else
              text = "Beacon Array - OPERATIONAL"
            end
          elseif station.components.station and station.components.station.type == "ore_furnace_station" then
            if docking and docking.can_dock and docking.nearby_station == station then
              dockPromptState.visible = true
              dockPromptState.station = station
              dockPromptState.stationName = (station.components and station.components.station and station.components.station.name) or "Ore Furnace"
              local sw, sh = Viewport.getDimensions()
              local mouseX, mouseY = Viewport.getMousePosition()

              -- Simple dock button - no minimized/expanded states
              local buttonW, buttonH = 80, 36
              local buttonX = math.floor(screenX - buttonW * 0.5 + 0.5)
              local buttonY = math.floor(screenY - buttonH - 48 + 0.5)
              buttonX = math.max(8, math.min(sw - buttonW - 8, buttonX))
              buttonY = math.max(8, math.min(sh - buttonH - 8, buttonY))

              local hover = UIUtils.pointInRect(mouseX, mouseY, {
                x = buttonX,
                y = buttonY,
                w = buttonW,
                h = buttonH,
              })

              local buttonFont = (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
              local previousFont = love.graphics.getFont()
              dockPromptState.dockRect = UIUtils.drawButton(buttonX, buttonY, buttonW, buttonH, "Dock", hover, false, {
                font = buttonFont,
                bg = {0, 0, 0, 1}, -- Black background
                hoverBg = {0.1, 0.1, 0.1, 1}, -- Dark gray on hover
                activeBg = {0.2, 0.2, 0.2, 1}, -- Lighter gray when active
              })
              dockPromptState.toggleRect = nil

              local triCx = math.floor(screenX + 0.5)
              local triY = dockPromptState.dockRect.y + dockPromptState.dockRect.h
              Theme.setColor(Theme.colors.bg2)
              love.graphics.polygon('fill', triCx - 6, triY, triCx + 6, triY, triCx, triY + 8)
              Theme.setColor(Theme.colors.border)
              love.graphics.line(triCx - 6, triY, triCx, triY + 8)
              love.graphics.line(triCx + 6, triY, triCx, triY + 8)

              if previousFont then
                love.graphics.setFont(previousFont)
              end
            else
              -- No tooltip for furnace station when not in docking range
              text = nil
            end
          elseif docking and docking.can_dock and docking.nearby_station == station then
            dockPromptState.visible = true
            dockPromptState.station = station
            dockPromptState.stationName = (station.components and station.components.station and station.components.station.name) or "Station"
            if docking.can_dock then
              local sw, sh = Viewport.getDimensions()
              local mouseX, mouseY = Viewport.getMousePosition()

              -- Simple dock button - no minimized/expanded states
              local buttonW, buttonH = 80, 36
              local buttonX = math.floor(screenX - buttonW * 0.5 + 0.5)
              local buttonY = math.floor(screenY - buttonH - 48 + 0.5)
              buttonX = math.max(8, math.min(sw - buttonW - 8, buttonX))
              buttonY = math.max(8, math.min(sh - buttonH - 8, buttonY))

              local hover = UIUtils.pointInRect(mouseX, mouseY, {
                x = buttonX,
                y = buttonY,
                w = buttonW,
                h = buttonH,
              })

              local buttonFont = (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
              local previousFont = love.graphics.getFont()
              dockPromptState.dockRect = UIUtils.drawButton(buttonX, buttonY, buttonW, buttonH, "Dock", hover, false, {
                font = buttonFont,
                bg = {0, 0, 0, 1}, -- Black background
                hoverBg = {0.1, 0.1, 0.1, 1}, -- Dark gray on hover
                activeBg = {0.2, 0.2, 0.2, 1}, -- Lighter gray when active
              })
              dockPromptState.toggleRect = nil

              local triCx = math.floor(screenX + 0.5)
              local triY = dockPromptState.dockRect.y + dockPromptState.dockRect.h
              Theme.setColor(Theme.colors.bg2)
              love.graphics.polygon('fill', triCx - 6, triY, triCx + 6, triY, triCx, triY + 8)
              Theme.setColor(Theme.colors.border)
              love.graphics.line(triCx - 6, triY, triCx, triY + 8)
              love.graphics.line(triCx + 6, triY, triCx, triY + 8)

              if previousFont then
                love.graphics.setFont(previousFont)
              end
            end
          end

          -- Render tooltip if we have text to show
          if text then
            -- Style and layout
            local paddingX, paddingY = 10, 6
            local font = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
            local oldFont = love.graphics.getFont()
            love.graphics.setFont(font)

            -- Handle multi-line text
            local lines = {}
            for line in text:gmatch("[^\n]+") do
              table.insert(lines, line)
            end

            local maxWidth = 0
            local totalHeight = 0
            for _, line in ipairs(lines) do
              local lineWidth = font:getWidth(line)
              maxWidth = math.max(maxWidth, lineWidth)
              totalHeight = totalHeight + font:getHeight()
            end

            local boxW = maxWidth + paddingX * 2
            local boxH = totalHeight + paddingY * 2
            local boxX = math.floor(screenX - boxW * 0.5 + 0.5)
            local boxY = math.floor(screenY - boxH - 50 + 0.5) -- 50px above station
            -- Keep on-screen
            boxX = math.max(8, math.min(sw - boxW - 8, boxX))
            boxY = math.max(8, math.min(sh - boxH - 8, boxY))

            -- Background and border
            Theme.drawGradientGlowRect(boxX, boxY, boxW, boxH, 4,
              Theme.colors.bg2, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak * 0.2)
            Theme.drawEVEBorder(boxX, boxY, boxW, boxH, 4, Theme.colors.border, 2)

            -- Pointer triangle
            local triCx = math.floor(screenX + 0.5)
            local triY = boxY + boxH
            Theme.setColor(Theme.colors.bg2)
            love.graphics.polygon('fill', triCx - 6, triY, triCx + 6, triY, triCx, triY + 8)
            Theme.setColor(Theme.colors.border)
            love.graphics.line(triCx - 6, triY, triCx, triY + 8)
            love.graphics.line(triCx + 6, triY, triCx, triY + 8)

            -- Multi-line text rendering
            Theme.setColor(Theme.colors.text)
            local currentY = boxY + paddingY
            for _, line in ipairs(lines) do
              love.graphics.print(line, boxX + paddingX, currentY)
              currentY = currentY + font:getHeight()
            end

            if oldFont then love.graphics.setFont(oldFont) end
          end
        end
      end
    end
  end

  -- Warp button above warp gates
  do
    local all_gates = world:get_entities_with_components("warp_gate")
    for _, gate in ipairs(all_gates) do
      if gate and gate.components and gate.components.position and not (docking and docking.docked) then
        local gx, gy = gate.components.position.x, gate.components.position.y
        local sw, sh = Viewport.getDimensions()
        local camScale = camera and camera.scale or 1
        local camX = (camera and camera.x) or 0
        local camY = (camera and camera.y) or 0

        -- Calculate distance to player
        local dx = gx - player.components.position.x
        local dy = gy - player.components.position.y
        local distance = math.sqrt(dx * dx + dy * dy)

        -- World -> screen
        local screenX = (gx - camX) * camScale + sw * 0.5
        local screenY = (gy - camY) * camScale + sh * 0.5

        -- Determine interaction range from interactable/component
        local range = (gate.components.interactable and gate.components.interactable.range)
          or (gate.components.warp_gate and gate.components.warp_gate.interactionRange) or 500

        -- Only draw if on-screen and close enough
        if distance <= range then
          local mouseX, mouseY = Viewport.getMousePosition()
          warpPromptState.visible = true

          -- Simple warp button - similar to dock button
          local buttonW, buttonH = 80, 36
          local buttonX = math.floor(screenX - buttonW * 0.5 + 0.5)
          local buttonY = math.floor(screenY - buttonH - 48 + 0.5)
          buttonX = math.max(8, math.min(sw - buttonW - 8, buttonX))
          buttonY = math.max(8, math.min(sh - buttonH - 8, buttonY))

          local hover = UIUtils.pointInRect(mouseX, mouseY, {
            x = buttonX,
            y = buttonY,
            w = buttonW,
            h = buttonH,
          })

          local buttonFont = (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
          local previousFont = love.graphics.getFont()
          warpPromptState.warpRect = UIUtils.drawButton(buttonX, buttonY, buttonW, buttonH, "Warp", hover, false, {
            font = buttonFont,
            bg = {0, 0, 0, 1}, -- Black background
            hoverBg = {0.1, 0.1, 0.1, 1}, -- Dark gray on hover
            activeBg = {0.2, 0.2, 0.2, 1}, -- Lighter gray when active
          })

          local triCx = math.floor(screenX + 0.5)
          local triY = warpPromptState.warpRect.y + warpPromptState.warpRect.h
          Theme.setColor(Theme.colors.bg2)
          love.graphics.polygon('fill', triCx - 6, triY, triCx + 6, triY, triCx, triY + 8)
          Theme.setColor(Theme.colors.border)
          love.graphics.line(triCx - 6, triY, triCx, triY + 8)
          love.graphics.line(triCx + 6, triY, triCx, triY + 8)

          if previousFont then
            love.graphics.setFont(previousFont)
          end
        end
      end
    end
  end

  -- Reward crate collection prompt
  do
    if not (docking and docking.docked) and world and camera then
      -- Look for reward crate world objects instead of pickups
      local rewardCrates = world:get_entities_with_components("interactable", "position")
      local nearestCrate = nil
      local nearestDistance = math.huge
      
      for _, crate in ipairs(rewardCrates) do
        if crate and crate.components and crate.components.position and crate.components.interactable then
          -- Check if this is a reward crate by looking for the reward key requirement
          if crate.components.interactable.requiresKey == "reward_crate_key" then
            local px = player.components.position.x
            local py = player.components.position.y
            local cx = crate.components.position.x
            local cy = crate.components.position.y
            local dx = cx - px
            local dy = cy - py
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance < nearestDistance and distance <= 800 then
              nearestDistance = distance
              nearestCrate = crate
            end
          end
        end
      end
      
      if nearestCrate and nearestCrate.components and nearestCrate.components.position then
        local sw, sh = Viewport.getDimensions()
        local camScale = camera and camera.scale or 1
        local camX = (camera and camera.x) or 0
        local camY = (camera and camera.y) or 0

        local px = nearestCrate.components.position.x
        local py = nearestCrate.components.position.y
        local screenX = (px - camX) * camScale + sw * 0.5
        local screenY = (py - camY) * camScale + sh * 0.5

        if nearestDistance <= 800 and screenX >= -80 and screenX <= sw + 80 and screenY >= -80 and screenY <= sh + 80 then
          cratePromptState.visible = true
          cratePromptState.pickup = nearestCrate

          local hasKey = player.components and player.components.cargo and player.components.cargo:has("reward_crate_key", 1)
          local keyCount = player.components and player.components.cargo and player.components.cargo:getQuantity("reward_crate_key") or 0

          local buttonW, buttonH = 120, 36
          local buttonX = math.floor(screenX - buttonW * 0.5 + 0.5)
          local buttonY = math.floor(screenY - buttonH - 48 + 0.5)
          buttonX = math.max(8, math.min(sw - buttonW - 8, buttonX))
          buttonY = math.max(8, math.min(sh - buttonH - 8, buttonY))

          local mouseX, mouseY = Viewport.getMousePosition()
          local hover = UIUtils.pointInRect(mouseX, mouseY, {
            x = buttonX,
            y = buttonY,
            w = buttonW,
            h = buttonH,
          })

          local buttonFont = (Theme.fonts and Theme.fonts.normal) or love.graphics.getFont()
          local previousFont = love.graphics.getFont()
          
          -- Button color and text based on key availability
          local buttonColor, buttonText, textColor
          if hasKey then
            buttonColor = {0, 0.6, 0, 1} -- Green
            buttonText = "Open"
            textColor = Theme.colors.success or {0, 0.8, 0, 1}
          else
            buttonColor = {0.6, 0, 0, 1} -- Red
            buttonText = "Locked"
            textColor = Theme.colors.danger or {0.8, 0, 0, 1}
          end
          
          local hoverColor = {buttonColor[1] + 0.2, buttonColor[2] + 0.2, buttonColor[3] + 0.2, 1}
          local activeColor = {buttonColor[1] + 0.3, buttonColor[2] + 0.3, buttonColor[3] + 0.3, 1}
          
          cratePromptState.collectRect = UIUtils.drawButton(buttonX, buttonY, buttonW, buttonH, buttonText, hover, false, {
            font = buttonFont,
            bg = buttonColor,
            hoverBg = hoverColor,
            activeBg = activeColor,
          })

          -- Draw text under the button
          local textFont = (Theme.fonts and Theme.fonts.small) or love.graphics.getFont()
          love.graphics.setFont(textFont)
          Theme.setColor(textColor)
          
          local textToShow = hasKey and "Open" or "Reward Key Required"
          local textWidth = textFont:getWidth(textToShow)
          local textX = buttonX + (buttonW - textWidth) / 2
          local textY = buttonY + buttonH + 8
          love.graphics.print(textToShow, textX, textY)

          if previousFont then
            love.graphics.setFont(previousFont)
          end
        end
      end
    end
  end


end

-- Export universal icon drawing helper
UI.drawIcon = IconSystem.drawIconAny
UI.drawTurretIcon = IconSystem.drawIconAny

function UI.handleHelperMousePressed(x, y, button, player)
  if button ~= 1 then return false end
  
  -- Handle construction button clicks first
  if ConstructionButton.mousepressed(x, y, button) then
    return true
  end
  
  if not dockPromptState.visible and not warpPromptState.visible and not cratePromptState.visible and not beaconRepairPromptState.visible then
    return false
  end
  local docking = getDocking(player)
  if not player or (docking and docking.docked) then return false end

  if beaconRepairPromptState.buttonRect and UIUtils.pointInRect(x, y, beaconRepairPromptState.buttonRect) then
    local station = beaconRepairPromptState.station
    if station and station.components and station.components.repairable and station.components.repairable.broken then
      local success = RepairSystem.tryRepair(station, player)
      local Notifications = require("src.ui.notifications")
      if success then
        Notifications.add("Beacon station repaired successfully!", "success")
        beaconRepairPromptState.visible = false
        beaconRepairPromptState.buttonRect = nil
        beaconRepairPromptState.station = nil
        beaconRepairPromptState.canRepair = false
      else
        Notifications.add("Insufficient materials for repair", "error")
      end
    end
    return true
  end

  if cratePromptState.collectRect and UIUtils.pointInRect(x, y, cratePromptState.collectRect) then
    local crate = cratePromptState.pickup
    if crate and not crate.dead then
      local hasKey = player.components and player.components.cargo and player.components.cargo:has("reward_crate_key", 1)
      if not hasKey then
        local Notifications = require("src.ui.notifications")
        Notifications.add("You need a Reward Key to open this crate.", "warning")
        cratePromptState.visible = false
        cratePromptState.collectRect = nil
        cratePromptState.pickup = nil
        return true
      end
      
      -- Set the nearby interactable and use the interaction system
      player._nearbyInteractable = crate
      local InteractionSystem = require("src.systems.interaction")
      local success = InteractionSystem.interact(player)
      if success then
        -- Mark the crate as used/removed
        crate.dead = true
      end
      player._nearbyInteractable = nil
    end
    cratePromptState.visible = false
    cratePromptState.collectRect = nil
    cratePromptState.pickup = nil
    return true
  end

  if dockPromptState.dockRect and UIUtils.pointInRect(x, y, dockPromptState.dockRect) then
    if docking and docking.can_dock then
      Events.emit(Events.GAME_EVENTS.DOCK_REQUESTED)
      return true
    end
  end

  if warpPromptState.warpRect and UIUtils.pointInRect(x, y, warpPromptState.warpRect) then
    Events.emit(Events.GAME_EVENTS.WARP_REQUESTED)
    return true
  end

  return false
end

return UI
