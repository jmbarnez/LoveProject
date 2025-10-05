local Log = require("src.core.log")

local Messages = {}

Messages.TYPES = {
    HELLO = "hello",
    WELCOME = "welcome",
    STATE = "state",
    GOODBYE = "goodbye",
    PING = "ping",
    PONG = "pong",
    WORLD_SNAPSHOT = "world_snapshot",
    HOST_MIGRATED = "host_migrated",
    ENEMY_UPDATE = "enemy_update",
    PROJECTILE_UPDATE = "projectile_update",
    WEAPON_FIRE_REQUEST = "weapon_fire_request"
}

-- Maximum message size to prevent memory issues
local MAX_MESSAGE_SIZE = 1024 * 1024 -- 1MB

function Messages.encode(payload)
    if not payload or type(payload) ~= "table" then
        return nil
    end

    local json = require("src.libs.json")
    local encoded = json.encode(payload)
    
    if encoded and #encoded > MAX_MESSAGE_SIZE then
        Log.warn("Message too large:", #encoded, "bytes (max:", MAX_MESSAGE_SIZE, ")")
        return nil
    end
    
    return encoded
end

function Messages.decode(data)
    if not data or type(data) ~= "string" then
        return nil
    end

    if #data > MAX_MESSAGE_SIZE then
        Log.warn("Received message too large:", #data, "bytes (max:", MAX_MESSAGE_SIZE, ")")
        return nil
    end

    local json = require("src.libs.json")
    local ok, value = pcall(json.decode, data)
    if ok and value and type(value) == "table" then
        -- Validate message has required type field
        if not value.type or type(value.type) ~= "string" then
            Log.warn("Invalid message: missing or invalid type field")
            return nil
        end
        
        -- Validate message type is known
        local validTypes = {}
        for _, typeName in pairs(Messages.TYPES) do
            validTypes[typeName] = true
        end
        
        if not validTypes[value.type] then
            Log.warn("Unknown message type:", value.type)
            return nil
        end
        
        return value
    end
    
    Log.warn("Failed to decode message:", data and #data or 0, "bytes")
    return nil
end

return Messages
