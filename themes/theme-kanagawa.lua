-- Kanagawa Theme for WezTerm
-- Dark palette inspired by the Kanagawa color scheme

local wezterm = require('wezterm')

local M = {}

function M.apply(config, constants)
  -- APPEARANCE
  config.window_decorations = "RESIZE"
  config.hide_tab_bar_if_only_one_tab = false

  config.window_background_opacity = 0.85
  config.text_background_opacity = 0.85

  if wezterm.target_triple:find("darwin") then
    config.macos_window_background_blur = 10
  end

  config.window_padding = {
    left = 8,
    right = 8,
    top = 0,
    bottom = 6,
  }

  -- COLORS
  config.colors = {
    background = "#1f1f28",
    foreground = "#dcd7ba",

    cursor_bg = "#c8c093",
    cursor_fg = "#1f1f28",

    selection_bg = "#2d4f67",

    ansi = {
      "#090618", "#c34043", "#76946a", "#c0a36e",
      "#7e9cd8", "#957fb8", "#6a9589", "#c8c093",
    },

    brights = {
      "#727169", "#e82424", "#98bb6c", "#e6c384",
      "#7fb4ca", "#938aa9", "#7aa89f", "#dcd7ba",
    },
  }

  config.colors.tab_bar = {
    background = "#1f1f28",
    active_tab = {
      bg_color = "#2d4f67",
      fg_color = "#dcd7ba",
    },
    inactive_tab = {
      bg_color = "#1f1f28",
      fg_color = "#727169",
    },
  }

  -- TAB BAR
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = true
  config.show_tabs_in_tab_bar = true
  config.show_new_tab_button_in_tab_bar = false

  -- UX
  config.default_cursor_style = "BlinkingBlock"
  config.cursor_blink_rate = 500

  config.animation_fps = 60
  config.max_fps = 60

  config.enable_scroll_bar = false
  config.window_close_confirmation = "AlwaysPrompt"
end

-- =============================================================================
-- STATUSBAR COLORS — matches this theme's palette
-- =============================================================================
M.statusbar_colors = {
  bg_left      = "#1f1f28",
  bg_right     = "#1f1f28",
  fg_primary   = "#dcd7ba",
  fg_muted     = "#727169",
  accent       = "#7e9cd8",
  git          = "#76946a",
  battery_ok   = "#98bb6c",
  battery_warn = "#c0a36e",
  battery_crit = "#c34043",
  cwd          = "#957fb8",
  stat_bg      = "#2d4f67",
  stat_fg      = "#7e9cd8",
}

return M
