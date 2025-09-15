local Util = require("src.core.util")
local Theme = require("src.core.theme")
local Content = require("src.content.content")
local Viewport = require("src.core.viewport")

-- Import modular HUD components
local StatusBars = require("src.ui.hud.status_bars")
local Minimap = require("src.ui.hud.minimap")
local Hotbar = require("src.ui.hud.hotbar")
local Reticle = require("src.ui.hud.reticle")

local UI = {}

-- Helper function to check if player has required turret type
local function hasRequiredTurret(player, requiredType)
  if not player.components or not player.components.equipment or not player.components.equipment.turrets then
    return false
  end
  
  for _, turretData in ipairs(player.components.equipment.turrets) do
    if turretData.turret and turretData.turret.kind == requiredType then
      return true
    end
  end
  return false
end

function UI.drawHUD(player, world, enemies, hub, wreckage, lootDrops, camera, remotePlayers)
  love.graphics.origin()

  -- Helper tooltip above stations (docking prompt and repair requirements)
  do
    local Settings = require("src.core.settings")
    local g = Settings.getGraphicsSettings()
    local helpersEnabled = (g.helpers_enabled ~= false)

    -- Check all stations for tooltip display
    local allStations = world:getEntitiesWithComponents("station")
    for _, station in ipairs(allStations) do
      if helpersEnabled and station and station.components and station.components.position and not player.docked then
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
        if screenX > 0 and screenX < sw and screenY > 0 and screenY < sh and distance < 300 then
          local keymap = Settings.getKeymap()
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
          elseif station == hub then
            -- Show docking prompt only for hub station
            local dockKey = (keymap and keymap.dock or "space"):upper()
            if player.canDock then
              text = "Press [" .. dockKey .. "] to Dock"
            else
              text = "Move closer to the station to dock"
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

  -- Helper tooltip above warp gates (same visual style as stations)
  do
    local Settings = require("src.core.settings")
    local g = Settings.getGraphicsSettings()
    local helpersEnabled = (g.helpers_enabled ~= false)

    local allGates = world:getEntitiesWithComponents("warp_gate")
    for _, gate in ipairs(allGates) do
      if helpersEnabled and gate and gate.components and gate.components.position and not player.docked then
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
          or (gate.components.warp_gate and gate.components.warp_gate.interactionRange) or 300

        -- Only draw if on-screen and close enough
        if screenX > 0 and screenX < sw and screenY > 0 and screenY < sh and distance <= range then
          local keymap = Settings.getKeymap()
          local dockKey = (keymap and keymap.dock or "space"):upper()
          local text = string.format("Press [%s] to Use Warp Gate", dockKey)

          -- Style and layout (same as station helper)
          local paddingX, paddingY = 10, 6
          local font = Theme.fonts and Theme.fonts.small or love.graphics.getFont()
          local oldFont = love.graphics.getFont()
          love.graphics.setFont(font)

          local lines = { text }
          local maxWidth = font:getWidth(text)
          local totalHeight = font:getHeight()

          local boxW = maxWidth + paddingX * 2
          local boxH = totalHeight + paddingY * 2
          local boxX = math.floor(screenX - boxW * 0.5 + 0.5)
          local boxY = math.floor(screenY - boxH - 50 + 0.5) -- 50px above gate
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

          -- Text
          Theme.setColor(Theme.colors.text)
          love.graphics.print(text, boxX + paddingX, boxY + paddingY)

          if oldFont then love.graphics.setFont(oldFont) end
        end
      end
    end
  end

  -- Helper tooltip for mouse-hovered asteroid or wreckage (updated to show bound keys, no LMB hold)
  do
    local Settings = require("src.core.settings")
    local g = Settings.getGraphicsSettings()
    local helpersEnabled = (g.helpers_enabled ~= false)
    if helpersEnabled and not player.docked and world and camera then
      local best, bestType = nil, nil
      
      -- Get mouse cursor world position
      local mx, my = Viewport.getMousePosition()
      local sw, sh = Viewport.getDimensions()
      local camScale = camera and camera.scale or 1
      local camX = (camera and camera.x) or 0
      local camY = (camera and camera.y) or 0
      
      -- Convert mouse screen position to world position
      local worldMouseX = (mx - sw * 0.5) / camScale + camX
      local worldMouseY = (my - sh * 0.5) / camScale + camY
      
      -- Check if mouse is hovering over any asteroid with resources
      for _, a in ipairs(world:getEntitiesWithComponents("mineable")) do
        local m = a.components and a.components.mineable
        local pos = a.components and a.components.position
        if m and (m.resources or 0) > 0 and pos then
          local dx, dy = worldMouseX - pos.x, worldMouseY - pos.y
          local dist = math.sqrt(dx*dx + dy*dy)
          local hoverRadius = (a.components.collidable and a.components.collidable.radius or 30) + 10
          if dist <= hoverRadius then
            best, bestType = a, 'asteroid'
            break -- Take the first one found (they shouldn't overlap much)
          end
        end
      end

      -- If no asteroid found, check salvageable wreckage
      if not best then
        for _, w in ipairs(world:getEntitiesWithComponents("wreckage")) do
          local pos = w.components and w.components.position
          local canSalvage = (w.canBeSalvaged and w:canBeSalvaged())
            or (w.salvageAmount and w.salvageAmount > 0)
            or (w.components and w.components.lootable and #w.components.lootable.drops > 0)
          if pos and canSalvage then
            local dx, dy = worldMouseX - pos.x, worldMouseY - pos.y
            local dist = math.sqrt(dx*dx + dy*dy)
            local hoverRadius = (w.components.collidable and w.components.collidable.radius or 20) + 8
            if dist <= hoverRadius then
              best, bestType = w, 'wreckage'
              break
            end
          end
        end
      end

      if best then
        local bx = best.components.position.x
        local by = best.components.position.y
        local screenX = (bx - camX) * camScale + sw * 0.5
        local screenY = (by - camY) * camScale + sh * 0.5
        if screenX > 0 and screenX < sw and screenY > 0 and screenY < sh then
          local text, canPerformAction
          -- Helper to find the hotbar key for the first turret of a given kind
          local function findKeyForTurretKind(kind)
            if not player or not player.components or not player.components.equipment then return nil end
            local slotNum = nil
            for _, td in ipairs(player.components.equipment.turrets) do
              if td and td.turret and td.turret.kind == kind then slotNum = td.slot break end
            end
            if not slotNum then return nil end
            local HotbarSystem = require("src.systems.hotbar")
            local Settings = require("src.core.settings")
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
          if bestType == 'asteroid' then
            if hasRequiredTurret(player, "mining_laser") then
              local key = findKeyForTurretKind('mining_laser')
              text = string.format("Press [%s] to Mine", labelForKey(key))
              canPerformAction = true
            else
              text = "Install a Mining Laser"
              canPerformAction = false
            end
          else -- wreckage
            if hasRequiredTurret(player, "salvaging_laser") then
              local key = findKeyForTurretKind('salvaging_laser')
              text = string.format("Press [%s] to Salvage", labelForKey(key))
              canPerformAction = true
            else
              text = "Install a Salvaging Laser"
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


  -- Draw modular HUD components
  StatusBars.draw(player)
  -- Toggle OS cursor when over UI; hide reticle in that case
  local UIManager = require("src.core.ui_manager")
  local overUI = UIManager.isMouseOverUI and UIManager.isMouseOverUI() or false
  if love and love.mouse and love.mouse.setVisible then love.mouse.setVisible(overUI) end
  if not overUI then
    Reticle.draw(player)
  end
  Minimap.draw(player, world, enemies, hub, wreckage, lootDrops, remotePlayers, world:getEntitiesWithComponents("mineable"))
  Hotbar.draw(player)
  
  -- Skills panel
  local SkillsPanel = require("src.ui.skills")
  SkillsPanel.draw()

end

function UI.hotbarMousePressed(player, mx, my, button)
  return Hotbar.mousepressed(player, mx, my, button)
end

-- Export drawTurretIcon from Hotbar for backward compatibility
UI.drawTurretIcon = Hotbar.drawTurretIcon

return UI
