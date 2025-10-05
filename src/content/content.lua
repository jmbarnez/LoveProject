local Item = require("src.templates.item")
local Log = require("src.core.log")
local DesignLoader = require("src.content.design_loader")
local IconRenderer = require("src.content.icon_renderer")
local Validator = require("src.content.validator")
local Normalizer = require("src.content.normalizer")

local Content = {
  items = {},
  ships = {},
  turrets = {},
  projectiles = {},
  worldObjects = {},
  byId = { item = {}, ship = {}, turret = {}, projectile = {}, worldObject = {} },
  images = {}, -- Cache for loaded images
}

function Content.load()
  -- Clear icon cache to ensure fresh rendering
  if IconRenderer.clearCache then
    IconRenderer.clearCache()
  end
  
  -- Try auto-discovery first (preferred for easy content drops)
  local discoveredItems, discoveredShips, discoveredTurrets, discoveredWorldObjects = DesignLoader.discover()

  local items = discoveredItems
  local ships = discoveredShips
  local turrets = discoveredTurrets
  local projectiles = {} -- Projectiles are now embedded in turrets, so this is empty
  local worldObjects = discoveredWorldObjects

  -- No legacy fallback: content must be discovered via files

  -- Items
  for _, def in ipairs(items or {}) do
    Validator.item(def)
    local item = Item.fromDef(def)
    table.insert(Content.items, item)
    if item and item.id then
      Content.byId.item[item.id] = item
    end
  end

  -- Generate icons for items
  for _, item in ipairs(Content.items) do
    if item.icon and type(item.icon) == "table" and item.icon.shapes then
      item.iconDef = item.icon
      item.icon = IconRenderer.renderIcon(item.iconDef, 128, item.id)
    end
  end

  -- Ships (store normalized defs)
  for _, def in ipairs(ships or {}) do
    Validator.ship(def)
    local ndef = Normalizer.normalizeShip(def)
    table.insert(Content.ships, ndef)
    if ndef and ndef.id then
      Content.byId.ship[ndef.id] = ndef
    end
  end

  -- Generate icons for ships
  for _, ship in ipairs(Content.ships) do
    if ship.icon and type(ship.icon) == "table" and ship.icon.shapes then
      ship.iconDef = ship.icon
      ship.icon = IconRenderer.renderIcon(ship.iconDef, 128, ship.id)
    end
  end

  -- Turrets (raw defs)
  for _, def in ipairs(turrets or {}) do
    Validator.turret(def)
    table.insert(Content.turrets, def)
    if def and def.id then
      Content.byId.turret[def.id] = def
      Log.debug("Loaded turret: " .. def.id .. " (" .. (def.name or "unnamed") .. ")")
      
      -- Extract embedded projectile definition if it exists
      if def.projectile and type(def.projectile) == "table" then
        local projectileDef = def.projectile
        Validator.projectile(projectileDef)
        local ndef = Normalizer.normalizeProjectile(projectileDef)
        table.insert(Content.projectiles, ndef)
        if ndef and ndef.id then
          Content.byId.projectile[ndef.id] = ndef
          Log.debug("Extracted projectile from turret: " .. ndef.id)
        end
      end
      
      if def.module then
        local item = Item.fromDef(def)
        table.insert(Content.items, item)
        Content.byId.item[item.id] = item
      end
    end
  end
  
  Log.debug("Total turrets loaded: " .. #Content.turrets)

  -- Generate icons for turrets
  for _, turret in ipairs(Content.turrets) do
    if turret.icon and type(turret.icon) == "table" and turret.icon.shapes then
      turret.iconDef = turret.icon
      turret.icon = IconRenderer.renderIcon(turret.iconDef, 128, turret.id)
    end
  end

  -- Ensure module items injected from turret defs receive rendered icons
  for _, item in ipairs(Content.items) do
    if item.icon and type(item.icon) == "table" and item.icon.shapes then
      item.iconDef = item.icon
      item.icon = IconRenderer.renderIcon(item.iconDef, 128, item.id)
    elseif item.iconDef and type(item.iconDef) == "table" and (not item.icon or type(item.icon) ~= "userdata") then
      item.icon = IconRenderer.renderIcon(item.iconDef, 128, item.id)
    end
  end

  -- Projectiles (store normalized defs)
  for _, def in ipairs(projectiles or {}) do
    Validator.projectile(def)
    local ndef = Normalizer.normalizeProjectile(def)
    table.insert(Content.projectiles, ndef)
    if ndef and ndef.id then
      Content.byId.projectile[ndef.id] = ndef
    end
  end

  -- World Objects (store normalized defs)
  for _, def in ipairs(worldObjects or {}) do
    Validator.worldObject(def)
    local ndef = Normalizer.normalizeWorldObject(def)
    table.insert(Content.worldObjects, ndef)
    if ndef and ndef.id then
      Content.byId.worldObject[ndef.id] = ndef
    end
  end
end

-- Rebuild canvased icons after a graphics context change (e.g., settings apply)
function Content.rebuildIcons()
  local IconRenderer = require("src.content.icon_renderer")
  -- Items
  for _, item in ipairs(Content.items or {}) do
    if item and item.def and type(item.def.icon) == "table" and item.def.icon.shapes then
      item.icon = IconRenderer.renderIcon(item.def.icon, 128, item.id)
    elseif item and item.iconDef and type(item.iconDef) == "table" and item.iconDef.shapes then
      item.icon = IconRenderer.renderIcon(item.iconDef, 128, item.id)
    end
  end
  -- Ships
  for _, ship in ipairs(Content.ships or {}) do
    if ship and ship.icon and ship.id and type(ship.icon) ~= "userdata" and type(ship.icon) == "table" and ship.icon.shapes then
      -- If ship.icon kept the def table, render it now; otherwise try ship.iconDef
      ship.icon = IconRenderer.renderIcon(ship.icon, 128, ship.id)
    elseif ship and ship.iconDef and type(ship.iconDef) == "table" then
      ship.icon = IconRenderer.renderIcon(ship.iconDef, 128, ship.id)
    end
  end
  -- Turrets
  for _, turret in ipairs(Content.turrets or {}) do
    if turret and turret.icon and turret.id and type(turret.icon) ~= "userdata" and type(turret.icon) == "table" and turret.icon.shapes then
      turret.icon = IconRenderer.renderIcon(turret.icon, 128, turret.id)
    elseif turret and turret.iconDef and type(turret.iconDef) == "table" then
      turret.icon = IconRenderer.renderIcon(turret.iconDef, 128, turret.id)
    end
  end
end

function Content.getItem(id)
  return Content.byId.item[id]
end

function Content.getShip(id)
  return Content.byId.ship[id]
end

function Content.getTurret(id)
  return Content.byId.turret[id]
end

function Content.getProjectile(id)
  return Content.byId.projectile[id]
end

function Content.getWorldObject(id)
  return Content.byId.worldObject[id]
end

-- New function to get and cache images
function Content.getImage(path)
    if Content.images[path] then
        return Content.images[path]
    end

    local fullPath = "content/" .. path
    local ok, img = pcall(love.graphics.newImage, fullPath)
    if ok then
        Content.images[path] = img
        return img
    else
        Log.warn("Could not load image", fullPath)
        return nil
    end
end

return Content
