local wezterm = require 'wezterm'
local constants = require 'constants.default-theme'

local command = {
  brief = "Toggle terminal transparency",
  icon  = "md_circle_opacity",
  action = wezterm.action_callback(function(window)
    local current = window:get_config_overrides() or {}
    local overrides = {
      window_background_opacity = current.window_background_opacity,
      window_background_image = current.window_background_image,
    }

    if not overrides.window_background_opacity or overrides.window_background_opacity == 1 then
      overrides.window_background_opacity = 0.5
      overrides.window_background_image = ""
    else
      overrides.window_background_opacity = 1
      overrides.window_background_image = constants.bg_image
    end

    window:set_config_overrides(overrides)
  end),
}

return command
