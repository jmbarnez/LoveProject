local Debug = require("src.core.debug")
local Log = {}

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
local LABELS_BY_VALUE = {}
for name, value in pairs(LEVELS) do
  LABELS_BY_VALUE[value] = name
end

-- Default to info level for production; can be changed via Log.setLevel
local current = LEVELS.info
Log._infoEnabled = true
Log._whitelist = nil

local function resolveLevel(level)
  if type(level) == 'string' then
    local normalized = level:lower()
    return LEVELS[normalized]
  elseif type(level) == 'number' then
    for _, value in pairs(LEVELS) do
      if value == level then
        return value
      end
    end
  end
  return nil
end

function Log.setLevel(level)
  local resolved = resolveLevel(level)
  if resolved then
    current = resolved
  end
end

function Log.getLevel()
  return current
end

function Log.getLevelName()
  return LABELS_BY_VALUE[current] or 'unknown'
end

function Log.isLevelEnabled(level)
  local resolved = resolveLevel(level)
  if not resolved then return false end
  return current <= resolved
end

function Log.setDebugWhitelist(list)
  Log._whitelist = nil
  if type(list) == 'table' and #list > 0 then
    Log._whitelist = {}
    for _, value in ipairs(list) do
      if type(value) == 'string' and value ~= '' then
        Log._whitelist[#Log._whitelist + 1] = value
      end
    end
  end
end

function Log.clearDebugWhitelist()
  Log._whitelist = nil
end

function Log.setInfoEnabled(enabled)
  if enabled == nil then
    Log._infoEnabled = true
  else
    Log._infoEnabled = not not enabled
  end
end

function Log.isInfoEnabled()
  return Log._infoEnabled
end

local function startsWith(str, prefix)
  if type(str) ~= 'string' or type(prefix) ~= 'string' then return false end
  return str:sub(1, #prefix) == prefix
end

local function out(prefix, ...)
  local parts = { ... }
  for i = 1, #parts do
    parts[i] = tostring(parts[i])
  end
  local line = string.format('[%s] %s', prefix, table.concat(parts, ' '))
  print(line)
end

function Log.debug(flag, ...)
  if not Log.isLevelEnabled('debug') then return end
  if Log._whitelist and #Log._whitelist > 0 then
    local first = select(1, ...)
    if type(first) ~= 'string' then return end
    local allowed = false
    for _, prefix in ipairs(Log._whitelist) do
      if startsWith(first, prefix) then
        allowed = true
        break
      end
    end
    if not allowed then return end
  end
  
  -- Use debug system if flag is provided, otherwise use legacy format
  if flag and type(flag) == 'string' then
    Debug.debug(flag, ...)
  else
    out('DEBUG', ...)
  end
end

function Log.info(...)
  if not Log._infoEnabled then return end
  if Log.isLevelEnabled('info') then
    out('INFO', ...)
  end
end

function Log.warn(...)
  if Log.isLevelEnabled('warn') then
    out('WARN', ...)
  end
end

function Log.error(...)
  out('ERROR', ...)
end

return Log
