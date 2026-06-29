local wezterm = require("wezterm")
local M = {}

M.ACTIVE_THEME_FILE = wezterm.config_dir .. "/themes/active-theme.json"

M.STATUS_BAR = {
  status_time_error = 3, -- seconds to show error message in status bar
  stats_file = "/tmp/wezterm_stats.txt", -- path to stats file from update_stats.sh
}

return M
