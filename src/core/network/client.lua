--[[
    Network Client
    Minimal ENet client that exchanges player state snapshots with the host.
]]

local Log = require("src.core.log")
local Events = require("src.core.events")
local Messages = require("src.core.network.messages")

local TYPES = Messages.TYPES

local NetworkClient = {}
NetworkClient.__index = NetworkClient

local function sanitiseState(state)
    if type(state) ~= "table" then
        return nil
    end

    local position = state.position or {}
    local velocity = state.velocity or {}

    return {
        position = {
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 0,
            angle = tonumber(position.angle) or 0
        },
        velocity = {
            x = tonumber(velocity.x) or 0,
            y = tonumber(velocity.y) or 0
        },
        name = state.name
    }
end

local function buildIndex(snapshot)
    local out = {}
    if type(snapshot) ~= "table" then
        return out
    end

    for _, entry in ipairs(snapshot) do
        if entry.playerId ~= nil and entry.state then
            out[entry.playerId] = {
                playerId = entry.playerId,
                name = entry.name,
                state = sanitiseState(entry.state) or {
                    position = { x = 0, y = 0, angle = 0 },
                    velocity = { x = 0, y = 0 }
                }
            }
        end
    end
    return out
end

local function randomName()
    return string.format("Pilot_%d", love and love.timer and love.timer.getTime and math.floor(love.timer.getTime() * 1000) or os.time())
end

local function sanitiseWorldExtras(extra)
    if type(extra) ~= "table" then
        return nil
    end

    local sanitised = {}
    for key, value in pairs(extra) do
        local valueType = type(value)
        if valueType == "number" or valueType == "string" or valueType == "boolean" then
            sanitised[key] = value
        end
    end

    if next(sanitised) then
        return sanitised
    end

    return nil
end

local function sanitiseWorldEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if not entry.kind or not entry.id then
        return nil
    end

    local x = tonumber(entry.x)
    local y = tonumber(entry.y)
    if not x or not y then
        return nil
    end

    local sanitised = {
        kind = tostring(entry.kind),
        id = tostring(entry.id),
        x = x,
        y = y
    }

    if entry.angle ~= nil then
        sanitised.angle = tonumber(entry.angle) or 0
    end

    local extra = sanitiseWorldExtras(entry.extra)
    if extra then
        sanitised.extra = extra
    end

    return sanitised
end

