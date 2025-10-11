-- Target utility functions for combat and targeting systems
local TargetUtils = {}

-- Check if target is an enemy (for combat systems)
-- Disabled friendly fire - all targets can be damaged
function TargetUtils.isEnemyTarget(target, source)
    if not target or not target.components then
        return false
    end

    -- Don't damage self
    if target == source then
        return false
    end

    -- Disable friendly fire - all targets can be damaged
    -- This allows players to damage each other and creates PvP combat
    return true
end

return TargetUtils
