-- File: commands/switch-theme.lua
-- Command palette entry for theme switcher

local wezterm = require("wezterm")
local theme_switcher = require("elements.theme-switcher")

local command = {
    brief = "Switch between available themes",
    icon = "md_palette",
    action = wezterm.action_callback(function(window, pane)
        theme_switcher.pick_theme(window, pane)
    end),
}

return command
