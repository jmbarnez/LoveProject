
--[[
    Core game loop entry point.

    This lightweight facade wires Love2D callbacks to dedicated modules that
    handle loading, updating, drawing, and teardown. The heavy lifting now
    lives inside src/game/* to keep this file focused on orchestration and
    multiplayer helpers.
]]

local State = require("src.game.state")
local LoadGame = require("src.game.load")
local UnloadGame = require("src.game.unload")
local UpdateGame = require("src.game.update")
local DrawGame = require("src.game.draw")

local NetworkSession = require("src.core.network.session")

local Game = {}

Game.world = nil
Game.windfield = nil

function Game.getNetworkSession()
    return NetworkSession
end

function Game.getNetworkManager()
    return NetworkSession.getManager()
end

function Game.setMultiplayerMode(multiplayer, host)
    NetworkSession.setMode(multiplayer, host)
end

function Game.isMultiplayer()
    return NetworkSession.isMultiplayer()
end

function Game.isHost()
    return NetworkSession.isHost()
end

function Game.toggleLanHosting()
    return NetworkSession.toggleHosting()
end

function Game.load(fromSave, saveSlot, loadingScreen, multiplayer, isHost)
    local ok, err = LoadGame.load(Game, fromSave, saveSlot, loadingScreen, multiplayer, isHost)
    if ok then
        Game.world = State.world
        Game.windfield = State.windfieldManager
    end
    return ok, err
end

function Game.unload()
    UnloadGame.unload(Game)
end

function Game.update(dt)
    UpdateGame.update(dt)
end

function Game.resize(w, h)
    if State.world then
        State.world:resize(w, h)
    end

    if Game.blurCanvas then
        if Game.blurCanvas.release then
            Game.blurCanvas:release()
        end
        Game.blurCanvas = nil
    end
end

function Game.draw()
    DrawGame.draw(Game)
end

return Game
