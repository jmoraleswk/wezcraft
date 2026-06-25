#!/bin/zsh
# NOTE: This path must match constants.global.STATUS_BAR.stats_file in config.lua
OUTPUT="/tmp/wezterm_stats.txt"

while true; do
    # 1. Real-time CPU usage (0-100%) using top
    cpu=$(top -l 1 | grep -E "^CPU" | awk '{print int($3 + $5)"%"}')

    # 2. Get base memory statistics from macOS
    vm_stats=$(vm_stat)
    page_size=$(sysctl -n hw.pagesize)
    mem_total=$(sysctl -n hw.memsize)

    # Extract the exact pages used by Apple's Activity Monitor
    anon_pages=$(echo "$vm_stats" | grep "Anonymous pages" | awk '{print $3}' | tr -d '.')
    purge_pages=$(echo "$vm_stats" | grep "Pages purgeable" | awk '{print $3}' | tr -d '.')
    wired_pages=$(echo "$vm_stats" | grep "Pages wired down" | awk '{print $4}' | tr -d '.')
    comp_pages=$(echo "$vm_stats" | grep "Pages occupied by compressor" | awk '{print $5}' | tr -d '.')

    # Prevent empty or null values during system fluctuations
    anon_pages=${anon_pages:-0}
    purge_pages=${purge_pages:-0}
    wired_pages=${wired_pages:-0}
    comp_pages=${comp_pages:-0}

    # 3. Apple's official math executed in efficient AWK:
    # App Memory = Anonymous - Purgeable
    # Used Memory = App Memory + Wired + Compressed
    stats=$(awk -v anon="$anon_pages" -v purge="$purge_pages" -v wired="$wired_pages" -v comp="$comp_pages" -v page_sz="$page_size" -v total="$mem_total" '
        BEGIN {
            app_bytes = (anon - purge) * page_sz;
            wired_bytes = wired * page_sz;
            comp_bytes = comp * page_sz;
            
            used_bytes = app_bytes + wired_bytes + comp_bytes;
            
            # Use %.2f to show two decimals (e.g. 11.84GB) like Activity Monitor
            printf "%.2fGB/%.0fGB", used_bytes / (1024^3), total / (1024^3);
        }
    ')

    # 4. Save clean output
    echo "󰍛 CPU: $cpu | 󰘚 RAM: $stats" > "$OUTPUT"

    # Wait 5 seconds before next sample
    sleep 5
done