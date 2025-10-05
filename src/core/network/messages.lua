local Messages = {}

Messages.TYPES = {
    HELLO = "hello",
    WELCOME = "welcome",
    STATE = "state",
    GOODBYE = "goodbye",
    PING = "ping",
    PONG = "pong",
    WORLD_SNAPSHOT = "world_snapshot"
}

function Messages.encode(payload)
    local json = require("src.libs.json")
    return json.encode(payload)
end

function Messages.decode(data)
    local json = require("src.libs.json")
    local ok, value = pcall(json.decode, data)
    if ok then
        return value
    end
    return nil
end

return Messages
