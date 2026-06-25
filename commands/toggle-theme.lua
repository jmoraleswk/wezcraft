local wezterm = require 'wezterm'

local command = {
  brief = "Toggle theme between default and kanagawa",
  icon  = "md_palette",
  action = wezterm.action.EmitEvent("toggle-theme"),
}

return command
