local PlayerState = {}

function PlayerState.new(initial)
  initial = initial or {}
  return {
    is_player = true,
    move_target = initial.move_target or nil,
    weapons_disabled = initial.weapons_disabled or false,
    was_in_hub = initial.was_in_hub or false,
    thruster_state = initial.thruster_state or {
      forward = 0,
      reverse = 0,
      strafeLeft = 0,
      strafeRight = 0,
      boost = 0,
      brake = 0,
      isThrusting = false,
    },
    dash_cooldown = initial.dash_cooldown or 0,
    shield_active = initial.shield_active or false,
    target = initial.target or nil,
    target_type = initial.target_type or "enemy",
    can_warp = initial.can_warp or false,
    was_in_warp_range = initial.was_in_warp_range or false,
  }
end

return PlayerState
