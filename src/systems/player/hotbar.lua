local Hotbar = require("src.systems.hotbar")

local PlayerHotbar = {}

local function ensure_state()
  Hotbar.state = Hotbar.state or {}
  Hotbar.state.active = Hotbar.state.active or {}
  Hotbar.state.active.turret_slots = Hotbar.state.active.turret_slots or {}
  Hotbar.state.active.ability_slots = Hotbar.state.active.ability_slots or {}
end

function PlayerHotbar.populate(player, newModuleId, slotNum)
  if not player then return end
  if Hotbar.populateFromPlayer then
    Hotbar.populateFromPlayer(player, newModuleId, slotNum)
  end
end

function PlayerHotbar.clearAssignments()
  ensure_state()
  Hotbar.state.active.turret_slots = {}
  Hotbar.state.active.ability_slots = {}
end

return PlayerHotbar
