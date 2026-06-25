-- TODO: Only register when default theme is active (currently checks at runtime)

local wezterm = require 'wezterm'
local constants = require 'constants.default-theme'
local theme_utils = require("utils.theme")
local status_utils = require("utils.status")


local command = {
  brief = "Toggle terminal transparency",
  icon  = "md_circle_opacity",
  action = wezterm.action_callback(function(window)
    local current = window:get_config_overrides() or {}
    local overrides = {
      window_background_opacity = current.window_background_opacity,
      window_background_image = current.window_background_image,
    }
    local theme = theme_utils.get_active_theme()

    -- only toggle in default theme
    if theme ~= "default" then
      window:toast_notification(
        "WezTerm",
        "Only available in \"default\" theme",
        nil,
        3000
      )
      status_utils.set_status_message(
        window,
        "Only available in \"default\" theme (current: " .. theme .. ")",
        1
      )
      return
    end

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
