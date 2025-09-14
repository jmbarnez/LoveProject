--[[
  Multiplayer Menu UI
  Simple interface for hosting/joining games
]]

local Viewport = require("src.core.viewport")
local Theme = require("src.core.theme")
local Multiplayer = require("src.core.multiplayer")

local MultiplayerMenu = {}
MultiplayerMenu.__index = MultiplayerMenu

function MultiplayerMenu.new()
    local self = setmetatable({}, MultiplayerMenu)
    self.visible = false
    self.mode = "menu" -- "menu", "host", "join"
    self.hostPort = "25565"
    self.joinIP = "127.0.0.1"
    self.joinPort = "25565"
    self.inputField = nil -- Which field is being edited
    self.buttons = {}
    self.textFields = {}
    self.serverList = {} -- Discovered servers
    self.selectedServer = nil -- Currently selected server
    self.showDirectConnect = false -- Toggle between browser and direct connect
    
    -- ENet networking is now always available
    self.status = "ENet networking ready"
    
    return self
end

function MultiplayerMenu:show()
    self.visible = true
    self.mode = "menu"
    self.showDirectConnect = false
    self.status = ""
end

function MultiplayerMenu:hide()
    self.visible = false
    self.mode = "menu"
    self.inputField = nil
end

function MultiplayerMenu:update(dt)
    if not self.visible then return end
    
    -- Update server list when in join mode
    if self.mode == "join" and not self.showDirectConnect then
        self.serverList = Multiplayer.getNetworkStats().discoveredServers or {}
    end
    
    -- Update multiplayer status
    if Multiplayer.isConnected() then
        local stats = Multiplayer.getNetworkStats()
        if stats.isHost then
            self.status = "ENet: Hosting game - " .. stats.playerCount .. " players connected"
        else
            self.status = "ENet: Connected to game - " .. stats.playerCount .. " players"
        end
    end
end

function MultiplayerMenu:draw()
    if not self.visible then return end
    
    local w, h = Viewport.getDimensions()
    local scale = math.min(w / 1920, h / 1080)
    
    -- Background overlay
    Theme.setColor({0, 0, 0, 0.8})
    love.graphics.rectangle('fill', 0, 0, w, h)
    
    -- Main panel
    local panelW, panelH = 400 * scale, 300 * scale
    local panelX = (w - panelW) / 2
    local panelY = (h - panelH) / 2
    
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 10)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', panelX, panelY, panelW, panelH, 10)
    
    -- Title
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("MULTIPLAYER", panelX, panelY + 20 * scale, panelW, 'center')
    
    local yOffset = panelY + 60 * scale
    
    if self.mode == "menu" then
        self:drawMainMenu(panelX, yOffset, panelW, scale)
    elseif self.mode == "host" then
        self:drawHostMenu(panelX, yOffset, panelW, scale)
    elseif self.mode == "join" then
        self:drawJoinMenu(panelX, yOffset, panelW, scale)
    end
    
    -- Status text
    if self.status ~= "" then
        Theme.setColor(Theme.colors.accent)
        love.graphics.printf(self.status, panelX, panelY + panelH - 60 * scale, panelW, 'center')
    end
    
    -- Start Game button (show when connected)
    if Multiplayer.isConnected() then
        local startGameBtn = {
            x = panelX + (panelW - 150 * scale) / 2,
            y = panelY + panelH - 35 * scale,
            w = 150 * scale,
            h = 25 * scale
        }
        self.buttons.startGame = startGameBtn
        
        Theme.setColor(Theme.colors.primary)
        love.graphics.rectangle('fill', startGameBtn.x, startGameBtn.y, startGameBtn.w, startGameBtn.h, 3)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle('line', startGameBtn.x, startGameBtn.y, startGameBtn.w, startGameBtn.h, 3)
        Theme.setColor(Theme.colors.text)
        love.graphics.printf("START GAME", startGameBtn.x, startGameBtn.y + 5 * scale, startGameBtn.w, 'center')
    end
end

