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

  if player.components and player.components.health then
    local h = player.components.health
    h.shield = h.maxShield or h.shield
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
  Events.emit(Events.GAME_EVENTS.PLAYER_UNDOCKED, { player = player })
end

return Docking