local function sanitiseWorldSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return nil
    end

    local width = tonumber(snapshot.width)
    local height = tonumber(snapshot.height)

    local sanitised = {
        entities = {}
    }

    if width ~= nil then
        sanitised.width = width
    end

    if height ~= nil then
        sanitised.height = height
    end

    if type(snapshot.entities) == "table" then
        for _, entry in ipairs(snapshot.entities) do
            local sanitisedEntry = sanitiseWorldEntry(entry)
            if sanitisedEntry then
                sanitised.entities[#sanitised.entities + 1] = sanitisedEntry
            end
        end
    end

    return sanitised
end

function NetworkClient.new()
    local self = setmetatable({}, NetworkClient)

    self.transport = nil
    self.enetClient = nil
    self.playerId = nil
    self.players = {}
    self.connected = false
    self.lastError = nil
    self.localName = randomName()
    self.worldSnapshot = nil

    return self
end

function NetworkClient:isConnected()
    return self.connected and self.enetClient ~= nil
end

function NetworkClient:getPlayers()
    return self.players
end

function NetworkClient:getWorldSnapshot()
    return self.worldSnapshot
end

function NetworkClient:getPing()
    if self.enetClient and self.enetClient.peer then
        return self.enetClient.peer:round_trip_time() or 0
    end
    return 0
end

function NetworkClient:getLastError()
    return self.lastError
end

function NetworkClient:connect(address, port)
    if self:isConnected() then
        return true
    end

    local ok, EnetTransport = pcall(require, "src.core.network.transport.enet")
    if not ok or not EnetTransport or not EnetTransport.isAvailable() then
        self.lastError = "ENet transport not available"
        return false, self.lastError
    end

    local client, err = EnetTransport.createClient()
    if not client then
        self.lastError = err
        return false, err
    end

    local peer, connectErr = EnetTransport.connect(client, address or "localhost", port or 7777)
    if not peer then
        self.lastError = connectErr
        return false, connectErr
    end

    -- Block until connected or timeout
    local startTime = love.timer.getTime()
    local timeout = 5 -- 5 second timeout
    local connectedEvent = false
    local eventQueue = {}

    while love.timer.getTime() - startTime < timeout do
        local event = EnetTransport.service(client, 10) -- Wait up to 10ms
        if event then
            if event.type == "connect" then
                connectedEvent = true
                break
            elseif event.type == "disconnect" then
                self.lastError = "Connection failed: Disconnected"
                return false, self.lastError
            else
                table.insert(eventQueue, event)
            end
        end
    end

    if not connectedEvent then
        self.lastError = "Connection timed out"
        return false, self.lastError
    end

    self.transport = EnetTransport
    self.enetClient = client
    self.connected = true
    self.players = {}

    Log.info("Connecting to", address or "localhost", port or 7777)

    -- Process any queued events that arrived during connection
    for _, event in ipairs(eventQueue) do
        if event.type == "receive" then
            local message = Messages.decode(event.data)
            if message then
                self:_handleMessage(message)
            end
        end
    end

    self:_send({
        type = TYPES.HELLO,
        name = self.localName,
        state = {
            position = { x = 0, y = 0, angle = 0 },
            velocity = { x = 0, y = 0 }
        }
    })
    Events.emit("NETWORK_CONNECTED")

    return true
end

function NetworkClient:_send(payload)
    if not self:isConnected() then
        return
    end

    local encoded = Messages.encode(payload)
    if not encoded then
        return
    end

    local ok, err = self.transport.send(self.enetClient, encoded, 0, true)
    if not ok then
        Log.warn("Failed to send payload:", err)
    end
end

function NetworkClient:disconnect()
    if not self:isConnected() then
        return
    end

    self:_send({ type = TYPES.GOODBYE, playerId = self.playerId })

    self.transport.disconnectClient(self.enetClient)
    self.transport.destroy(self.enetClient)

    self.transport = nil
    self.enetClient = nil
    self.connected = false
    self.playerId = nil
    self.players = {}
    self.worldSnapshot = nil

    Events.emit("NETWORK_DISCONNECTED")
end

function NetworkClient:update(dt)
    if not self:isConnected() then
        return
    end

    local event = self.transport.service(self.enetClient, 0)
    while event do
        if event.type == "connect" then
            self:_send({
                type = TYPES.HELLO,
                name = self.localName,
                state = {
                    position = { x = 0, y = 0, angle = 0 },
                    velocity = { x = 0, y = 0 }
                }
            })
            Events.emit("NETWORK_CONNECTED")
        elseif event.type == "disconnect" then
            Log.warn("Disconnected from server")
            self:disconnect()
            return
        elseif event.type == "receive" then
            local message = Messages.decode(event.data)
            if message then
                self:_handleMessage(message)
            end
        end

        event = self.transport.service(self.enetClient, 0)
    end
end

function NetworkClient:_handleMessage(message)
    if message.type == TYPES.WELCOME then
        self.playerId = message.playerId
        self.players = buildIndex(message.players)

        Events.emit("NETWORK_PLAYER_JOINED", {
            playerId = self.playerId,
            isSelf = true,
            playerName = self.localName
        })

        for _, entry in ipairs(message.players or {}) do
            if entry.playerId ~= self.playerId then
                Events.emit("NETWORK_PLAYER_JOINED", {
                    playerId = entry.playerId,
                    playerName = entry.name,
                    data = entry.state
                })
            end
        end

    elseif message.type == TYPES.STATE then
        if message.playerId == self.playerId then
            return
        end

        if not self.players[message.playerId] then
            self.players[message.playerId] = {
                playerId = message.playerId,
                name = message.name or string.format("Player %s", tostring(message.playerId)),
                state = sanitiseState(message.state) or {
                    position = { x = 0, y = 0, angle = 0 },
                    velocity = { x = 0, y = 0 }
                }
            }
        else
            self.players[message.playerId].state = sanitiseState(message.state) or self.players[message.playerId].state
        end

        Events.emit("NETWORK_PLAYER_UPDATED", {
            playerId = message.playerId,
            data = self.players[message.playerId].state,
            playerName = self.players[message.playerId].name
        })
    elseif message.type == TYPES.GOODBYE then
        self.players[message.playerId] = nil
        Events.emit("NETWORK_PLAYER_LEFT", { playerId = message.playerId })
    elseif message.type == TYPES.WORLD_SNAPSHOT then
        local snapshot = sanitiseWorldSnapshot(message.snapshot)
        if snapshot then
            self.worldSnapshot = snapshot
            Events.emit("NETWORK_WORLD_SNAPSHOT", { snapshot = snapshot })
        end
    elseif message.type == TYPES.ENEMY_UPDATE then
        -- Forward enemy replication payloads to gameplay systems
        local enemies = type(message.enemies) == "table" and message.enemies or nil
        if enemies then
            Events.emit("NETWORK_ENEMY_UPDATE", { enemies = enemies })
        end
    end
end

function NetworkClient:sendPlayerUpdate(state)
    if not self:isConnected() then
        return
    end

    self:_send({
        type = TYPES.STATE,
        playerId = self.playerId,
        state = sanitiseState(state)
    })
end

return NetworkClient
