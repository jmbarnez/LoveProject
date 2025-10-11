local Strings = {}
Strings.__index = Strings

-- Current language (default: English)
Strings.currentLanguage = "en"

-- Fallback language
Strings.fallbackLanguage = "en"

-- Available languages
Strings.languages = {
    en = "English",
    -- Add more languages here as needed
    -- es = "Español",
    -- fr = "Français",
    -- de = "Deutsch",
}

-- String categories
Strings.categories = {
    UI = "ui",
    ERRORS = "errors",
    GAME_STATES = "game_states",
    NOTIFICATIONS = "notifications",
    SETTINGS = "settings",
    THEMES = "themes",
    CONTROLS = "controls",
    ITEMS = "items",
    MISC = "misc"
}

-- Localized strings database
local strings = {
    en = {
        -- UI Category
        [Strings.categories.UI] = {
            -- Settings Panel
            settings_title = "Settings",
            graphics_settings = "Graphics Settings",
            audio_settings = "Audio Settings",
            controls = "Controls",
            keybindings = "Keybindings",
            keybindings_instruction = "(Click to change)",
            apply_button = "Apply",
            select_crosshair = "Select Crosshair",
            choose_crosshair = "Choose Crosshair",
            done_button = "Done",
            back_button = "← Back",

            -- Volume labels
            master_volume = "Master Volume:",
            sfx_volume = "SFX Volume:",
            music_volume = "Music Volume:",

            -- Graphics options
            vsync = "VSync:",
            max_fps = "Max FPS:",
            display_mode = "Display Mode:",
            resolution = "Resolution:",
            crosshair = "Crosshair:",
            accent_color = "Accent Color:",
            show_helpers = "Show Helpers:",

            -- Toggle states
            on = "On",
            off = "Off",
            unlimited = "Unlimited",

            -- Main menu
            new_game = "NEW GAME",
            load_game = "LOAD GAME",
            game_title = "NOVUS",
            version = "v0.40",

            -- Common UI elements
            close = "Close",
            cancel = "Cancel",
            confirm = "Confirm",
            save = "Save",
            load = "Load",
            delete = "Delete",
            edit = "Edit",
            create = "Create",
            exit = "Exit",
        },

        -- Errors Category
        [Strings.categories.ERRORS] = {
            insufficient_funds = "Insufficient funds",
            insufficient_funds_warp = "Insufficient funds for warp",
            insufficient_holdings = "Insufficient holdings for sale",
            trade_execution_failed = "Trade execution failed",
            settings_save_failed = "Failed to save settings",
            settings_load_failed = "Failed to load settings",
            file_not_found = "File not found",
            invalid_input = "Invalid input",
            network_error = "Network error",
            connection_lost = "Connection lost",
            save_corrupted = "Save file corrupted",
            permission_denied = "Permission denied",
            disk_full = "Disk full",
            unknown_error = "Unknown error",
        },

        -- Game States Category
        [Strings.categories.GAME_STATES] = {
            loading = "Loading...",
            saving = "Saving...",
            paused = "Paused",
            game_over = "Game Over",
            victory = "Victory",
            docked = "Docked",
            in_space = "In Space",
            warping = "Warping",
            mining = "Mining",
            trading = "Trading",
            combat = "Combat",
            exploring = "Exploring",
        },

        -- Notifications Category
        [Strings.categories.NOTIFICATIONS] = {
            settings_applied = "Settings applied successfully!",
            accent_color_changed = "Accent color changed to",
            item_purchased = "Item purchased",
            item_sold = "Item sold",
            quest_completed = "Quest completed",
            level_up = "Level up!",
            experience_gained = "Experience gained",
            credits_earned = "Credits earned",
            damage_taken = "Damage taken",
            shield_damaged = "Shield damaged",
            ship_repaired = "Ship repaired",
            cargo_full = "Cargo full",
            fuel_low = "Fuel low",
            connection_established = "Connection established",
            connection_lost = "Connection lost",
            player_joined = "Player joined",
            player_left = "Player left",
        },

        -- Settings Category
        [Strings.categories.SETTINGS] = {
            -- Resolution and display
            resolution = "Resolution",
            fullscreen = "Fullscreen",
            windowed = "Windowed",
            borderless = "Borderless",
            borderless_fullscreen = "Fullscreen",

            -- Graphics quality
            low = "Low",
            medium = "Medium",
            high = "High",
            ultra = "Ultra",

            -- Audio settings
            audio_quality = "Audio Quality",
            sample_rate = "Sample Rate",
            buffer_size = "Buffer Size",

            -- Control settings
            mouse_sensitivity = "Mouse Sensitivity",
            invert_mouse = "Invert Mouse",
            key_repeat_delay = "Key Repeat Delay",
            key_repeat_rate = "Key Repeat Rate",
        },

        -- Themes Category
        [Strings.categories.THEMES] = {
            cyan_lavender = "Cyan/Lavender",
            blue_purple = "Blue/Purple",
            green_emerald = "Green/Emerald",
            red_orange = "Red/Orange",
            monochrome = "Monochrome",
        },

        -- Controls Category
        [Strings.categories.CONTROLS] = {
            toggle_cargo = "Toggle Cargo",
            toggle_skills = "Toggle Skills",
            toggle_map = "Toggle Map",
            dock = "Dock",
            hotbar_1 = "Hotbar Slot 1",
            hotbar_2 = "Hotbar Slot 2",
            hotbar_3 = "Hotbar Slot 3",
            hotbar_4 = "Hotbar Slot 4",
            hotbar_5 = "Hotbar Slot 5",
            hotbar_6 = "Hotbar Slot 6",
            hotbar_7 = "Hotbar Slot 7",
            press_key = "Press key...",
        },

        -- Items Category
        [Strings.categories.ITEMS] = {
            -- Resources
            ore_palladium = "Palladium Ore",
            ore_tritanium = "Tritanium Ore",
            scraps = "Scraps",

            -- Equipment
            shield_module_basic = "Basic Shield Module",
            node_wallet = "Node Wallet",

            -- Categories
            weapons = "Weapons",
            shields = "Shields",
            engines = "Engines",
            cargo = "Cargo",
            resources = "Resources",
            consumables = "Consumables",
        },

        -- Misc Category
        [Strings.categories.MISC] = {
            press_any_key = "Press any key to continue",
            loading_assets = "Loading assets...",
            initializing = "Initializing...",
            connecting = "Connecting...",
            disconnected = "Disconnected",
            retry = "Retry",
            continue = "Continue",
            restart = "Restart",
            quit = "Quit",
            yes = "Yes",
            no = "No",
            ok = "OK",
            error = "Error",
            warning = "Warning",
            info = "Info",
            success = "Success",
        }
    }
}

