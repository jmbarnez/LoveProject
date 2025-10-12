local Events = require("src.core.events")
local DockedUI = require("src.ui.docked")
local PlayerHotbar = require("src.systems.player.hotbar")

local Docking = {}

local function get_docking(player)
  return player and player.components and player.components.docking_status
end

local function get_state(player)
  return player and player.components and player.components.player_state
end

function Docking.dock(player, station)
  local docking = get_docking(player)
  if not docking then return end

  docking.docked = true
  docking.docked_station = station
  docking.can_dock = false
  docking.nearby_station = nil

  local state = get_state(player)
  if state then
    state.move_target = nil
  end

  if player.components and player.components.physics and player.components.physics.body then
    player.components.physics.body.vx = 0
    player.components.physics.body.vy = 0
  end

  -- Instant shield recharge when docking
  if player.components and player.components.hull then
    local hull = player.components.hull
    local shield = player.components.shield
    if shield and shield.maxShield and shield.maxShield > 0 then
      shield.shield = shield.maxShield  -- Full shield recharge
      
      -- Trigger shield recharge visual effect
      local Effects = require("src.systems.effects")
      local pos = player.components.position
      if pos and Effects.spawnImpact then
        local shieldRadius = require("src.systems.collision.radius").getShieldRadius(player)
        Effects.spawnImpact('shield', pos.x, pos.y, shieldRadius, pos.x, pos.y, 0, nil, 'recharge', player, true)
      end
    end
  end

  DockedUI.show(player, station)
  PlayerHotbar.clearAssignments()
  Events.emit(Events.GAME_EVENTS.PLAYER_DOCKED, { player = player, station = station })
end

function Docking.undock(player)
  local docking = get_docking(player)
  if not docking then return end

  docking.docked = false
  docking.docked_station = nil
  docking.nearby_station = nil

  DockedUI.hide()
  PlayerHotbar.clearAssignments()
  
  -- Ensure UI state is properly updated
  local UIState = require("src.core.ui.state")
  UIState.close("docked")
  
  -- Force modal handler to update
  local UIModalHandler = require("src.core.ui.modal_handler")
  UIModalHandler.update()
  
  Events.emit(Events.GAME_EVENTS.PLAYER_UNDOCKED, { player = player })
end

return Docking
