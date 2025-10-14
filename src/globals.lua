-- Global variable declarations for linter
-- This file helps the linter understand Love2D and project-specific globals

-- Love2D Framework globals
love = love or {}

-- Project-specific globals
world = world or {}
Constants = Constants or {}
serialize = serialize or {}
sx = sx or 1
sy = sy or 1
health = health or {}
damage = damage or {}
Geometry = Geometry or {}
enet = enet or {}
drawShieldIcon = drawShieldIcon or function() end

-- This file should not be required in the actual game
-- It's only for linter support