function MultiplayerMenu:drawMainMenu(x, y, w, scale)
    -- Clear buttons for this mode
    self.buttons = {}
    
    local buttonW, buttonH = 200 * scale, 40 * scale
    local buttonX = x + (w - buttonW) / 2
    
    -- Host Game button
    local hostBtn = {x = buttonX, y = y, w = buttonW, h = buttonH}
    self.buttons.host = hostBtn
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle('fill', hostBtn.x, hostBtn.y, hostBtn.w, hostBtn.h, 5)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', hostBtn.x, hostBtn.y, hostBtn.w, hostBtn.h, 5)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("HOST GAME", hostBtn.x, hostBtn.y + 12 * scale, hostBtn.w, 'center')
    
    y = y + buttonH + 20 * scale
    
    -- Join Game button
    local joinBtn = {x = buttonX, y = y, w = buttonW, h = buttonH}
    self.buttons.join = joinBtn
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle('fill', joinBtn.x, joinBtn.y, joinBtn.w, joinBtn.h, 5)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', joinBtn.x, joinBtn.y, joinBtn.w, joinBtn.h, 5)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("JOIN GAME", joinBtn.x, joinBtn.y + 12 * scale, joinBtn.w, 'center')
    
    y = y + buttonH + 20 * scale
    
    -- Back button
    local backBtn = {x = buttonX, y = y, w = buttonW, h = buttonH}
    self.buttons.back = backBtn
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle('fill', backBtn.x, backBtn.y, backBtn.w, backBtn.h, 5)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', backBtn.x, backBtn.y, backBtn.w, backBtn.h, 5)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("BACK", backBtn.x, backBtn.y + 12 * scale, backBtn.w, 'center')
end

function MultiplayerMenu:drawHostMenu(x, y, w, scale)
    -- Clear buttons and text fields for this mode
    self.buttons = {}
    self.textFields = {}
    
    -- Port input
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("Port:", x + 20 * scale, y, w - 40 * scale, 'left')
    
    local fieldW, fieldH = 100 * scale, 30 * scale
    local fieldX = x + w - fieldW - 20 * scale
    local portField = {x = fieldX, y = y - 5 * scale, w = fieldW, h = fieldH}
    self.textFields.hostPort = portField
    
    local fieldColor = (self.inputField == "hostPort") and Theme.colors.accent or Theme.colors.bg3
    Theme.setColor(fieldColor)
    love.graphics.rectangle('fill', portField.x, portField.y, portField.w, portField.h, 3)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', portField.x, portField.y, portField.w, portField.h, 3)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf(self.hostPort, portField.x + 5 * scale, portField.y + 5 * scale, portField.w - 10 * scale, 'left')
    
    y = y + 50 * scale
    
    -- Start hosting button
    local buttonW, buttonH = 150 * scale, 40 * scale
    local startBtn = {x = x + (w - buttonW) / 2, y = y, w = buttonW, h = buttonH}
    self.buttons.startHost = startBtn
    Theme.setColor(Theme.colors.primary)
    love.graphics.rectangle('fill', startBtn.x, startBtn.y, startBtn.w, startBtn.h, 5)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', startBtn.x, startBtn.y, startBtn.w, startBtn.h, 5)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("START HOST", startBtn.x, startBtn.y + 12 * scale, startBtn.w, 'center')
    
    y = y + buttonH + 20 * scale
    
    -- Back button
    local backBtn = {x = x + (w - buttonW) / 2, y = y, w = buttonW, h = buttonH}
    self.buttons.backToMenu = backBtn
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle('fill', backBtn.x, backBtn.y, backBtn.w, backBtn.h, 5)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', backBtn.x, backBtn.y, backBtn.w, backBtn.h, 5)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("BACK", backBtn.x, backBtn.y + 12 * scale, backBtn.w, 'center')
end

function MultiplayerMenu:drawJoinMenu(x, y, w, scale)
    -- Clear buttons and text fields for this mode
    self.buttons = {}
    self.textFields = {}
    
    if self.showDirectConnect then
        self:drawDirectConnect(x, y, w, scale)
    else
        self:drawServerBrowser(x, y, w, scale)
    end
end

