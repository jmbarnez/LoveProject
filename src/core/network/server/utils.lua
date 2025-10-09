local Utils = {}

function Utils.now()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return os.clock()
end

local function simpleHashTable(data)
    local hash = ""
    for key, value in pairs(data) do
        if type(value) == "table" then
            hash = hash .. tostring(key) .. ":" .. simpleHashTable(value) .. ";"
        else
            hash = hash .. tostring(key) .. ":" .. tostring(value) .. ";"
        end
    end
    return hash
end

function Utils.simpleHash(data)
    if not data or type(data) ~= "table" then
        return tostring(data)
    end

    return simpleHashTable(data)
end

function Utils.canonicalPlayerId(id)
    if id == nil then
        return nil
    end
    if type(id) == "number" then
        return id
    end
    if tonumber(id) then
        return tonumber(id)
    end
    return id
end

function Utils.buildSnapshot(players)
    local snapshot = {}
    for id, entry in pairs(players) do
        snapshot[#snapshot + 1] = {
            playerId = id,
            name = entry.name,
            state = entry.state
        }
    end
    return snapshot
end

return Utils
