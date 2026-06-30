-- File: elements/theme-switcher/init.lua
-- Dynamic theme switcher with fuzzy picker
-- Scans themes/ directory and lets user select any available theme

local wezterm = require("wezterm")
local globals = require("constants.global")

local M = {}

--- Scan themes directory for available themes
--- @return table Array of {id, label} for InputSelector
function M.scan_themes()
    local themes = {}
    local themes_dir = wezterm.config_dir .. "/themes"

    -- Read all files in themes directory
    local handle = io.popen('ls "' .. themes_dir .. '"/*.lua 2>/dev/null')
    if not handle then
        return themes
    end

    for file in handle:lines() do
        -- Extract theme name from filename: /path/theme-kanagawa.lua -> kanagawa
        local theme_name = file:match("theme%-(.+)%.lua$")
        if theme_name then
            table.insert(themes, {
                id = theme_name,
                label = theme_name,
            })
        end
    end
    handle:close()

    -- Sort themes alphabetically
    table.sort(themes, function(a, b)
        return a.label < b.label
    end)

    return themes
end

--- Get current active theme
--- @return string Theme name
function M.get_current_theme()
    local file = io.open(globals.ACTIVE_THEME_FILE, "r")
    if not file then
        return "default"
    end
    local content = file:read("*a")
    file:close()
    local ok, data = pcall(wezterm.json_parse, content)
    return (ok and data.active_theme) or "default"
end

--- Apply selected theme
--- @param theme_name string Theme name to apply
--- @param window table WezTerm window object
function M.apply_theme(theme_name, window)
    local file, err = io.open(globals.ACTIVE_THEME_FILE, "w")
    if not file then
        local msg = "Failed to write active theme: " .. (err or "unknown error")
        wezterm.log_error(msg)
        return false
    end

    file:write(wezterm.json_encode({
        active_theme = theme_name
    }))
    file:close()

    wezterm.reload_configuration()
    return true
end

--- Show theme picker using InputSelector
--- @param window table WezTerm window object
--- @param pane table WezTerm pane object
function M.pick_theme(window, pane)
    local themes = M.scan_themes()

    if #themes == 0 then
        wezterm.log_error("No themes found in themes/ directory")
        return
    end

    -- Mark current theme with indicator
    local current = M.get_current_theme()
    for _, theme in ipairs(themes) do
        if theme.id == current then
            theme.label = theme.label .. " (current)"
        end
    end

    -- Show fuzzy picker
    window:perform_action(
        wezterm.action.InputSelector({
            title = "Switch Theme",
            choices = themes,
            fuzzy_description = "Search themes...",
            action = wezterm.action_callback(function(win, pane, id, label)
                if id then
                    M.apply_theme(id, win)
                end
            end),
        }),
        pane
    )
end

return M