function MultiplayerMenu:drawServerBrowser(x, y, w, scale)
    local startY = y
    
    -- Header with buttons
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("LAN SERVERS", x, y, w, 'center')
    y = y + 25 * scale
    
    -- Control buttons
    local buttonW, buttonH = 80 * scale, 25 * scale
    local spacing = 10 * scale
    local totalButtonWidth = (buttonW * 3) + (spacing * 2)
    local buttonStartX = x + (w - totalButtonWidth) / 2
    
    -- Refresh button
    local refreshBtn = {x = buttonStartX, y = y, w = buttonW, h = buttonH}
    self.buttons.refresh = refreshBtn
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle('fill', refreshBtn.x, refreshBtn.y, refreshBtn.w, refreshBtn.h, 3)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', refreshBtn.x, refreshBtn.y, refreshBtn.w, refreshBtn.h, 3)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("REFRESH", refreshBtn.x, refreshBtn.y + 5 * scale, refreshBtn.w, 'center')
    
    -- Direct Connect button
    local directBtn = {x = buttonStartX + buttonW + spacing, y = y, w = buttonW, h = buttonH}
    self.buttons.directConnect = directBtn
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle('fill', directBtn.x, directBtn.y, directBtn.w, directBtn.h, 3)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', directBtn.x, directBtn.y, directBtn.w, directBtn.h, 3)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("DIRECT", directBtn.x, directBtn.y + 5 * scale, directBtn.w, 'center')
    
    -- Back button
    local backBtn = {x = buttonStartX + (buttonW + spacing) * 2, y = y, w = buttonW, h = buttonH}
    self.buttons.backToMenu = backBtn
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle('fill', backBtn.x, backBtn.y, backBtn.w, backBtn.h, 3)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', backBtn.x, backBtn.y, backBtn.w, backBtn.h, 3)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("BACK", backBtn.x, backBtn.y + 5 * scale, backBtn.w, 'center')
    
    y = y + buttonH + 20 * scale
    
    -- Server list area
    local listHeight = 120 * scale
    local listArea = {x = x + 10 * scale, y = y, w = w - 20 * scale, h = listHeight}
    
    -- List background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle('fill', listArea.x, listArea.y, listArea.w, listArea.h, 5)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', listArea.x, listArea.y, listArea.w, listArea.h, 5)
    
    -- Server list headers
    local headerY = listArea.y + 5 * scale
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.printf("SERVER NAME", listArea.x + 10 * scale, headerY, 140 * scale, 'left')
    love.graphics.printf("PLAYERS", listArea.x + 160 * scale, headerY, 60 * scale, 'left')
    love.graphics.printf("PING", listArea.x + 230 * scale, headerY, 40 * scale, 'left')
    love.graphics.printf("IP:PORT", listArea.x + 280 * scale, headerY, 80 * scale, 'left')
    
    -- Header line
    local lineY = headerY + 15 * scale
    Theme.setColor(Theme.colors.border)
    love.graphics.line(listArea.x + 5 * scale, lineY, listArea.x + listArea.w - 5 * scale, lineY)
    
    -- Server entries
    local entryHeight = 18 * scale
    local entryY = lineY + 5 * scale
    
    -- Get discovered servers from network
    local Network = require("src.core.network")
    local discoveredServers = Network.getDiscoveredServers()
    
    if #discoveredServers == 0 then
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.printf("No servers found. Use DIRECT CONNECT to join a specific IP address.", 
                           listArea.x + 10 * scale, entryY + 20 * scale, listArea.w - 20 * scale, 'center')
    else
        for i, server in ipairs(discoveredServers) do
            if entryY + entryHeight > listArea.y + listArea.h - 10 * scale then break end
            
            local serverRect = {
                x = listArea.x + 5 * scale,
                y = entryY,
                w = listArea.w - 10 * scale,
                h = entryHeight
            }
            
            -- Server entry background (highlight if selected)
            local isSelected = (self.selectedServer == i)
            if isSelected then
                Theme.setColor(Theme.colors.accent)
                love.graphics.rectangle('fill', serverRect.x, serverRect.y, serverRect.w, serverRect.h, 3)
            end
            
            -- Make server entries clickable
            self.buttons["server_" .. i] = serverRect
            
            -- Server info
            local textColor = isSelected and Theme.colors.bg0 or Theme.colors.text
            Theme.setColor(textColor)
            
            local textY = entryY + 3 * scale
            love.graphics.printf(server.name, listArea.x + 10 * scale, textY, 140 * scale, 'left')
            love.graphics.printf(server.players .. "/" .. server.maxPlayers, listArea.x + 160 * scale, textY, 60 * scale, 'left')
            love.graphics.printf(server.ping .. "ms", listArea.x + 230 * scale, textY, 40 * scale, 'left')
            love.graphics.printf(server.ip .. ":" .. server.port, listArea.x + 280 * scale, textY, 80 * scale, 'left')
            
            entryY = entryY + entryHeight + 2 * scale
        end
    end
    
    y = listArea.y + listArea.h + 15 * scale
    
    -- Connect button (only show if server selected)
    if self.selectedServer and discoveredServers[self.selectedServer] then
        local connectBtn = {x = x + (w - 120 * scale) / 2, y = y, w = 120 * scale, h = 30 * scale}
        self.buttons.connectToServer = connectBtn
        Theme.setColor(Theme.colors.primary)
        love.graphics.rectangle('fill', connectBtn.x, connectBtn.y, connectBtn.w, connectBtn.h, 5)
        Theme.setColor(Theme.colors.border)
        love.graphics.rectangle('line', connectBtn.x, connectBtn.y, connectBtn.w, connectBtn.h, 5)
        Theme.setColor(Theme.colors.text)
        love.graphics.printf("JOIN SERVER", connectBtn.x, connectBtn.y + 8 * scale, connectBtn.w, 'center')
    end
