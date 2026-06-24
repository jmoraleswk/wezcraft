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