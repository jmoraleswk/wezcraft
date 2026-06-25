local wezterm = require('wezterm')
local config = wezterm.config_builder()

-- ======================
-- BASE
-- ======================
config.window_close_confirmation = "AlwaysPrompt"

config.status_update_interval = 5000

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 2000 }

config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- Font (single source of truth)
local fonts = require("constants.fonts")
local emoji_font = wezterm.target_triple:find("darwin") and fonts.EMOJI_FONT_MACOS or fonts.EMOJI_FONT_WINDOWS
config.font = wezterm.font_with_fallback {
  { family = fonts.MAIN_FONT, weight = fonts.MAIN_FONT_WEIGHT },
  { family = emoji_font },
}

-- ======================
-- THEME
-- ======================
local theme_default = require("themes.theme-default")
local theme_kanagawa = require("themes.theme-kanagawa")
local theme_utils = require("utils.theme")
local constants_default = require("constants.default-theme")

local active_theme = theme_utils.load_active_theme()

if active_theme == "kanagawa" then
  theme_kanagawa.apply(config, constants_default)
else
  theme_default.apply(config, constants_default)
end

-- ======================
-- TOGGLE THEME (runtime)
-- ======================
wezterm.on("toggle-theme", function(window)
  local current = theme_utils.get_active_theme()
  local next = current == "kanagawa" and "default" or "kanagawa"
  local path = wezterm.config_dir .. "/themes/active-theme.json"
  local file = io.open(path, "w")
  file:write(wezterm.json_encode({
    active_theme = next
  }))
  file:close()
  wezterm.reload_configuration()
end)

-- ======================
-- STATUS BAR
-- ======================
local status_utils = require("utils.status")

wezterm.on("update-status", function(window, pane)
  local status_message = status_utils.get_status_message(window)
  if status_message then
    window:set_right_status(status_message)
    return
  end

  local theme = theme_utils.get_active_theme()
  if theme == "kanagawa" then
    local ok_cwd, cwd = pcall(function()
      return pane and pane:get_current_working_dir()
    end)
    local dir = cwd and cwd.file_path or ""
    if not ok_cwd then
      dir = ""
    end
    window:set_right_status("  " .. dir .. "  ")
  else
    window:set_right_status("")
  end
end)

-- ======================
-- COMMAND PALETTE
-- ======================
local ok_commands, commands = pcall(require, "commands")
if ok_commands and type(commands) == "table" then
  wezterm.on("augment-command-palette", function()
    return commands
  end)
end

-- ======================
-- SHORTCUTS
-- ======================
config.keys = {
  -- Cerrar el panel actual (pide confirmación)
  {
    key = 'w',
    mods = 'CMD|SHIFT',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  -- Dividir panel horizontalmente
  {
    key = '2',
    mods = 'CTRL|CMD',
    action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" },
  },
  -- Dividir panel verticalmente
  {
    key = '5',
    mods = 'CTRL|CMD',
    action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" },
  },
  -- Ir al FINAL de la palabra (Option + Flecha Derecha)
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = wezterm.action.SendKey { key = 'f', mods = 'ALT' },
  },
  -- Ir al INICIO de la palabra (Option + Flecha Izquierda)
  {
    key = 'LeftArrow',
    mods = 'OPT',
    action = wezterm.action.SendKey { key = 'b', mods = 'ALT' },
  },
  -- virgulilla (ALT + ñ)
  {
    key = 'ñ',
    mods = 'ALT',
    action = wezterm.action.SendString("~"),
  },
  -- arroba (ALT + 2)
  {
    key = '2',
    mods = 'ALT',
    action = wezterm.action.SendString("@"),
  },
  -- barra invertida (ALT + º)
  {
    key = 'º',
    mods = 'ALT',
    action = wezterm.action.SendString("\\"),
  },
  -- barra invertida (ALT + 3)
  {
    key = '3',
    mods = 'ALT',
    action = wezterm.action.SendString("#"),
  },
}

return config
