-- main.lua
-- Entry point for the game. Delegates all Love callbacks to the core App module
-- to keep the project modular and maintainable.

local App = require("src.core.app")

function love.load(...)
    App.load(...)
end

function love.resize(...)
    App.resize(...)
end

function love.update(...)
    App.update(...)
end

function love.draw(...)
    App.draw(...)
end

function love.keypressed(...)
    App.keypressed(...)
end

function love.keyreleased(...)
    App.keyreleased(...)
end

function love.mousepressed(...)
    App.mousepressed(...)
end

function love.mousereleased(...)
    App.mousereleased(...)
end

function love.mousemoved(...)
    App.mousemoved(...)
end

function love.wheelmoved(...)
    App.wheelmoved(...)
end

function love.textinput(...)
    App.textinput(...)
end