end

function MultiplayerMenu:drawDirectConnect(x, y, w, scale)
    -- Direct connect mode (original join UI)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("DIRECT CONNECT", x, y, w, 'center')
    y = y + 35 * scale
    
    -- IP input
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("IP Address:", x + 20 * scale, y, w - 40 * scale, 'left')
    
    local fieldW, fieldH = 150 * scale, 30 * scale
    local fieldX = x + w - fieldW - 20 * scale
    local ipField = {x = fieldX, y = y - 5 * scale, w = fieldW, h = fieldH}
    self.textFields.joinIP = ipField
    
    local fieldColor = (self.inputField == "joinIP") and Theme.colors.accent or Theme.colors.bg3
    Theme.setColor(fieldColor)
    love.graphics.rectangle('fill', ipField.x, ipField.y, ipField.w, ipField.h, 3)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', ipField.x, ipField.y, ipField.w, ipField.h, 3)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf(self.joinIP, ipField.x + 5 * scale, ipField.y + 5 * scale, ipField.w - 10 * scale, 'left')
    
    y = y + 50 * scale
    
    -- Port input
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("Port:", x + 20 * scale, y, w - 40 * scale, 'left')
    
    local portField = {x = fieldX, y = y - 5 * scale, w = fieldW, h = fieldH}
    self.textFields.joinPort = portField
    
    fieldColor = (self.inputField == "joinPort") and Theme.colors.accent or Theme.colors.bg3
    Theme.setColor(fieldColor)
    love.graphics.rectangle('fill', portField.x, portField.y, portField.w, portField.h, 3)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', portField.x, portField.y, portField.w, portField.h, 3)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf(self.joinPort, portField.x + 5 * scale, portField.y + 5 * scale, portField.w - 10 * scale, 'left')
    
    y = y + 50 * scale
    
    -- Buttons
    local buttonW, buttonH = 120 * scale, 30 * scale
    local spacing = 20 * scale
    local totalWidth = buttonW * 2 + spacing
    local buttonX = x + (w - totalWidth) / 2
    
    -- Connect button
    local connectBtn = {x = buttonX, y = y, w = buttonW, h = buttonH}
    self.buttons.connect = connectBtn
    Theme.setColor(Theme.colors.primary)
    love.graphics.rectangle('fill', connectBtn.x, connectBtn.y, connectBtn.w, connectBtn.h, 5)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', connectBtn.x, connectBtn.y, connectBtn.w, connectBtn.h, 5)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("CONNECT", connectBtn.x, connectBtn.y + 8 * scale, connectBtn.w, 'center')
    
    -- Back to browser button
    local backToBrowserBtn = {x = buttonX + buttonW + spacing, y = y, w = buttonW, h = buttonH}
    self.buttons.backToBrowser = backToBrowserBtn
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle('fill', backToBrowserBtn.x, backToBrowserBtn.y, backToBrowserBtn.w, backToBrowserBtn.h, 5)
    Theme.setColor(Theme.colors.border)
    love.graphics.rectangle('line', backToBrowserBtn.x, backToBrowserBtn.y, backToBrowserBtn.w, backToBrowserBtn.h, 5)
    Theme.setColor(Theme.colors.text)
    love.graphics.printf("BACK", backToBrowserBtn.x, backToBrowserBtn.y + 8 * scale, backToBrowserBtn.w, 'center')
