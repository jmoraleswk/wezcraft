-- =============================================================================
-- WEZTERM STATUS BAR
--
-- SETUP: require("elements.statusbar.config").setup(wezterm, config)
--
-- LEFT:  workspace
-- RIGHT: cwd | git | battery | stats | clock
-- =============================================================================

local M = {}

-- =============================================================================
-- CONFIGURATION — enable or disable each section here
-- =============================================================================

local SHOW_WORKSPACE  = true     -- active workspace name (left)
local SHOW_BATTERY    = false    -- battery level (right, skipped on desktop)
local SHOW_CLOCK      = true     -- HH:MM time (right)
local SHOW_GIT        = false    -- git branch of current directory (right)
local CLOCK_FORMAT    = "%H:%M"  -- time format: "%H:%M:%S" to include seconds
local SHOW_CWD        = true     -- absolute path of current directory (right)

-- Separator between sections (use "  " if your font doesn't have these glyphs)
local SEP = "  │  "

-- =============================================================================
-- COLOR PALETTE — loaded dynamically from the active theme
-- Each theme exports statusbar_colors in themes/theme-*.lua
-- Colors are refreshed on each update-status call to reflect theme changes
-- =============================================================================

local theme_utils = require("utils.theme")

-- =============================================================================
-- INTERNAL HELPERS
-- =============================================================================

-- Battery icon based on level and charging state
local function battery_icon(pct, charging)
  if charging then return "⚡" end
  if pct > 80  then return "█" end
  if pct > 60  then return "▓" end
  if pct > 40  then return "▒" end
  if pct > 20  then return "░" end
  return "▪"
end

-- Battery color based on level
local function battery_color(pct, colors)
  if pct < 10 then return colors.battery_crit end
  if pct < 20 then return colors.battery_warn end
  return colors.battery_ok
end

-- =============================================================================
-- SETUP
-- =============================================================================

function M.setup(wezterm_module, _config)
  local status_utils = require("utils.status")
  local global_constants = require("constants.global")
  local stats_file = global_constants.STATUS_BAR.stats_file

  wezterm_module.on("update-status", function(window, pane)
    -- Load colors fresh each time to reflect theme changes
    local COLORS = theme_utils.get_statusbar_colors()

    -- Check for temporary status message first
    local status_message, message_color = status_utils.get_status_message(window)
    if status_message then
      local msg_elements = {}
      if message_color then
        table.insert(msg_elements, { Foreground = { Color = message_color } })
      end
      table.insert(msg_elements, { Text = status_message })
      window:set_right_status(wezterm_module.format(msg_elements))
      return
    end

    -- LEFT: workspace
    local left_elements = {}
    table.insert(left_elements, { Background = { Color = COLORS.bg_left } })

    if SHOW_WORKSPACE then
      local ws = window:active_workspace()
      table.insert(left_elements, { Foreground = { Color = COLORS.accent } })
      table.insert(left_elements, { Text = "  " .. ws .. " " })
    end

    window:set_left_status(wezterm_module.format(left_elements))

    -- RIGHT: cwd | git | battery | stats | clock
    local right_elements = {}
    table.insert(right_elements, { Background = { Color = COLORS.bg_right } })

    -- CWD
    if SHOW_CWD then
      local cwd_uri = pane:get_current_working_dir()
      if cwd_uri then
        local cwd = cwd_uri.file_path or tostring(cwd_uri):gsub("file://[^/]*", "")
        if cwd and cwd ~= "" then
          -- Normalize: remove trailing slash if exists (e.g. "/Users/foo/" → "/Users/foo")
          cwd = cwd:gsub("/$", "")
 
          -- Replace $HOME with ~ using direct comparison (not Lua patterns)
          -- to avoid issues with special characters in the path
          local home = os.getenv("HOME") or ""
          if home ~= "" then
            -- Also remove trailing slash from HOME just in case
            home = home:gsub("/$", "")
            if cwd == home then
              cwd = "~"
            elseif cwd:sub(1, #home + 1) == home .. "/" then
              cwd = "~/" .. cwd:sub(#home + 2)
            end
          end
 
          table.insert(right_elements, { Foreground = { Color = COLORS.cwd } })
          table.insert(right_elements, { Text = "  " .. cwd })
          table.insert(right_elements, { Foreground = { Color = COLORS.fg_muted } })
          table.insert(right_elements, { Text = SEP })
        end
      end
    end

    -- GIT
    if SHOW_GIT then
      local cwd_uri = pane:get_current_working_dir()
      if cwd_uri then
        local cwd = cwd_uri.file_path
        if cwd then
          local ok, branch = pcall(function()
            local h = io.popen(
              "git -C " .. wezterm_module.shell_quote_arg(cwd) ..
              " branch --show-current 2>/dev/null"
            )
            if h then
              local r = h:read("*l")
              h:close()
              return r
            end
          end)
          if ok and branch and branch ~= "" then
            table.insert(right_elements, { Foreground = { Color = COLORS.git } })
            table.insert(right_elements, { Text = "  " .. branch })
            table.insert(right_elements, { Foreground = { Color = COLORS.fg_muted } })
            table.insert(right_elements, { Text = SEP })
          end
        end
      end
    end

    -- BATTERY
    if SHOW_BATTERY then
      local ok, bat_list = pcall(wezterm_module.battery_info)
      if ok and bat_list and #bat_list > 0 then
        local bat      = bat_list[1]
        local pct      = math.floor(bat.state_of_charge * 100)
        local charging = bat.state == "Charging" or bat.state == "Full"
        local icon     = battery_icon(pct, charging)
        local color    = battery_color(pct, COLORS)
        table.insert(right_elements, { Foreground = { Color = color } })
        table.insert(right_elements, { Text = icon .. " " .. pct .. "%" })
        table.insert(right_elements, { Foreground = { Color = COLORS.fg_muted } })
        table.insert(right_elements, { Text = SEP })
      end
    end

    -- STATS (from external script)
    local file = io.open(stats_file, "r")
    local stats_text = nil
    if file then
      stats_text = file:read("*l")
      file:close()
    end

    if stats_text and stats_text ~= "" then
      table.insert(right_elements, "ResetAttributes")
      table.insert(right_elements, { Text = " " })
      table.insert(right_elements, { Foreground = { Color = COLORS.stat_bg } })
      table.insert(right_elements, { Text = "" })
      table.insert(right_elements, { Background = { Color = COLORS.stat_bg } })
      table.insert(right_elements, { Foreground = { Color = COLORS.stat_fg } })
      table.insert(right_elements, { Attribute = { Intensity = "Bold" } })
      table.insert(right_elements, { Text = " " .. stats_text .. " " })
      table.insert(right_elements, "ResetAttributes")
      table.insert(right_elements, { Foreground = { Color = COLORS.stat_bg } })
      table.insert(right_elements, { Text = "" })
      table.insert(right_elements, "ResetAttributes")
      table.insert(right_elements, { Foreground = { Color = COLORS.fg_muted } })
      table.insert(right_elements, { Text = SEP })
    end

    -- CLOCK
    if SHOW_CLOCK then
      local time = wezterm_module.strftime(CLOCK_FORMAT)
      table.insert(right_elements, { Foreground = { Color = COLORS.accent } })
      table.insert(right_elements, { Text = time .. "  " })
    end

    window:set_right_status(wezterm_module.format(right_elements))
  end)
end

return M