local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Log = require("src.core.log")

local Minimap = {}

-- Debug log to verify enemies passed to minimap
function Minimap.draw(player, world, enemies, hub, wreckage, lootDrops, remotePlayers, asteroids, remotePlayerSnapshots)


  local sw, sh = Viewport.getDimensions()
  local s = math.min(sw / 1920, sh / 1080)
  local w, h = math.floor(220 * s), math.floor(160 * s)
  local pad = math.floor(16 * s)
  local x, y = sw - w - pad, pad
  local time = love.timer.getTime()
  
  -- EVE-style minimap background with glow
  Theme.drawGradientGlowRect(x, y, w, h, 8,
    Theme.colors.bg1, Theme.colors.bg0,
    Theme.colors.primary, Theme.effects.glowWeak)
  
  -- Animated scan border (EVE style)
  local pulseColor = Theme.pulseColor(Theme.colors.primary, Theme.colors.accent, time)
  Theme.drawEVEBorder(x + 4, y + 4, w - 8, h - 8, 6, pulseColor, 8)
  
  -- Grid overlay for tech aesthetic
  Theme.setColor(Theme.withAlpha(Theme.colors.border, 0.2))
  local gridSize = 16
  for i = 1, math.floor((w - 8) / gridSize) do
    local gx = x + 4 + i * gridSize
    love.graphics.line(gx, y + 4, gx, y + h - 4)
  end
  for i = 1, math.floor((h - 8) / gridSize) do
    local gy = y + 4 + i * gridSize
    love.graphics.line(x + 4, gy, x + w - 4, gy)
  end
  
  -- Map entities with EVE colors
  local mw, mh = w - 16, h - 16
  local sx = mw / world.width
  local sy = mh / world.height
  local ox, oy = x + 8, y + 8

  -- Station blips (green with glow for all station types)
  local stations = world:get_entities_with_components("station")
  for _, station in ipairs(stations) do
    if station.components and station.components.position then
      local stationId = station.components.station and station.components.station.type
      local stationX, stationY = ox + station.components.position.x * sx, oy + station.components.position.y * sy

      -- Different station types get slightly different visual markers
      if stationId == "hub_station" then
        -- Hub station: larger green circle with stronger glow
        Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
        love.graphics.circle("fill", stationX, stationY, 8)
        Theme.setColor(Theme.colors.success)
        love.graphics.circle("fill", stationX, stationY, 4)
      elseif stationId == "beacon_station" then
        -- Beacon station: green diamond with glow
        Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
        love.graphics.polygon("fill", stationX, stationY - 6, stationX + 6, stationY, stationX, stationY + 6, stationX - 6, stationY)
        Theme.setColor(Theme.colors.success)
        love.graphics.polygon("fill", stationX, stationY - 3, stationX + 3, stationY, stationX, stationY + 3, stationX - 3, stationY)
      else
        -- Generic station: standard green circle
        Theme.setColor(Theme.withAlpha(Theme.colors.success, 0.4))
        love.graphics.circle("fill", stationX, stationY, 6)
        Theme.setColor(Theme.colors.success)
        love.graphics.circle("fill", stationX, stationY, 3)
      end
    end
  end

  -- Warp gate blips (blue hexagons with glow)
  local warp_gates = world:get_entities_with_components("warp_gate")
  for _, warp_gate in ipairs(warp_gates) do
    if warp_gate.components and warp_gate.components.position then
      local gateX, gateY = ox + warp_gate.components.position.x * sx, oy + warp_gate.components.position.y * sy
      local isActive = warp_gate.components.warp_gate and warp_gate.components.warp_gate.isActive

      if isActive then
        -- Active warp gate: bright blue hexagon with glow
        Theme.setColor(Theme.withAlpha({0.2, 0.6, 1.0}, 0.6))
        love.graphics.circle("fill", gateX, gateY, 8)
        Theme.setColor({0.4, 0.8, 1.0})

        -- Draw hexagon
        local hex_radius = 5
        local hex_vertices = {}
        for i = 0, 5 do
          local angle = (i / 6) * math.pi * 2
          table.insert(hex_vertices, gateX + math.cos(angle) * hex_radius)
          table.insert(hex_vertices, gateY + math.sin(angle) * hex_radius)
        end
        love.graphics.polygon("fill", hex_vertices)
      else
        -- Inactive warp gate: gray hexagon
        Theme.setColor({0.4, 0.4, 0.4})
        local hex_radius = 4
        local hex_vertices = {}
        for i = 0, 5 do
          local angle = (i / 6) * math.pi * 2
          table.insert(hex_vertices, gateX + math.cos(angle) * hex_radius)
          table.insert(hex_vertices, gateY + math.sin(angle) * hex_radius)
        end
        love.graphics.polygon("fill", hex_vertices)
      end
    end
  end

  -- Wreckage blips (amber squares with glow)
  if wreckage then
    for _, piece in ipairs(wreckage) do
      local px = (piece.components and piece.components.position and piece.components.position.x) or piece.x
      local py = (piece.components and piece.components.position and piece.components.position.y) or piece.y
      if px and py then
        local wx, wy = ox + px * sx, oy + py * sy
        Theme.setColor(Theme.withAlpha(Theme.colors.warning, 0.3))
        love.graphics.rectangle("fill", wx - 3, wy - 3, 6, 6)
        Theme.setColor(Theme.colors.warning)
        love.graphics.rectangle("fill", wx - 1.5, wy - 1.5, 3, 3)
      end
    end
  end

  -- Asteroid blips (small gray dots)
  if asteroids then
    for _, asteroid in ipairs(asteroids) do
      local ax = (asteroid.components and asteroid.components.position and asteroid.components.position.x) or asteroid.x
      local ay = (asteroid.components and asteroid.components.position and asteroid.components.position.y) or asteroid.y
      if ax and ay then
        local astx, asty = ox + ax * sx, oy + ay * sy
        Theme.setColor(Theme.withAlpha({0.6, 0.6, 0.6}, 0.8))
        love.graphics.circle("fill", astx, asty, 1.5)
      end
    end
  end

  -- Loot blips (blue diamonds with glow)
  if lootDrops then
    for _, drop in ipairs(lootDrops) do
      local dx, dy = ox + drop.x * sx, oy + drop.y * sy
      Theme.setColor(Theme.withAlpha(Theme.colors.info, 0.4))
      love.graphics.polygon("fill", dx, dy - 4, dx + 3, dy, dx, dy + 4, dx - 3, dy)
      Theme.setColor(Theme.colors.info)
      love.graphics.polygon("fill", dx, dy - 2.5, dx + 2, dy, dx, dy + 2.5, dx - 2, dy)
    end
  end
  
  -- Enemy blips; bosses get a unique marker
  for _, e in ipairs(enemies) do
    local exComp = e and e.components and e.components.position and e.components.position.x
    local eyComp = e and e.components and e.components.position and e.components.position.y
    local exRaw = (e and e.x) or nil
    local eyRaw = (e and e.y) or nil
    local exVal = exComp or exRaw
    local eyVal = eyComp or eyRaw
    if exVal and eyVal then
      local exScreen, eyScreen = ox + exVal * sx, oy + eyVal * sy
      if e.isBoss or e.shipId == 'boss_drone' then
        -- Boss: bright red diamond with halo
        Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.45))
        love.graphics.circle('fill', exScreen, eyScreen, 7)
        Theme.setColor(Theme.colors.danger)
        love.graphics.polygon('fill', exScreen, eyScreen - 5, exScreen + 5, eyScreen, exScreen, eyScreen + 5, exScreen - 5, eyScreen)
      else
        -- Regular enemy: red square with subtle glow
        Theme.setColor(Theme.withAlpha(Theme.colors.danger, 0.5))
        love.graphics.rectangle("fill", exScreen - 3, eyScreen - 3, 6, 6)
        Theme.setColor(Theme.colors.danger)
        love.graphics.rectangle("fill", exScreen - 1.5, eyScreen - 1.5, 3, 3)
      end
    else
      -- Skip entities without a valid position
    end
  end
  
  -- Remote player blips (blue with glow)
  local drawnRemote = {}
  local function drawRemoteBlip(worldX, worldY, key)
    if not worldX or not worldY then
      return
    end
    if key then
      if drawnRemote[key] then
        return
      end
      drawnRemote[key] = true
    end
    local rx, ry = ox + worldX * sx, oy + worldY * sy
    Theme.setColor(Theme.withAlpha(Theme.colors.info, 0.4))
    love.graphics.circle("fill", rx, ry, 6)
    Theme.setColor(Theme.colors.info)
    love.graphics.circle("fill", rx, ry, 3)
  end

  if remotePlayers then
    for id, remotePlayer in pairs(remotePlayers) do
      local pos = remotePlayer and remotePlayer.components and remotePlayer.components.position
      if pos then
        drawRemoteBlip(pos.x, pos.y, remotePlayer.remotePlayerId or id)
      end
    end
  end

  if remotePlayerSnapshots then
    for id, snapshot in pairs(remotePlayerSnapshots) do
      local pos = snapshot and (snapshot.position or (snapshot.data and snapshot.data.position))
      if pos then
        drawRemoteBlip(pos.x, pos.y, snapshot.playerId or id)
      end
    end
  end

  -- Reward crate blips (bright green with glow) - only visible in debug mode
  local DebugPanel = require("src.ui.debug_panel")
  if DebugPanel.isVisible() then
    local rewardCrates = world:get_entities_with_components("interactable")
    for _, crate in ipairs(rewardCrates) do
      if crate.components and crate.components.position and crate.components.renderable and crate.components.renderable.type == "reward_crate" then
        local crateX, crateY = ox + crate.components.position.x * sx, oy + crate.components.position.y * sy
        -- Bright green glow for reward crates
        Theme.setColor(Theme.withAlpha({0.0, 1.0, 0.0}, 0.6)) -- Bright green with alpha
        love.graphics.circle("fill", crateX, crateY, 8)
        -- Main bright green blip
        Theme.setColor({0.0, 1.0, 0.0}) -- Pure bright green
        love.graphics.circle("fill", crateX, crateY, 4)
        -- Add a small cross to make it more distinctive
        Theme.setColor({0.0, 0.8, 0.0}) -- Slightly darker green for cross
        love.graphics.setLineWidth(2)
        love.graphics.line(crateX - 3, crateY, crateX + 3, crateY)
        love.graphics.line(crateX, crateY - 3, crateX, crateY + 3)
        love.graphics.setLineWidth(1)
      end
    end
  end
  
  -- Player blip with dynamic pulse
  local playerColor = Theme.shimmerColor(Theme.colors.accent, time, 0.3)
  Theme.setColor(playerColor)
  love.graphics.rectangle("fill", ox + player.components.position.x * sx - 2.5, oy + player.components.position.y * sy - 2.5, 5, 5)
  
  -- Real-world time display underneath minimap
  local timeY = y + h + math.floor(8 * s) -- 8 pixels below minimap
  local currentTime = os.date("%H:%M:%S") -- 24-hour format

  -- Use smaller font for time
  local oldFont = love.graphics.getFont()
  local font = Theme.fonts and Theme.fonts.xsmall or oldFont
  love.graphics.setFont(font)

  local timeText = currentTime
  local textWidth = font:getWidth(timeText)
  local textHeight = font:getHeight()

  -- Center the time text under the minimap
  local timeX = x + (w - textWidth) / 2

  -- Semi-transparent background for better readability
  Theme.setColor(Theme.withAlpha(Theme.colors.bg0, 0.7))
  love.graphics.rectangle("fill", timeX - 4, timeY - 2, textWidth + 8, textHeight + 4, 4)

  -- Draw the time text
  Theme.setColor(Theme.colors.textSecondary)
  love.graphics.print(timeText, timeX, timeY)

  -- Restore original font
  if oldFont then love.graphics.setFont(oldFont) end
end

return Minimap
