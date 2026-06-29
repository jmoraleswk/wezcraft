local wezterm = require("wezterm")
local globals = require("constants.global")

local M = {}


M._active_theme = nil

function M.load_active_theme()
  local file = io.open(globals.ACTIVE_THEME_FILE, "r")
  if not file then
    M._active_theme = "default"
    return M._active_theme
  end
  local content = file:read("*a")
  file:close()
  local ok, data = pcall(wezterm.json_parse, content)
  M._active_theme = (ok and data.active_theme) or "default"
  return M._active_theme
end

function M.get_active_theme()
  -- Always read from file to stay in sync after reload
  local file = io.open(globals.ACTIVE_THEME_FILE, "r")
  if not file then
    return "default"
  end
  local content = file:read("*a")
  file:close()
  local ok, data = pcall(wezterm.json_parse, content)
  return (ok and data.active_theme) or "default"
end

--- Returns the statusbar color palette for the active theme.
--- Falls back to default theme colors if the active theme module doesn't export them.
function M.get_statusbar_colors()
  local theme_name = M.get_active_theme()
  local ok, theme_module = pcall(require, "themes.theme-" .. theme_name)
  if ok and theme_module and theme_module.statusbar_colors then
    return theme_module.statusbar_colors
  end
  -- Fallback to default theme
  local ok_default, default_module = pcall(require, "themes.theme-default")
  if ok_default and default_module and default_module.statusbar_colors then
    return default_module.statusbar_colors
  end
  -- Ultimate fallback: hardcoded defaults
  return {
    bg_left = "#1a1b26", bg_right = "#1a1b26",
    fg_primary = "#c0caf5", fg_muted = "#565f89",
    accent = "#7aa2f7", git = "#9ece6a",
    battery_ok = "#9ece6a", battery_warn = "#e0af68", battery_crit = "#f7768e",
    cwd = "#bb9af7", stat_bg = "#1f2335", stat_fg = "#7aa2f7",
  }
end

return M
