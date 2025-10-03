local DockingStatus = {}

function DockingStatus.new(initial)
  initial = initial or {}
  return {
    docked = initial.docked or false,
    can_dock = initial.can_dock or false,
    nearby_station = initial.nearby_station or nil,
    docked_station = initial.docked_station or nil,
  }
end

return DockingStatus
