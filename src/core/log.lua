local Log = {}

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
-- Default to debug during active debugging; can be lowered via Log.setLevel
local current = LEVELS.debug

function Log.setLevel(level)
  current = LEVELS[level] or current
end

function Log.setDebugWhitelist(list)
  -- list should be an array of string prefixes to allow for debug prints
  Log._whitelist = nil
  if type(list) == 'table' and #list > 0 then
    Log._whitelist = {}
    for _, v in ipairs(list) do
      if type(v) == 'string' then Log._whitelist[#Log._whitelist+1] = v end
    end
  end
end

function Log.setInfoEnabled(enabled)
  Log._infoEnabled = not not enabled
end

local function out(prefix, ...)
  local parts = { ... }
  for i = 1, #parts do parts[i] = tostring(parts[i]) end
  local line = string.format("[%s] %s", prefix, table.concat(parts, " "))
  print(line)
end

function Log.debug(...)
  if current <= LEVELS.debug then
    -- If a debug whitelist is active, only allow messages whose first arg
    -- matches one of the configured prefixes
    if Log._whitelist and #Log._whitelist > 0 then
      local first = select(1, ...)
      if type(first) ~= 'string' then return end
      local allowed = false
      for _, pref in ipairs(Log._whitelist) do
        if first:find(pref, 1, true) then allowed = true break end
      end
      if not allowed then return end
    end
    out("DEBUG", ...)
  end
end

function Log.info(...)
  if not Log._infoEnabled then return end
  if current <= LEVELS.info then out("INFO", ...) end
end

function Log.warn(...)
  if current <= LEVELS.warn then out("WARN", ...) end
end

function Log.error(...)
  out("ERROR", ...)
end

return Log

