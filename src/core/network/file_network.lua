--[[
    File-based Network Simulation
    A simple networking solution that uses files for communication
    This allows testing multiplayer functionality without external dependencies
]]

local Log = require("src.core.log")
local json = require("src.libs.json")

local FileNetwork = {}
FileNetwork.__index = FileNetwork

function FileNetwork.new(port, isServer)
    local self = setmetatable({}, FileNetwork)
    
    self.port = port or 7777
    self.isServer = isServer or false
    -- Use port-specific directory to avoid conflicts between different game instances
    self.messageDir = "network_messages_" .. self.port
    self.lastMessageId = 0
    
    -- Create message directory
    local success = love.filesystem.createDirectory(self.messageDir)
    if not success then
        Log.warn("Could not create network message directory")
    end
    
    return self
end

function FileNetwork:sendMessage(message, targetAddress, targetPort)
    if not self.isServer then
        -- Client sends to server
        local filename = self.messageDir .. "/client_to_server_" .. os.time() .. "_" .. math.random(1000, 9999) .. ".json"
        local data = json.encode({
            message = message,
            from = "client",
            to = "server",
            timestamp = love.timer.getTime()
        })
        love.filesystem.write(filename, data)
        Log.info("Sent message to server:", message.type)
        return true
    else
        -- Server broadcasts to all clients
        local filename = self.messageDir .. "/server_broadcast_" .. os.time() .. "_" .. math.random(1000, 9999) .. ".json"
        local data = json.encode({
            message = message,
            from = "server",
            to = "all_clients",
            timestamp = love.timer.getTime()
        })
        love.filesystem.write(filename, data)
        Log.info("Broadcasted message to clients:", message.type)
        return true
    end
end

function FileNetwork:receiveMessages()
    local messages = {}
    local files = love.filesystem.getDirectoryItems(self.messageDir)
    
    for _, filename in ipairs(files) do
        local shouldRead = false
        if self.isServer and filename:find("client_to_server") then
            shouldRead = true
        elseif not self.isServer and filename:find("server_broadcast") then
            shouldRead = true
        end
        
        if shouldRead then
            local success, data = pcall(love.filesystem.read, self.messageDir .. "/" .. filename)
            if success and data then
            local success2, messageData = pcall(json.decode, data)
            if success2 and messageData then
                Log.info("Received message:", messageData.message and messageData.message.type or "unknown")
                table.insert(messages, messageData)
            end
            end
            -- Delete the message file after reading
            love.filesystem.remove(self.messageDir .. "/" .. filename)
        end
    end
    
    return messages
end

function FileNetwork:cleanup()
    -- Clean up old message files (older than 10 seconds)
    local files = love.filesystem.getDirectoryItems(self.messageDir)
    local currentTime = os.time()
    
    for _, filename in ipairs(files) do
        local filePath = self.messageDir .. "/" .. filename
        local info = love.filesystem.getInfo(filePath)
        if info and (currentTime - info.modtime) > 10 then
            love.filesystem.remove(filePath)
        end
    end
end

return FileNetwork
