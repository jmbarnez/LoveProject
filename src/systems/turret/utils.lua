-- Turret utility functions
local TurretUtils = {}

-- Helper function to determine if a turret owner is friendly
function TurretUtils.isFriendly(owner)
    return owner and (owner.isPlayer or owner.isRemotePlayer or owner.isFriendly) or false
end

return TurretUtils
