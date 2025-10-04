--[[
    ENet transport helper
    Wraps lua-enet so higher-level networking code can stay clean and fallback-friendly.
]]

local Log = require("src.core.log")

local function ensureCPath()
    if not package or not package.cpath then
        return
    end

    local patterns = {
        "src/libs/lua-enet/?.dll",
        "src/libs/lua-enet/?/?.dll",
        "src/libs/?.dll",
        "src/libs/?/?.dll"
    }

    local cpath = package.cpath
    for _, pattern in ipairs(patterns) do
        if not cpath:find(pattern, 1, true) then
            cpath = cpath .. ";" .. pattern
        end
    end

    package.cpath = cpath
end

ensureCPath()

local hasEnet, enet = pcall(require, "enet")

local EnetTransport = {}
EnetTransport._available = hasEnet and enet ~= nil

--- Check if the lua-enet binding is available.
function EnetTransport.isAvailable()
    return EnetTransport._available
end

--- Create an ENet client host that can connect to a remote server.
--- @param options table|nil
--- @return table|nil handle
--- @return string|nil err
function EnetTransport.createClient(options)
    if not EnetTransport._available then
        return nil, "ENet library not available"
    end

    options = options or {}
    local peerLimit = options.peerLimit or 32
    local channelLimit = options.channelLimit or 2
    local inBandwidth = options.inBandwidth or 0
    local outBandwidth = options.outBandwidth or 0

    local host = enet.host_create(nil, peerLimit, channelLimit, inBandwidth, outBandwidth)
    if not host then
        return nil, "Failed to create ENet client host"
    end

    return {
        host = host,
        peer = nil,
        channelLimit = channelLimit
    }
end

--- Initiate a connection for an ENet client host.
--- @param client table
--- @param address string
--- @param port number
--- @return userdata|nil peer
--- @return string|nil err
function EnetTransport.connect(client, address, port)
    if not client or not client.host then
        return nil, "Client host not initialised"
    end

    local endpoint = string.format("%s:%d", address, port)
    local peer = client.host:connect(endpoint, client.channelLimit or 2, 0)
    if not peer then
        return nil, "Failed to initiate ENet connection"
    end

    client.peer = peer
    return peer
end

--- Poll an ENet host for events.
--- @param handle table
--- @param timeout number|nil milliseconds
--- @return table|nil event
function EnetTransport.service(handle, timeout)
    if not handle or not handle.host then
        return nil
    end

    return handle.host:service(timeout or 0)
end

--- Send data through an ENet client peer.
--- @param client table
--- @param data string
--- @param channel number|nil
--- @param reliable boolean|nil
--- @return boolean success
--- @return string|nil err
function EnetTransport.send(client, data, channel, reliable)
    if not client or not client.peer then
        return false, "No active ENet peer"
    end

    local flag = nil
    if reliable == false then
        flag = "unreliable"
    end

    local ok = client.peer:send(data, channel or 0, flag)
    if ok == nil then
        return false, "Failed to enqueue ENet packet"
    end

    return true
end

--- Create an ENet server host bound to a port.
--- @param port number
--- @param options table|nil
--- @return table|nil handle
--- @return string|nil err
function EnetTransport.createServer(port, options)
    if not EnetTransport._available then
        return nil, "ENet library not available"
    end

    options = options or {}
    local endpoint = string.format("*:%d", port)
    local peerLimit = options.peerLimit or 64
    local channelLimit = options.channelLimit or 2
    local inBandwidth = options.inBandwidth or 0
    local outBandwidth = options.outBandwidth or 0

    local host = enet.host_create(endpoint, peerLimit, channelLimit, inBandwidth, outBandwidth)
    if not host then
        return nil, "Failed to create ENet server host"
    end

    return {
        host = host,
        channelLimit = channelLimit
    }
end

--- Flush pending packets for a client or server handle.
--- @param handle table|nil
function EnetTransport.flush(handle)
    if handle and handle.host then
        handle.host:flush()
    end
end

--- Disconnect a client peer cleanly.
--- @param client table
function EnetTransport.disconnectClient(client)
    if not client or not client.peer then
        return
    end

    client.peer:disconnect()
    -- Drain disconnect events so ENet can tidy up immediately.
    for _ = 1, 8 do
        local event = EnetTransport.service(client, 0)
        if not event then
            break
        end
    end
    client.peer = nil
end

--- Destroy an ENet host and release resources.
--- @param handle table|nil
function EnetTransport.destroy(handle)
    if not handle or not handle.host then
        return
    end

    handle.host:destroy()
    handle.host = nil
    handle.peer = nil
end

if not EnetTransport._available then
    Log.warn("ENet transport not available; falling back to simulation where possible")
end

return EnetTransport
