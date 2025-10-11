-- Simple module to hold reference to current player
local PlayerRef = {}

PlayerRef.current = nil

function PlayerRef.set(player)
  PlayerRef.current = player
end

function PlayerRef.get()
  return PlayerRef.current
end

return PlayerRef