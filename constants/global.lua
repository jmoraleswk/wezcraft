local wezterm = require("wezterm")
local M = {}

M.ACTIVE_THEME_FILE = wezterm.config_dir .. "/themes/active-theme.json"

-- Cross-platform stats file path
local function get_stats_file()
  -- Check if we're on Windows (TEMP exists with drive letter)
  local temp = os.getenv("TEMP")
  if temp and temp:match("^[A-Z]:") then
    -- Windows: use %TEMP%\wezterm_stats.txt
    return temp .. "\\wezterm_stats.txt"
  else
    -- macOS/Linux: both scripts write to /tmp/wezterm_stats.txt
    return "/tmp/wezterm_stats.txt"
  end
end

M.STATUS_BAR = {
  status_time_error = 3, -- seconds to show error message in status bar
  stats_file = get_stats_file(), -- path to stats file from update_stats.sh
}

return M
