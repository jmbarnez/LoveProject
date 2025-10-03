local Util = require("src.core.util")
local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")
local UIUtils = require("src.ui.common.utils")
local Events = require("src.core.events")
local Settings = require("src.core.settings")

-- Import modular HUD components
local StatusBars = require("src.ui.hud.status_bars")
local Minimap = require("src.ui.hud.minimap")
local Hotbar = require("src.ui.hud.hotbar")
local Reticle = require("src.ui.hud.reticle")
local ExperienceNotification = require("src.ui.hud.experience_notification")

local UI = {}

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

function UI.drawHUD(player, world, enemies, hub, wreckage, lootDrops, camera, remotePlayers)
  -- Draw modular HUD components
  StatusBars.draw(player, world)
  -- Always hide system mouse cursor - use in-game cursors instead
  if love and love.mouse and love.mouse.setVisible then love.mouse.setVisible(false) end

  -- Draw reticle when not over UI (in-game targeting cursor)
  local UIManager = require("src.core.ui_manager")
  local overUI = UIManager.isMouseOverUI and UIManager.isMouseOverUI() or false

  if not overUI then
    Reticle.draw(player, world, camera)
  end
  Minimap.draw(player, world, enemies, hub, wreckage, lootDrops, remotePlayers, world:get_entities_with_components("mineable"))
  Hotbar.draw(player)
  ExperienceNotification.draw()
end


