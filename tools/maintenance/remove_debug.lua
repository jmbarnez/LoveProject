-- Script to remove debug statements from destruction.lua
local file = io.open("src/systems/destruction.lua", "r")
local content = file:read("*all")
file:close()

-- Remove all Log.debug statements
content = content:gsub("%s*Log%.debug%([^%)]*%);?\n?", "")

-- Write back
file = io.open("src/systems/destruction.lua", "w")
file:write(content)
file:close()

print("Removed debug statements from destruction.lua")
