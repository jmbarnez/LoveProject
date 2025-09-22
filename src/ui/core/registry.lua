local Registry = {}

local componentsById = {}

-- Register or replace a UI component. The component should implement:
-- id (string), isVisible() -> bool, getZ() -> number,
-- draw(ctx), update(dt, ctx) [optional],
-- getRect() -> {x,y,w,h} or nil [optional],
-- mousepressed/mousereleased/mousemoved/wheelmoved/keypressed/keyreleased/textinput [optional]
function Registry.register(component)
  assert(component and type(component.id) == "string", "Component must have an id")
  componentsById[component.id] = component
  return component
end

function Registry.unregister(id)
  componentsById[id] = nil
end

function Registry.get(id)
  return componentsById[id]
end

function Registry.all()
  local arr = {}
  for _, comp in pairs(componentsById) do
    table.insert(arr, comp)
  end
  return arr
end

local function visibleComponents()
  local arr = {}
  for _, comp in pairs(componentsById) do
    local ok, visible = pcall(function() return comp.isVisible and comp.isVisible() end)
    if ok and visible then
      table.insert(arr, comp)
    end
  end
  return arr
end

local function sortByZAscending(a, b)
  local za = (a.getZ and a.getZ()) or 0
  local zb = (b.getZ and b.getZ()) or 0
  return za < zb
end

local function sortByZDescending(a, b)
  local za = (a.getZ and a.getZ()) or 0
  local zb = (b.getZ and b.getZ()) or 0
  return (za or 0) > (zb or 0)
end

function Registry.visibleSortedAscending()
  local arr = visibleComponents()
  table.sort(arr, sortByZAscending)
  return arr
end

function Registry.visibleSortedDescending()
  local arr = visibleComponents()
  table.sort(arr, sortByZDescending)
  return arr
end

return Registry


