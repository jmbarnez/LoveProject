# UI Guide - Novus Space Game

This document provides comprehensive information about the UI system, components, and how to create and modify user interface elements.

## Table of Contents

1. [UI System Overview](#ui-system-overview)
2. [UI Architecture](#ui-architecture)
3. [Core UI Components](#core-ui-components)
4. [UI Panels](#ui-panels)
5. [HUD System](#hud-system)
6. [Theme System](#theme-system)
7. [Input Handling](#input-handling)
8. [UI Development](#ui-development)

## UI System Overview

The UI system uses a **modular panel approach** with centralized management. UI elements are organized into panels that can be shown/hidden, and the system handles input routing, rendering, and state management.

### Key Features

- **Panel-based Architecture**: Self-contained UI components
- **Centralized Management**: UIManager coordinates all UI elements
- **Theme System**: Consistent styling and theming
- **Input Routing**: Automatic input handling and focus management
- **Responsive Design**: Adapts to different screen sizes
- **Modal Support**: Full-screen overlays and dialogs

### UI System Components

- **UIManager**: Central coordination and state management
- **Panels**: Individual UI components (inventory, settings, etc.)
- **Theme System**: Styling and visual consistency
- **Input System**: Mouse and keyboard handling
- **Viewport System**: Screen space management

## UI Architecture

### UIManager (`src/core/ui_manager.lua`)

The UIManager is the central coordinator for all UI elements:

```lua
-- UIManager provides these key functions:
UIManager.init()                    -- Initialize UI system
UIManager.update(dt, player)        -- Update all UI elements
UIManager.draw(player, world, ...)  -- Render all UI elements
UIManager.open(panelName)           -- Show a panel
UIManager.close(panelName)          -- Hide a panel
UIManager.isOpen(panelName)         -- Check if panel is open
UIManager.toggle(panelName)         -- Toggle panel visibility
```

### Panel Structure

Each UI panel follows a consistent structure:

```lua
local MyPanel = {}

-- Panel state
MyPanel.visible = false
MyPanel.player = nil
MyPanel.data = {}

-- Initialize panel
function MyPanel.init()
    -- Setup panel
end

-- Show panel
function MyPanel.show(player, data)
    MyPanel.visible = true
    MyPanel.player = player
    MyPanel.data = data or {}
end

-- Hide panel
function MyPanel.hide()
    MyPanel.visible = false
    MyPanel.player = nil
    MyPanel.data = {}
end

-- Update panel
function MyPanel.update(dt)
    if not MyPanel.visible then return end
    -- Update logic
end

-- Draw panel
function MyPanel.draw()
    if not MyPanel.visible then return end
    -- Drawing logic
end
```

## Core UI Components

### 1. Window Component (`src/ui/common/window.lua`)

Provides standard window styling and behavior:

```lua
-- Create a window
local window = {
    x = 100, y = 100,
    width = 400, height = 300,
    title = "Window Title",
    closable = true
}

-- Draw window
Window.draw(window)
```

### 2. Button Component

Standard button with hover and click states:

```lua
-- Button definition
local button = {
    x = 100, y = 100,
    width = 120, height = 40,
    text = "Click Me",
    onClick = function() 
        -- Button action
    end
}

-- Check if button is clicked
if Button.isClicked(button, mouseX, mouseY) then
    button.onClick()
end
```

### 3. Input Field Component

Text input with focus management:

```lua
-- Input field definition
local input = {
    x = 100, y = 100,
    width = 200, height = 30,
    text = "",
    placeholder = "Enter text...",
    maxLength = 50,
    active = false
}

-- Handle input
if InputField.handleInput(input, key, text) then
    -- Input was processed
end
```

### 4. Tooltip Component (`src/ui/tooltip.lua`)

Context-sensitive help and information:

```lua
-- Show tooltip
Tooltip.show("This is a tooltip", x, y)

-- Hide tooltip
Tooltip.hide()
```

## UI Panels

### 1. Start Screen (`src/ui/start_screen.lua`)

The main menu and game launcher:

**Features**:
- Game title with aurora effect
- Start game button
- Multiplayer menu
- Settings access
- Save/load slots
- Exit button

**Key Functions**:
```lua
Start.new()              -- Create start screen
Start:update(dt)         -- Update animations and input
Start:draw()             -- Render start screen
Start:resize(w, h)       -- Handle window resize
```

### 2. Docked Interface (`src/ui/docked.lua`)

Main interface when docked at stations:

**Tabs**:
- **Shop**: Buy/sell items and ships
- **Ship**: Equipment and customization
- **Quests**: Mission management
- **Nodes**: Trading interface

**Key Functions**:
```lua
DockedUI.show(player, station)    -- Show docked interface
DockedUI.hide()                   -- Hide interface
DockedUI.update(dt)               -- Update interface
DockedUI.draw()                   -- Render interface
```

### 3. Inventory Panel (`src/ui/inventory.lua`)

Item and equipment management:

**Features**:
- Item grid display
- Drag and drop functionality
- Equipment slots
- Item tooltips
- Context menus

**Key Functions**:
```lua
InventoryUI.show(player)          -- Show inventory
InventoryUI.hide()                -- Hide inventory
InventoryUI.handleDragDrop()      -- Handle drag and drop
InventoryUI.drawItemGrid()        -- Draw item grid
```

### 4. Settings Panel (`src/ui/settings_panel.lua`)

Game configuration and options:

**Features**:
- Graphics settings
- Audio settings
- Control bindings
- Gameplay options

**Key Functions**:
```lua
SettingsPanel.init()              -- Initialize settings
SettingsPanel.show()              -- Show settings
SettingsPanel.hide()              -- Hide settings
SettingsPanel.applySettings()     -- Apply changes
```

### 5. Warp Panel (`src/ui/warp.lua`)

Sector navigation and travel:

**Features**:
- Sector map display
- Sector information
- Warp confirmation
- Sector unlocking

**Key Functions**:
```lua
Warp:show()                       -- Show warp interface
Warp:hide()                       -- Hide interface
Warp:update(dt)                   -- Update interface
Warp:draw()                       -- Render interface
```

### 6. Debug Panel (`src/ui/debug_panel.lua`)

Development and debugging tools:

**Features**:
- Performance metrics
- Entity information
- Debug commands
- System status

**Key Functions**:
```lua
DebugPanel.update(dt)             -- Update debug info
DebugPanel.draw()                 -- Render debug panel
DebugPanel.keypressed(key)        -- Handle debug input
```

## HUD System

### HUD Components (`src/ui/hud/`)

The HUD provides in-game information and controls:

#### 1. Status Bars (`src/ui/hud/status_bars.lua`)

Displays player health, energy, and shields:

```lua
-- Status bar configuration
local statusBar = {
    x = 20, y = 20,
    width = 200, height = 20,
    value = 0.8,  -- 0-1
    maxValue = 1.0,
    color = {1, 0, 0},  -- Red for health
    label = "Health"
}

-- Draw status bar
StatusBar.draw(statusBar)
```

#### 2. Minimap (`src/ui/hud/minimap.lua`)

World overview and navigation:

```lua
-- Minimap configuration
local minimap = {
    x = screenWidth - 200, y = 20,
    width = 180, height = 180,
    scale = 0.1,  -- World to minimap scale
    player = player,
    world = world
}

-- Draw minimap
Minimap.draw(minimap)
```

#### 3. Quest Log (`src/ui/hud/quest_log.lua`)

Active mission display:

```lua
-- Quest log configuration
local questLog = {
    x = 20, y = screenHeight - 150,
    width = 300, height = 120,
    quests = player.active_quests
}

-- Draw quest log
QuestLog.draw(questLog)
```

#### 4. Hotbar (`src/systems/hotbar.lua`)

Quick actions and abilities:

```lua
-- Hotbar configuration
local hotbar = {
    x = screenWidth/2 - 200, y = screenHeight - 60,
    width = 400, height = 50,
    slots = 5,
    player = player
}

-- Draw hotbar
Hotbar.draw(hotbar)
```

## Theme System

### Theme Configuration (`src/core/theme.lua`)

The theme system provides consistent styling:

```lua
-- Theme colors
Theme.colors = {
    bg0 = {0.1, 0.1, 0.15},      -- Dark background
    bg1 = {0.2, 0.2, 0.25},      -- Light background
    border = {0.4, 0.4, 0.5},    -- Border color
    text = {0.9, 0.9, 0.9},      -- Text color
    accent = {0.2, 0.8, 0.9},    -- Accent color
    success = {0.2, 0.8, 0.2},   -- Success color
    warning = {0.8, 0.6, 0.2},   -- Warning color
    error = {0.8, 0.2, 0.2}      -- Error color
}

-- Theme fonts
Theme.fonts = {
    small = love.graphics.newFont(12),
    normal = love.graphics.newFont(16),
    large = love.graphics.newFont(24),
    title = love.graphics.newFont(32)
}

-- Theme effects
Theme.effects = {
    glowSmall = {radius = 2, intensity = 0.5},
    glowMedium = {radius = 4, intensity = 0.7},
    glowLarge = {radius = 8, intensity = 0.9}
}
```

### Theme Functions

```lua
-- Draw themed rectangle
Theme.drawRect(x, y, width, height, color, borderColor)

-- Draw themed text
Theme.drawText(text, x, y, font, color, align)

-- Draw gradient rectangle
Theme.drawGradientRect(x, y, width, height, color1, color2, direction)

-- Draw glow effect
Theme.drawGlow(x, y, width, height, color, glowConfig)
```

## Input Handling

### Input System (`src/core/input.lua`)

The input system handles mouse and keyboard input:

```lua
-- Input state
local input = Input.getInputState()

-- Mouse input
input.mouse.x              -- Mouse X position
input.mouse.y              -- Mouse Y position
input.mouse.left           -- Left mouse button
input.mouse.right          -- Right mouse button
input.mouse.wheel          -- Mouse wheel delta

-- Keyboard input
input.keys["space"]        -- Space key pressed
input.keys["escape"]       -- Escape key pressed
input.keys["w"]            -- W key pressed
```

### Input Handling Patterns

#### Mouse Click Detection
```lua
-- Check if mouse clicked on rectangle
local function isMouseOver(x, y, width, height)
    local mouse = Input.getInputState().mouse
    return mouse.x >= x and mouse.x <= x + width and
           mouse.y >= y and mouse.y <= y + height
end

-- Handle button click
if isMouseOver(button.x, button.y, button.width, button.height) and
   Input.getInputState().mouse.left then
    button.onClick()
end
```

#### Keyboard Input
```lua
-- Handle keyboard input
local input = Input.getInputState()
if input.keys["enter"] then
    -- Handle enter key
end

-- Handle key combinations
if input.keys["lctrl"] and input.keys["s"] then
    -- Handle Ctrl+S
end
```

## UI Development

### Creating a New Panel

1. **Create Panel File**: Create a new `.lua` file in `src/ui/`

2. **Define Panel Structure**:
```lua
local MyPanel = {}

-- Panel state
MyPanel.visible = false
MyPanel.player = nil
MyPanel.data = {}

-- Panel functions
function MyPanel.init()
    -- Initialize panel
end

function MyPanel.show(player, data)
    MyPanel.visible = true
    MyPanel.player = player
    MyPanel.data = data or {}
end

function MyPanel.hide()
    MyPanel.visible = false
    MyPanel.player = nil
    MyPanel.data = {}
end

function MyPanel.update(dt)
    if not MyPanel.visible then return end
    -- Update logic
end

function MyPanel.draw()
    if not MyPanel.visible then return end
    -- Drawing logic
end

return MyPanel
```

3. **Register with UIManager**: Add panel to UIManager

4. **Add Input Handling**: Handle mouse and keyboard input

5. **Test Panel**: Test in-game functionality

### UI Best Practices

#### 1. Responsive Design
- Use relative positioning when possible
- Handle window resizing
- Test at different resolutions

#### 2. Performance
- Only update visible panels
- Cache expensive calculations
- Use efficient rendering techniques

#### 3. User Experience
- Provide clear visual feedback
- Use consistent interaction patterns
- Handle edge cases gracefully

#### 4. Code Organization
- Keep panel logic self-contained
- Use helper functions for common operations
- Follow consistent naming conventions

### Common UI Patterns

#### Modal Dialog
```lua
-- Show modal dialog
local dialog = {
    visible = true,
    x = screenWidth/2 - 200,
    y = screenHeight/2 - 100,
    width = 400,
    height = 200,
    title = "Confirmation",
    message = "Are you sure?",
    buttons = {
        {text = "Yes", onClick = function() dialog.visible = false end},
        {text = "No", onClick = function() dialog.visible = false end}
    }
}
```

#### Tabbed Interface
```lua
-- Tabbed interface
local tabs = {
    activeTab = "tab1",
    tabs = {
        {id = "tab1", name = "Tab 1", content = tab1Content},
        {id = "tab2", name = "Tab 2", content = tab2Content}
    }
}
```

#### Scrollable List
```lua
-- Scrollable list
local list = {
    items = {},
    scrollY = 0,
    itemHeight = 30,
    visibleItems = 10,
    width = 200,
    height = 300
}
```

---

This UI guide provides comprehensive information about creating and managing user interface elements. For specific implementation details, refer to the UI system source files and existing panel examples.
