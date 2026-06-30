local wezterm = require('wezterm')
local config = wezterm.config_builder()

-- ======================
-- BASE
-- ======================
config.window_close_confirmation = "AlwaysPrompt"

config.status_update_interval = 3000

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
local globals = require("constants.global")
local constants_default = require("constants.default-theme")

local active_theme = theme_utils.load_active_theme()

if active_theme == "kanagawa" then
  theme_kanagawa.apply(config, constants_default)
else
  theme_default.apply(config, constants_default)
end

-- ======================
-- STATUS BAR
-- ======================
local statusbar = require("elements.statusbar.config")
statusbar.setup(wezterm, config)

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
local theme_switcher = require("elements.theme-switcher")

config.keys = {
  -- Close current panel (requires confirmation)
  {
    key = 'w',
    mods = 'CMD|SHIFT',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  -- Split panel horizontally
  {
    key = '2',
    mods = 'CTRL|CMD',
    action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" },
  },
  -- Split panel vertically
  {
    key = '5',
    mods = 'CTRL|CMD',
    action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" },
  },
  -- Switch theme (ALT + T)
  {
    key = 't',
    mods = 'ALT',
    action = wezterm.action_callback(function(window, pane)
      theme_switcher.pick_theme(window, pane)
    end),
  },
  -- Go to END of word (Option + Right Arrow)
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = wezterm.action.SendKey { key = 'f', mods = 'ALT' },
  },
  -- Go to START of word (Option + Left Arrow)
  {
    key = 'LeftArrow',
    mods = 'OPT',
    action = wezterm.action.SendKey { key = 'b', mods = 'ALT' },
  },
  -- tilde (ALT + ñ)
  {
    key = 'ñ',
    mods = 'ALT',
    action = wezterm.action.SendString("~"),
  },
  -- at sign (ALT + 2)
  {
    key = '2',
    mods = 'ALT',
    action = wezterm.action.SendString("@"),
  },
  -- backslash (ALT + º)
  {
    key = 'º',
    mods = 'ALT',
    action = wezterm.action.SendString("\\"),
  },
  -- backslash (ALT + 3)
  {
    key = '3',
    mods = 'ALT',
    action = wezterm.action.SendString("#"),
  },
}

-- ======================
-- RESURRECT (session persistence)
-- ======================
local ok_resurrect, resurrect_config = pcall(require, "elements.resurrect.config")
if ok_resurrect and resurrect_config and resurrect_config.keys then
  for _, key in ipairs(resurrect_config.keys) do
    table.insert(config.keys, key)
  end
end

return config
