--[[
  Simple JSON encoder/decoder for Lua
  Lightweight implementation for basic networking needs
]]

local json = {}

-- Encode Lua table to JSON string
function json.encode(obj)
    local objType = type(obj)
    
    if objType == "nil" then
        return "null"
    elseif objType == "boolean" then
        return obj and "true" or "false"
    elseif objType == "number" then
        return tostring(obj)
    elseif objType == "string" then
        return '"' .. obj:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif objType == "table" then
        local isArray = true
        local maxIndex = 0
        
        -- Check if it's an array
        for k, v in pairs(obj) do
            if type(k) ~= "number" or k <= 0 or k ~= math.floor(k) then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        
        if isArray then
            -- Encode as array
            local result = {}
            for i = 1, maxIndex do
                result[i] = json.encode(obj[i])
            end
            return "[" .. table.concat(result, ",") .. "]"
        else
            -- Encode as object
            local result = {}
            for k, v in pairs(obj) do
                table.insert(result, json.encode(tostring(k)) .. ":" .. json.encode(v))
            end
            return "{" .. table.concat(result, ",") .. "}"
        end
    else
        error("Cannot encode type: " .. objType)
    end
end

-- Decode JSON string to Lua table
function json.decode(str)
    local pos = 1
    local len = #str
    
    local function skipWhitespace()
        while pos <= len and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end
    
    local function parseValue()
        skipWhitespace()
        if pos > len then return nil end
        
        local char = str:sub(pos, pos)
        
        if char == '"' then
            -- Parse string
            pos = pos + 1
            local start = pos
            while pos <= len do
                if str:sub(pos, pos) == '"' and str:sub(pos-1, pos-1) ~= '\\' then
                    local result = str:sub(start, pos-1)
                    pos = pos + 1
                    return result:gsub('\\"', '"'):gsub('\\\\', '\\'):gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\t', '\t')
                end
                pos = pos + 1
            end
            error("Unterminated string")
        elseif char == '{' then
            -- Parse object
            pos = pos + 1
            local result = {}
            skipWhitespace()
            
            if pos <= len and str:sub(pos, pos) == '}' then
                pos = pos + 1
                return result
            end
            
            while pos <= len do
                skipWhitespace()
                local key = parseValue()
                skipWhitespace()
                
                if pos > len or str:sub(pos, pos) ~= ':' then
                    error("Expected ':' after key")
                end
                pos = pos + 1
                
                local value = parseValue()
                result[key] = value
                
                skipWhitespace()
                if pos > len then break end
                
                local nextChar = str:sub(pos, pos)
                if nextChar == '}' then
                    pos = pos + 1
                    break
                elseif nextChar == ',' then
                    pos = pos + 1
                else
                    error("Expected ',' or '}' in object")
                end
            end
            return result
        elseif char == '[' then
            -- Parse array
            pos = pos + 1
            local result = {}
            skipWhitespace()
            
            if pos <= len and str:sub(pos, pos) == ']' then
                pos = pos + 1
                return result
            end
            
            while pos <= len do
                local value = parseValue()
                table.insert(result, value)
                
                skipWhitespace()
                if pos > len then break end
                
                local nextChar = str:sub(pos, pos)
                if nextChar == ']' then
                    pos = pos + 1
                    break
                elseif nextChar == ',' then
                    pos = pos + 1
                else
                    error("Expected ',' or ']' in array")
                end
            end
            return result
        elseif char:match("[%d%-]") then
            -- Parse number
            local start = pos
            if char == '-' then pos = pos + 1 end
            while pos <= len and str:sub(pos, pos):match("%d") do
                pos = pos + 1
            end
            if pos <= len and str:sub(pos, pos) == '.' then
                pos = pos + 1
                while pos <= len and str:sub(pos, pos):match("%d") do
                    pos = pos + 1
                end
            end
            return tonumber(str:sub(start, pos-1))
        elseif str:sub(pos, pos+3) == "true" then
            pos = pos + 4
            return true
        elseif str:sub(pos, pos+4) == "false" then
            pos = pos + 5
            return false
        elseif str:sub(pos, pos+3) == "null" then
            pos = pos + 4
            return nil
        else
            error("Unexpected character: " .. char)
        end
    end
    
    return parseValue()
end

return json