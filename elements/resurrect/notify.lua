-- File: notify.lua
-- Cross-platform notification helper for resurrect.wezterm
--
-- Supports:
--   - macOS: osascript (native Notification Center)
--   - Windows: PowerShell (native toast notifications)
--   - Linux: notify-send (libnotify)

local wezterm = require('wezterm')
local module = {}

local function has_value(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function notify(subject, msg, urgency)
    local allowed_urgency = { 'low', 'normal', 'critical' }
    urgency = urgency or 'normal'
    if not has_value(allowed_urgency, urgency) then
        urgency = 'normal'
    end

    local platform = wezterm.target_triple

    if platform:find("darwin") then
        -- macOS: use osascript with AppleScript
        -- urgency maps to: informational (low/normal), critical
        local sound = urgency == "critical" and "Glass" or nil
        local script = string.format(
            'display notification %q with title %q',
            msg,
            subject
        )
        if sound then
            script = script .. string.format(' sound name %q', sound)
        end
        wezterm.run_child_process { 'osascript', '-e', script }

    elseif platform:find("windows") then
        -- Windows: use PowerShell toast notification
        local script = string.format(
            [[
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

            $template = @"
            <toast duration="short">
                <visual>
                    <binding template="ToastGeneric">
                        <text>$('{0}' -replace "'","''")</text>
                        <text>$('{1}' -replace "'","''")</text>
                    </binding>
                </visual>
            </toast>
"@

            $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
            $xml.LoadXml($template)
            $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('WezTerm').Show($toast)
            ]],
            subject,
            msg
        )
        wezterm.run_child_process { 'powershell', '-Command', script }

    else
        -- Linux: use notify-send
        wezterm.run_child_process {
            'notify-send',
            '-i', 'org.wezfurlong.wezterm',
            '-a', 'wezterm',
            '-u', urgency,
            subject,
            msg
        }
    end
end

module.send = notify

return module
