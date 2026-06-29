# WezTerm Stats Daemon (Windows)
# NOTE: This path must match constants.global.STATUS_BAR.stats_file in config.lua
OUTPUT = Join-Path $env:TEMP "wezterm_stats.txt"

# Get CPU core count for accurate percentage
$cpuCount = (Get-CimInstance Win32_Processor).NumberOfCores

# Function to get CPU usage
function Get-CpuUsage {
    # Sample 1
    $cpu1 = Get-Counter '\Processor(_Total)\% Processor Time'
    Start-Sleep -Seconds 1
    # Sample 2
    $cpu2 = Get-Counter '\Processor(_Total)\% Processor Time'
    
    # Return the instantaneous value (second sample)
    return [math]::Round($cpu2.CounterSamples.CookedValue, 0)
}

# Function to get memory usage
function Get-MemoryUsage {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalBytes = $os.TotalVisibleMemorySize * 1024
    $freeBytes = $os.FreePhysicalMemory * 1024
    $usedBytes = $totalBytes - $freeBytes
    
    $totalGB = [math]::Round($totalBytes / (1024 * 1024 * 1024), 2)
    $usedGB = [math]::Round($usedBytes / (1024 * 1024 * 1024), 2)
    
    return "$usedGB`GB/$totalGB`GB"
}

# Main loop
while ($true) {
    try {
        $cpu = Get-CpuUsage
        $ram = Get-MemoryUsage
        
        $stats = "󰍛 CPU: ${cpu}% | 󰘚 RAM: ${ram}"
        Set-Content -Path $OUTPUT -Value $stats -Force
    } catch {
        # Silently continue on error
    }
    
    Start-Sleep -Seconds 5
}