-- Add more languages here as needed
-- Example:
-- es = {
--     [Strings.categories.UI] = {
--         settings_title = "Configuración",
--         -- ... other Spanish translations
--     }
-- }

-- Utility functions

--- Get a localized string by category and key
-- @param category string: The category of the string (e.g., Strings.categories.UI)
-- @param key string: The key of the string
-- @param params table: Optional parameters for string formatting
-- @return string: The localized string, or the key if not found
function Strings.get(category, key, params)
    if not category or not key then
        return key or ""
    end

    -- Try current language first
    local langStrings = strings[Strings.currentLanguage]
    if langStrings and langStrings[category] and langStrings[category][key] then
        local str = langStrings[category][key]
        if params then
            return Strings.format(str, params)
        end
        return str
    end

    -- Try fallback language
    if Strings.currentLanguage ~= Strings.fallbackLanguage then
        langStrings = strings[Strings.fallbackLanguage]
        if langStrings and langStrings[category] and langStrings[category][key] then
            local str = langStrings[category][key]
            if params then
                return Strings.format(str, params)
            end
            return str
        end
    end

    -- Return key as fallback
    return key
end

--- Get a UI string
-- @param key string: The UI string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized UI string
function Strings.getUI(key, params)
    return Strings.get(Strings.categories.UI, key, params)
end

--- Get an error string
-- @param key string: The error string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized error string
function Strings.getError(key, params)
    return Strings.get(Strings.categories.ERRORS, key, params)
end

--- Get a game state string
-- @param key string: The game state string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized game state string
function Strings.getGameState(key, params)
    return Strings.get(Strings.categories.GAME_STATES, key, params)
end

