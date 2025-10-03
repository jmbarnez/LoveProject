local Events = require("src.core.events")

local InputIntentsSystem = {}

local intentState = {
  moveX = 0,
  moveY = 0,
  forward = false,
  reverse = false,
  strafeLeft = false,
  strafeRight = false,
  boost = false,
  brake = false,
  anyMovement = false,
  modalActive = false,
  player = nil,
}

local function resetIntent(player, modalActive)
  intentState.player = player
  intentState.modalActive = modalActive or false
  intentState.moveX = 0
  intentState.moveY = 0
  intentState.forward = false
  intentState.reverse = false
  intentState.strafeLeft = false
  intentState.strafeRight = false
  intentState.boost = false
  intentState.brake = false
  intentState.anyMovement = false
end

local function pollKey(key)
  return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown(key) or false
end

function InputIntentsSystem.update(dt, player, uiManager)
  if not player then
    return
  end

  local modalActive = uiManager and uiManager.isModalActive and uiManager.isModalActive() or false
  local blocked = modalActive or player.docked or player.dead or player.frozen

  if blocked then
    resetIntent(player, modalActive)
    Events.emit(Events.GAME_EVENTS.PLAYER_INTENT, intentState)
    return
  end

  local forward = pollKey("w")
  local reverse = pollKey("s")
  local strafeLeft = pollKey("a")
  local strafeRight = pollKey("d")
  local boost = pollKey("lshift") or pollKey("rshift")
  local brake = pollKey("space")

  local ix, iy = 0, 0
  if forward then iy = iy - 1 end
  if reverse then iy = iy + 1 end
  if strafeLeft then ix = ix - 1 end
  if strafeRight then ix = ix + 1 end

  local mag = math.sqrt(ix * ix + iy * iy)
  if mag > 0 then
    ix, iy = ix / mag, iy / mag
  else
    ix, iy = 0, 0
  end

  intentState.player = player
  intentState.modalActive = modalActive
  intentState.moveX = ix
  intentState.moveY = iy
  intentState.forward = forward
  intentState.reverse = reverse
  intentState.strafeLeft = strafeLeft
  intentState.strafeRight = strafeRight
  intentState.boost = boost
  intentState.brake = brake
  intentState.anyMovement = forward or reverse or strafeLeft or strafeRight

  Events.emit(Events.GAME_EVENTS.PLAYER_INTENT, intentState)
end

return InputIntentsSystem
