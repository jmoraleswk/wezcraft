-- Default theme for wezterm.
-- Monokai Pro — dark, vibrant, low eye strain.

local wezterm = require('wezterm')

local M = {}

-- =============================================================================
-- MONOKAI PRO PALETTE — single source of truth
-- =============================================================================
local palette = {
  bg         = "#333",
  bg_dark    = "#333",
  fg         = "#fcfcfa",
  muted      = "#333",
  surface    = "#333",
  red        = "#ff6188",
  green      = "#a9dc76",
  yellow     = "#ffd866",
  orange     = "#fc9867",
  blue       = "#78dce8",
  purple     = "#ab9df2",
}

function M.apply(config, constants)
    -- ======================
    -- COLORS
    -- ======================
    config.colors = {
      background = palette.bg,
      foreground = palette.fg,
      cursor_bg = palette.fg,
      cursor_border = palette.fg,
      cursor_fg = palette.bg,
      selection_bg = palette.surface,
      selection_fg = palette.fg,
      scrollbar_thumb = palette.surface,
      split = palette.surface,

      ansi = {
        palette.bg,     -- black
        palette.red,    -- red
        palette.green,  -- green
        palette.yellow, -- yellow
        palette.blue,   -- blue
        palette.purple, -- magenta
        palette.blue,   -- cyan
        palette.fg,     -- white
      },

      brights = {
        palette.muted,  -- bright black
        palette.red,    -- bright red
        palette.green,  -- bright green
        palette.yellow, -- bright yellow
        palette.orange, -- bright blue
        palette.purple, -- bright magenta
        palette.blue,   -- bright cyan
        palette.fg,     -- bright white
      },
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
      bottom = 5,
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

-- =============================================================================
-- STATUSBAR COLORS — derived from palette
-- =============================================================================
M.statusbar_colors = {
  bg_left      = palette.bg_dark,
  bg_right     = palette.bg_dark,
  fg_primary   = palette.fg,
  fg_muted     = palette.muted,
  accent       = palette.blue,
  git          = palette.green,
  battery_ok   = palette.green,
  battery_warn = palette.yellow,
  battery_crit = palette.red,
  cwd          = palette.blue,
  stat_bg      = palette.surface,
  stat_fg      = palette.blue,
}

return M