end

function MultiplayerMenu:mousepressed(x, y, button)
    if not self.visible or button ~= 1 then return false end
    
    -- Check button clicks
    for name, btn in pairs(self.buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            return self:handleButtonClick(name)
        end
    end
    
    -- Check text field clicks
    self.inputField = nil
    for name, field in pairs(self.textFields) do
        if x >= field.x and x <= field.x + field.w and y >= field.y and y <= field.y + field.h then
            self.inputField = name
            return true
        end
    end
    
    return true -- Consume all clicks when visible
end

function MultiplayerMenu:handleButtonClick(buttonName)
    if buttonName == "host" then
        self.mode = "host"
    elseif buttonName == "join" then
        self.mode = "join"
        self.showDirectConnect = false
        -- Start server discovery when entering join mode
        local Network = require("src.core.network")
        Network.startServerDiscovery()
    elseif buttonName == "back" then
        self:hide()
        return false -- Don't consume, allow start screen to handle
    elseif buttonName == "backToMenu" then
        self.mode = "menu"
        self.showDirectConnect = false
        self.selectedServer = nil
    elseif buttonName == "refresh" then
        local Network = require("src.core.network")
        Network.refreshServerList()
        self.selectedServer = nil
        self.status = "Searching for LAN games..."
    elseif buttonName == "directConnect" then
        self.showDirectConnect = true
    elseif buttonName == "backToBrowser" then
        self.showDirectConnect = false
    elseif buttonName == "connectToServer" then
        -- Connect to selected server
        if self.selectedServer then
            local Network = require("src.core.network")
            local servers = Network.getDiscoveredServers()
            local server = servers[self.selectedServer]
            if server then
                if Multiplayer.join(server.ip, server.port) then
                    self.status = "Connecting to " .. server.name .. "..."
                else
                    self.status = "Failed to connect to " .. server.name
                end
            end
        end
    elseif buttonName == "startHost" then
        local port = tonumber(self.hostPort) or 25565
        if Multiplayer.host(port) then
            self.status = "ENet: Hosting on port " .. port
        else
            self.status = "Failed to start host"
        end
    elseif buttonName == "connect" then
        local port = tonumber(self.joinPort) or 25565
        if Multiplayer.join(self.joinIP, port) then
            self.status = "ENet: Connecting to " .. self.joinIP .. ":" .. port
        else
            self.status = "Failed to connect"
        end
    elseif buttonName == "startGame" then
        -- Signal to start the game
        self:hide()
        return "startGame" -- Special return value to signal game start
    elseif buttonName:sub(1, 7) == "server_" then
        -- Server selection
        local serverIndex = tonumber(buttonName:sub(8))
        self.selectedServer = serverIndex
        local Network = require("src.core.network")
        local servers = Network.getDiscoveredServers()
        if servers[serverIndex] then
            self.status = "Selected: " .. servers[serverIndex].name
        end
    end
    
    return true
end

function MultiplayerMenu:textinput(text)
    if not self.visible or not self.inputField then return false end
    
    if self.inputField == "hostPort" then
        if text:match("%d") and #self.hostPort < 5 then
            self.hostPort = self.hostPort .. text
        end
    elseif self.inputField == "joinIP" then
        if #self.joinIP < 15 and (text:match("[%d%.]") or text == ".") then
            self.joinIP = self.joinIP .. text
        end
    elseif self.inputField == "joinPort" then
        if text:match("%d") and #self.joinPort < 5 then
            self.joinPort = self.joinPort .. text
        end
    end
    
    return true
end

function MultiplayerMenu:keypressed(key)
    if not self.visible then return false end
    
    if key == "escape" then
        if self.mode == "menu" then
            self:hide()
            return false
        else
            self.mode = "menu"
            return true
        end
    elseif key == "backspace" and self.inputField then
        if self.inputField == "hostPort" and #self.hostPort > 0 then
            self.hostPort = self.hostPort:sub(1, -2)
        elseif self.inputField == "joinIP" and #self.joinIP > 0 then
            self.joinIP = self.joinIP:sub(1, -2)
        elseif self.inputField == "joinPort" and #self.joinPort > 0 then
            self.joinPort = self.joinPort:sub(1, -2)
        end
        return true
    end
    
    return true -- Consume all keypresses when visible
end

return MultiplayerMenu