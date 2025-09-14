local DesignLoader = {}

-- Strict require: raise a clear error if module cannot be loaded or returns an invalid value
local function require_strict(name)
  local ok, mod = pcall(require, name)
  if not ok then
    error("DesignLoader: failed to require '" .. tostring(name) .. "' -> " .. tostring(mod))
  end
  if type(mod) ~= "table" then
    error("DesignLoader: module '" .. tostring(name) .. "' did not return a table")
  end
  return mod
end

-- Lists Lua module names under a directory using love.filesystem
-- dir: e.g. "content/ships"; modulePrefix: e.g. "content.ships"
local function list_modules(dir, modulePrefix)
  if not love or not love.filesystem or not love.filesystem.getDirectoryItems then
    error("DesignLoader: love.filesystem not available while listing '" .. dir .. "'")
  end
  if not love.filesystem.getInfo(dir) then
    error("DesignLoader: required content directory missing: '" .. dir .. "'")
  end
  local items = love.filesystem.getDirectoryItems(dir)
  table.sort(items)
  local mods = {}
  for _, item in ipairs(items) do
    -- Only plain .lua files, skip index.lua
    if item:sub(-4) == ".lua" and item ~= "index.lua" then
      local base = item:sub(1, -5) -- strip .lua
      table.insert(mods, modulePrefix .. "." .. base)
    end
  end
  if #mods == 0 then
    error("DesignLoader: no modules found in '" .. dir .. "'")
  end
  return mods
end

-- Public: discover item, ship, turret, projectile, and world object definitions.
function DesignLoader.discover()
  local itemDefs, shipDefs, turretDefs, projectileDefs, worldObjectDefs = {}, {}, {}, {}, {}

  -- Items
  for _, modName in ipairs(list_modules("content/items", "content.items")) do
    local def = require_strict(modName)
    table.insert(itemDefs, def)
  end

  -- Ships
  for _, modName in ipairs(list_modules("content/ships", "content.ships")) do
    local def = require_strict(modName)
    table.insert(shipDefs, def)
  end

  -- Turrets
  for _, modName in ipairs(list_modules("content/turrets", "content.turrets")) do
    local def = require_strict(modName)
    table.insert(turretDefs, def)
  end

  -- Projectiles
  for _, modName in ipairs(list_modules("content/projectiles", "content.projectiles")) do
    local def = require_strict(modName)
    table.insert(projectileDefs, def)
  end

  -- World Objects
  for _, modName in ipairs(list_modules("content/world_objects", "content.world_objects")) do
    local def = require_strict(modName)
    table.insert(worldObjectDefs, def)
  end

  return itemDefs, shipDefs, turretDefs, projectileDefs, worldObjectDefs
end

return DesignLoader
