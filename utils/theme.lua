local wezterm = require("wezterm")

local M = {}


M._active_theme = nil

function M.load_active_theme()
  local path = wezterm.config_dir .. "/themes/active-theme.json"
  local file = io.open(path, "r")
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
  return M._active_theme or "default"
end

return M
