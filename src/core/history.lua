local History = {}
History.__index = History

local function shallowCopy(t)
  local r = {}
  for k, v in pairs(t or {}) do r[k] = v end
  return r
end

function History.new(capacity)
  local self = setmetatable({}, History)
  self.capacity = capacity or 200
  self.past = {}
  self.future = {}
  return self
end

-- Push a snapshot onto the past stack and clear the future (new branch)
function History:push(state)
  if not state then return end
  table.insert(self.past, shallowCopy(state))
  self.future = {}
  -- Enforce capacity
  while #self.past > self.capacity do
    table.remove(self.past, 1)
  end
end

-- Undo: move last past state to future and return it
function History:undo()
  if #self.past == 0 then return nil end
  local s = table.remove(self.past)
  table.insert(self.future, s)
  return shallowCopy(s)
end

-- Redo: pop from future
function History:redo()
  if #self.future == 0 then return nil end
  local s = table.remove(self.future)
  table.insert(self.past, s)
  return shallowCopy(s)
end

return History