--- Get a notification string
-- @param key string: The notification string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized notification string
function Strings.getNotification(key, params)
    return Strings.get(Strings.categories.NOTIFICATIONS, key, params)
end

--- Get a settings string
-- @param key string: The settings string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized settings string
function Strings.getSetting(key, params)
    return Strings.get(Strings.categories.SETTINGS, key, params)
end

--- Get a theme string
-- @param key string: The theme string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized theme string
function Strings.getTheme(key, params)
    return Strings.get(Strings.categories.THEMES, key, params)
end

--- Get a control string
-- @param key string: The control string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized control string
function Strings.getControl(key, params)
    return Strings.get(Strings.categories.CONTROLS, key, params)
end

--- Get an item string
-- @param key string: The item string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized item string
function Strings.getItem(key, params)
    return Strings.get(Strings.categories.ITEMS, key, params)
end

--- Get a miscellaneous string
-- @param key string: The misc string key
-- @param params table: Optional parameters for string formatting
-- @return string: The localized misc string
function Strings.getMisc(key, params)
    return Strings.get(Strings.categories.MISC, key, params)
end

--- Format a string with parameters (simple placeholder replacement)
-- @param str string: The string to format
-- @param params table: Parameters to replace in the string
-- @return string: The formatted string
function Strings.format(str, params)
    if not str or not params then
        return str
    end

    local result = str
    for key, value in pairs(params) do
        result = result:gsub("{" .. key .. "}", tostring(value))
    end
    return result
end

--- Set the current language
-- @param language string: The language code to set
function Strings.setLanguage(language)
    if strings[language] then
        Strings.currentLanguage = language
    end
end

--- Get the current language
-- @return string: The current language code
function Strings.getCurrentLanguage()
    return Strings.currentLanguage
end

--- Get available languages
-- @return table: A table of available language codes and names
function Strings.getAvailableLanguages()
    local result = {}
    for code, name in pairs(Strings.languages) do
        result[code] = name
    end
    return result
end

--- Check if a language is available
-- @param language string: The language code to check
-- @return boolean: True if the language is available
function Strings.isLanguageAvailable(language)
    return strings[language] ~= nil
end

--- Add a new string to the database
-- @param language string: The language code
-- @param category string: The category
-- @param key string: The string key
-- @param value string: The string value
function Strings.addString(language, category, key, value)
    if not strings[language] then
        strings[language] = {}
    end
    if not strings[language][category] then
        strings[language][category] = {}
    end
    strings[language][category][key] = value
end

--- Load strings from a file
-- @param filename string: The filename to load from
function Strings.loadFromFile(filename)
    if love.filesystem.getInfo(filename) then
        local success, result = pcall(love.filesystem.load, filename)
        if success and result then
            local loadedStrings = result()
            for lang, categories in pairs(loadedStrings) do
                if not strings[lang] then
                    strings[lang] = {}
                end
                for category, keys in pairs(categories) do
                    if not strings[lang][category] then
                        strings[lang][category] = {}
                    end
                    for key, value in pairs(keys) do
                        strings[lang][category][key] = value
                    end
                end
            end
        end
    end
end

--- Save strings to a file
-- @param filename string: The filename to save to
function Strings.saveToFile(filename)
    local success = love.filesystem.write(filename, "return " .. serialize(strings))
    return success
end

-- Helper function for serialization (if not available)
function serialize(obj)
    local lua = ""
    local t = type(obj)
    if t == "number" then
        lua = lua .. obj
    elseif t == "boolean" then
        lua = lua .. tostring(obj)
    elseif t == "string" then
        lua = lua .. string.format("%q", obj)
    elseif t == "table" then
        lua = lua .. "{\n"
        for k, v in pairs(obj) do
            lua = lua .. "  [" .. serialize(k) .. "] = " .. serialize(v) .. ",\n"
        end
        local metatable = getmetatable(obj)
        if metatable ~= nil and type(metatable.__index) == "table" then
            for k, v in pairs(metatable.__index) do
                lua = lua .. "  [" .. serialize(k) .. "] = " .. serialize(v) .. ",\n"
            end
        end
        lua = lua .. "}"
    elseif t == "nil" then
        return "nil"
    else
        error("cannot serialize a " .. t)
    end
    return lua
end

return Strings