function UI.drawHelpers(player, world, hub, camera)
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

  -- Helper tooltip above stations (docking prompt and repair requirements)
  do
    -- Check all stations for tooltip display
    local all_stations = world:get_entities_with_components("station")
    for _, station in ipairs(all_stations) do
      if station and station.components and station.components.position and not player.docked then
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
            -- Handle beacon stations specially
            if station.components.repairable and station.components.repairable.broken then
              -- Show repair requirements for broken beacon stations with inventory status
              local RepairSystem = require("src.systems.repair_system")
              local requirements = station.components.repairable.repairCost
              local hasAllMaterials = RepairSystem.hasAllMaterials(player, requirements)

              text = "REPAIR REQUIRED:\n"
              for _, req in ipairs(requirements) do
                local playerCount = RepairSystem.getPlayerItemCount(player, req.item)
                local hasEnough = playerCount >= req.amount
                local indicator = hasEnough and "✓" or "✗"
                local color = hasEnough and "GREEN" or "RED"

                text = text .. string.format("%s %s: %d/%d\n", indicator, req.item, playerCount, req.amount)
              end

              if hasAllMaterials then
                text = text .. "\n✓ Press [R] to Repair"
              else
                text = text .. "\n✗ Insufficient materials"
              end
            elseif station.broken then
              -- Fallback: if station has broken property but no repairable component
              text = "REPAIR REQUIRED:\n✗ ore_tritanium: 0/25\n✗ ore_palladium: 0/15\n✗ scraps: 0/50\n\n✗ Insufficient materials"
            else
              -- Repaired beacon station
              text = "Beacon Array - OPERATIONAL"
            end
          elseif station.components.station and station.components.station.type == "ore_furnace_station" then
            if player.canDock and player.nearbyStation == station then
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
          elseif player.canDock and player.nearbyStation == station then
            dockPromptState.visible = true
            dockPromptState.station = station
            dockPromptState.stationName = (station.components and station.components.station and station.components.station.name) or "Station"
            if player.canDock then
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
      if gate and gate.components and gate.components.position and not player.docked then
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
    if not player.docked and world and camera then
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
          
          -- Button color based on key availability
          local buttonColor = hasKey and {0, 0.3, 0, 1} or {0.3, 0, 0, 1}
          local hoverColor = hasKey and {0, 0.4, 0, 1} or {0.4, 0, 0, 1}
          local activeColor = hasKey and {0, 0.5, 0, 1} or {0.5, 0, 0, 1}
          
          cratePromptState.collectRect = UIUtils.drawButton(buttonX, buttonY, buttonW, buttonH, "Open", hover, false, {
            font = buttonFont,
            bg = buttonColor,
            hoverBg = hoverColor,
            activeBg = activeColor,
          })

          -- Draw reward crate icon and label
          local itemDef = Content.getItem("reward_crate")
          local label = (itemDef and itemDef.name) or "Reward Crate"
          local labelFont = (Theme.fonts and Theme.fonts.small) or love.graphics.getFont()
          love.graphics.setFont(labelFont)
          Theme.setColor(Theme.colors.text)
          love.graphics.printf(label, cratePromptState.collectRect.x, cratePromptState.collectRect.y - labelFont:getHeight() - 6, cratePromptState.collectRect.w, "center")

          -- Draw key requirement with icon
          local keyDef = Content.getItem("reward_crate_key")
          local keyName = (keyDef and keyDef.name) or "Reward Key"
          local noteFont = (Theme.fonts and Theme.fonts.tiny) or labelFont
          love.graphics.setFont(noteFont)
          
          local keyColor = hasKey and (Theme.colors.success or {0, 0.8, 0, 1}) or (Theme.colors.danger or {0.8, 0, 0, 1})
          Theme.setColor(keyColor)
          
          -- Draw key icon if available
          if keyDef and keyDef.icon then
            local iconSize = 12
            local iconX = cratePromptState.collectRect.x + 8
            local iconY = cratePromptState.collectRect.y + cratePromptState.collectRect.h + 6
            UI.drawIcon(keyDef.icon, iconX, iconY, iconSize)
            
            -- Draw key count next to icon
            local keyText = string.format("%s: %d/1", keyName, keyCount)
            love.graphics.print(keyText, iconX + iconSize + 4, iconY + 2)
          else
            local keyText = string.format("%s: %d/1", keyName, keyCount)
            love.graphics.printf(keyText, cratePromptState.collectRect.x - 40, cratePromptState.collectRect.y + cratePromptState.collectRect.h + 6, cratePromptState.collectRect.w + 80, "center")
          end

          if previousFont then
            love.graphics.setFont(previousFont)
          end
        end
      end
    end
  end

  -- Helper tooltip for nearby asteroid or wreckage (shows hotkeys for mining/salvaging)
  do
    if not player.docked and world and camera then
      local mx, my = Viewport.getMousePosition()
      local sw, sh = Viewport.getDimensions()
      local camScale = camera and camera.scale or 1
      local camX = (camera and camera.x) or 0
      local camY = (camera and camera.y) or 0
      local worldMouseX = (mx - sw * 0.5) / camScale + camX
      local worldMouseY = (my - sh * 0.5) / camScale + camY
      local px, py = player.components.position.x, player.components.position.y

      local best, bestType
      local bestScore = math.huge
      local fallback, fallbackType
      local fallbackDist = math.huge

      local function evaluateEntity(entity, kind)
        local pos = entity.components and entity.components.position
        if not pos then return end
        local dx = pos.x - px
        local dy = pos.y - py
        local playerDist = math.sqrt(dx * dx + dy * dy)
        if playerDist > 600 then return end

        local cursorDx = worldMouseX - pos.x
        local cursorDy = worldMouseY - pos.y
        local cursorDist = math.sqrt(cursorDx * cursorDx + cursorDy * cursorDy)
        local radius = (entity.components and entity.components.collidable and entity.components.collidable.radius)
          or (kind == 'asteroid' and 30 or 20)
        local aimMargin = radius + 80
        local cursorScore = math.max(0, cursorDist - aimMargin)
        local score = cursorScore + playerDist * 0.01
        if cursorScore <= 80 and score < bestScore then
          best, bestType, bestScore = entity, kind, score
        end
        if playerDist < fallbackDist then
          fallback, fallbackType, fallbackDist = entity, kind, playerDist
        end
      end

      for _, a in ipairs(world:get_entities_with_components("mineable")) do
        local m = a.components and a.components.mineable
        if m and (m.resources or 0) > 0 then
          evaluateEntity(a, 'asteroid')
        end
      end

      for _, w in ipairs(world:get_entities_with_components("wreckage")) do
        local canSalvage = (w.canBeSalvaged and w:canBeSalvaged())
          or (w.salvageAmount and w.salvageAmount > 0)
          or (w.components and w.components.lootable and #w.components.lootable.drops > 0)
        if canSalvage then
          evaluateEntity(w, 'wreckage')
        end
      end

      if not best and fallback then
        best, bestType = fallback, fallbackType
      end

      if best then
        local bx = best.components.position.x
        local by = best.components.position.y
        local dx = bx - px
        local dy = by - py
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < 600 then
          local screenX = (bx - camX) * camScale + sw * 0.5
          local screenY = (by - camY) * camScale + sh * 0.5

          local function findKeyForTurretKind(kind)
            if not player or not player.components or not player.components.equipment then return nil end
            local slotNum
            for _, gridData in ipairs(player.components.equipment.grid) do
              if gridData.type == 'turret' and gridData.module and gridData.module.kind == kind then
                slotNum = gridData.slot
                break
              end
            end
            if not slotNum then return nil end
            local HotbarSystem = require('src.systems.hotbar')
            local km = Settings.getKeymap()
            if HotbarSystem and HotbarSystem.slots and km then
              for i, s in ipairs(HotbarSystem.slots) do
                if s.item == ('turret_slot_' .. tostring(slotNum)) then
                  return km['hotbar_' .. tostring(i)]
                end
              end
            end
            return nil
          end

          local function labelForKey(k)
            if not k then return '?' end
            k = tostring(k)
            if k == 'mouse1' then return 'LMB' end
            if k == 'mouse2' then return 'RMB' end
            if k == 'space' then return 'SPACE' end
            if #k == 1 then return k:upper() end
            return k:upper()
          end

          local text, canPerformAction
          if bestType == 'asteroid' then
            if hasRequiredTurret(player, 'mining_laser') then
              local key = findKeyForTurretKind('mining_laser')
              text = string.format('Aim at asteroid and press [%s] to mine', labelForKey(key))
              canPerformAction = true
            else
              text = 'Install a Mining Laser to mine asteroids'
              canPerformAction = false
            end
          else
            if hasRequiredTurret(player, 'salvaging_laser') then
              local key = findKeyForTurretKind('salvaging_laser')
              text = string.format('Aim at wreckage and press [%s] to salvage', labelForKey(key))
              canPerformAction = true
            else
              text = 'Install a Salvaging Laser to process wreckage'
              canPerformAction = false
            end
          end

          local paddingX, paddingY = 10, 6
          local font = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
          local oldFont = love.graphics.getFont()
          love.graphics.setFont(font)
          local textW = font:getWidth(text)
          local textH = font:getHeight()
          local boxW = textW + paddingX * 2
          local boxH = textH + paddingY * 2
          local boxX = math.floor(screenX - boxW * 0.5 + 0.5)
          local boxY = math.floor(screenY - boxH - 40 + 0.5)
          boxX = math.max(8, math.min(sw - boxW - 8, boxX))
          boxY = math.max(8, math.min(sh - boxH - 8, boxY))
          Theme.drawGradientGlowRect(boxX, boxY, boxW, boxH, 4,
            Theme.colors.bg2, Theme.colors.bg1, Theme.colors.accent, Theme.effects.glowWeak * 0.2)
          Theme.drawEVEBorder(boxX, boxY, boxW, boxH, 4, Theme.colors.border, 2)
          local triCx = math.floor(screenX + 0.5)
          local triY = boxY + boxH
          Theme.setColor(Theme.colors.bg2)
          love.graphics.polygon('fill', triCx - 6, triY, triCx + 6, triY, triCx, triY + 8)
          Theme.setColor(Theme.colors.border)
          love.graphics.line(triCx - 6, triY, triCx, triY + 8)
          love.graphics.line(triCx + 6, triY, triCx, triY + 8)
          Theme.setColor(canPerformAction and Theme.colors.text or Theme.colors.danger)
          love.graphics.print(text, boxX + paddingX, boxY + paddingY)
          if oldFont then love.graphics.setFont(oldFont) end
        end
      end
    end
  end

end

-- Export universal icon drawing helper
local IconSystem = require("src.core.icon_system")
UI.drawIcon = IconSystem.drawIconAny
UI.drawTurretIcon = IconSystem.drawIconAny

function UI.handleHelperMousePressed(x, y, button, player)
  if button ~= 1 then return false end
  if not dockPromptState.visible and not warpPromptState.visible and not cratePromptState.visible then return false end
  if not player or player.docked then return false end

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
    if player.canDock then
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

