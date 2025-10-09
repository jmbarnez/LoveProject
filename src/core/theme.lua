local Theme = {}
local Sound = require("src.core.sound")

-- === THEME DATA ===
Theme.colors = require("src.core.theme.colors")
Theme.ui = require("src.core.theme.ui_tokens")

-- === MODULE SETUP ===
require("src.core.theme.utilities").setup(Theme)
require("src.core.theme.scaling").setup(Theme)
require("src.core.theme.fonts").setup(Theme)
require("src.core.theme.config").setup(Theme)
require("src.core.theme.drawing").setup(Theme)
require("src.core.theme.animations").setup(Theme)
require("src.core.theme.particles").setup(Theme)
require("src.core.theme.screen_effects").setup(Theme)
require("src.core.theme.components").setup(Theme)
require("src.core.theme.interactions").setup(Theme, Sound)
require("src.core.theme.shaders").setup(Theme)

return Theme
