-- File: resurrect/config.lua
-- resurrect.wezterm configuration and settings
--
-- Inspired by Matthew Weimer's resurrect.wezterm configuration (mwop.net).
-- Enhancement and enrichment for WezCraft:
--   - Local plugin require instead of remote GitHub fetch
--   - Custom state save directory (~/.local/share/wezterm/resurrect/)
--   - Cross-platform age encryption detection (macOS/Windows/Linux)
--   - Custom pane restore: only fullscreen apps (avoids UTF-8 encoding errors)
--   - Custom keybindings: ALT+R load, SUPER+W save, ALT+SUPER+N new, ALT+D rename
--   - spawn_in_workspace for correct workspace isolation on restore
--   - restore_text disabled to prevent encoding and performance issues
--   - Added workspace creation and renaming actions (not in original)
--
-- This module:
-- * Configures the resurrect.wezterm plugin
-- * Configures custom pane restore (fullscreen apps only)
-- * Sets up encryption (age), periodic save, and state directory
-- * Returns wezterm keybinding configuration for resurrect-related actions.

local config  = {}
local wezterm = require('wezterm')

local resurrect = require('plugins.resurrect.plugin')

-- Main directory for resurrect to saved sessions.
-- By default it saves in the wezterm state directory, but I prefer to keep it
-- separate and more accessible.
resurrect.state_manager.change_state_save_dir(wezterm.home_dir .. "/.local/share/wezterm/resurrect/")

-- Custom pane restore function
-- Only restores fullscreen applications (vim, nvim, lazygit, htop, etc.)
-- This avoids encoding issues and duplicate prompts when restoring shell panes.
local function my_pane_restore(pane_tree)
    local pane = pane_tree.pane

    if pane_tree.alt_screen_active and pane_tree.process then
        pane:send_text(
            wezterm.shell_join_args(pane_tree.process.argv) .. "\r\n"
        )
    end
end

-- resurrect.wezterm encryption (disabled by default)
-- To enable:
-- 1. Install age: https://github.com/FiloSottile/age
-- 2. Generate key: age-keygen -o ~/.config/wezterm/elements/resurrect/wezterm.key
-- 3. Set enable = true below
-- 4. Update public_key with the key generated in step 2
local age_method = "age" -- default: expects age in PATH
if wezterm.target_triple:find("darwin") then
    age_method = "/opt/homebrew/bin/age" -- macOS Apple Silicon
elseif wezterm.target_triple:find("windows") then
    age_method = "C:\\Program Files\\age\\age.exe" -- Windows (adjust if needed)
end

resurrect.state_manager.set_encryption({
    enable      = false,
    method      = age_method,
    private_key = wezterm.home_dir .. "/.config/wezterm/elements/resurrect/wezterm.key",
    public_key  = "age1... YOUR_PUBLIC_KEY_HERE",
})

-- Periodic save every 5 minutes
resurrect.state_manager.periodic_save({
    interval_seconds = 300,
    save_tabs = true,
    save_windows = true,
    save_workspaces = true,
})

-- Save only 5000 lines per pane
resurrect.state_manager.set_max_nlines(5000)

-- Keybindings
config.keys = {
    -- Load saved session using fuzzy finder - ALT + r
    {
        key = "r",
        mods = "ALT",
        action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
                local session_type = string.match(id, "^([^/]+)") -- match before '/'
                id = string.match(id, "([^/]+)$") -- match after '/'
                id = string.match(id, "(.+)%..+$") -- remove file extension

                if session_type == "workspace" then
                    local state = resurrect.state_manager.load_state(id, "workspace")
                    resurrect.workspace_state.restore_workspace(state, {
                        spawn_in_workspace = true, -- CRITICAL: creates/restores the original workspace; without this everything restores into "default"
                        relative = true,
                        restore_text = false, -- Avoids encoding errors (UTF-8) and performance issues. Pane state (directories, commands, etc.) restores fine with this off.
                        resize_window = false,
                        on_pane_restore = my_pane_restore, -- Custom restore to avoid encoding errors with large text
                    })
                    wezterm.mux.set_active_workspace(id)
                elseif session_type == "window" then
                    local state = resurrect.state_manager.load_state(id, "window")
                    resurrect.window_state.restore_window(pane:window(), state, {
                        relative = true,
                        restore_text = false,
                        on_pane_restore = my_pane_restore,
                    })
                elseif session_type == "tab" then
                    local state = resurrect.state_manager.load_state(id, "tab")
                    resurrect.tab_state.restore_tab(pane:tab(), state, {
                        restore_text = false,
                        on_pane_restore = my_pane_restore,
                    })
                end
            end)
        end),
    },
    -- Save current workspace state - SUPER + w
    {
        key = "w",
        mods = "SUPER",
        action = wezterm.action_callback(function(win, pane)
            local state = resurrect.workspace_state.get_workspace_state()
            resurrect.state_manager.save_state(state)
            wezterm.log_info("Workspace state saved")
        end),
    },
    -- Create new workspace with custom name (does NOT auto-save) - ALT + SUPER + n
    {
        key = "n",
        mods = "ALT|SUPER",
        action = wezterm.action.PromptInputLine({
            description = "New workspace name:",
            action = wezterm.action_callback(function(window, pane, line)
                if line and line ~= "" then
                    window:perform_action(wezterm.action.SwitchToWorkspace({ name = line }), pane)
                end
            end),
        }),
    },
    -- Rename current workspace - ALT + d
    {
        key = "d",
        mods = "ALT",
        action = wezterm.action.PromptInputLine({
            description = "Rename current workspace:",
            action = wezterm.action_callback(function(window, pane, line)
                if line and line ~= "" then
                    wezterm.mux.rename_workspace(
                        wezterm.mux.get_active_workspace(),
                        line
                    )
                end
            end),
        }),
    },
    -- Delete a saved session using fuzzy finder - SUPER + d
    {
        key = "d",
        mods = "SUPER",
        action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(
                win,
                pane,
                function(id)
                    resurrect.state_manager.delete_state(id)
                end,
                {
                    title             = "Delete workspace, window or tab",
                    description       = "Select session to delete and press Enter = accept, Esc = cancel, / = filter",
                    fuzzy_description = "Search session to delete: ",
                    is_fuzzy          = true,
                }
            )
        end),
    },
}

require('elements.resurrect.events')

return config
