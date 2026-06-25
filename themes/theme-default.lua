-- Default theme for wezterm.
-- Simple theme using default colors and fonts.
-- Good starting point for creating your own theme.

local wezterm = require('wezterm')

local M = {}

function M.apply(config, constants)

    -- ======================
    -- FONT
    -- Requires: brew install --cask font-firamono-nerd-font
    -- See README.md for full setup instructions
    -- ======================
    config.font = wezterm.font("FiraMono Nerd Font")
    config.font_size = 12
    config.line_height = 1.2

    -- ======================
    -- COLORS
    -- ======================
    config.colors = {
      cursor_bg = "#ffffff",
      cursor_border = "#ffffff",
        -- background = "#282828",
        -- foreground = "#ebdbb2",
        -- cursor_fg = "#282828",
        -- selection_bg = "#665c54",
        -- selection_fg = "#ebdbb2",
    }

    -- ======================
    -- APPEARANCE
    -- ======================
    config.window_decorations = "RESIZE"
    config.hide_tab_bar_if_only_one_tab = false

    config.window_padding = {
      left = 5,
      right = 5,
      top = 5,
      bottom = 5  ,
    }

    -- background image (if exists)
    config.window_background_image = constants and constants.bg_image or nil

    -- ======================
    -- PERFORMANCE
    -- ======================
    config.max_fps = 120
    config.prefer_egl = true


    -- blur only on macOS
    if wezterm.target_triple:find("darwin") then
        config.macos_window_background_blur = 10
    end

end

return M
