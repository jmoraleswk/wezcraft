#!/bin/bash
# NOTE: This path must match constants.global.STATUS_BAR.stats_file in config.lua
OUTPUT="/tmp/wezterm_stats.txt"

while true; do
    # 1. Real-time CPU usage (0-100%) using /proc/stat
    # Read initial CPU values
    cpu_line=$(head -1 /proc/stat)
    user=$(echo $cpu_line | awk '{print $2}')
    nice=$(echo $cpu_line | awk '{print $3}')
    system=$(echo $cpu_line | awk '{print $4}')
    idle=$(echo $cpu_line | awk '{print $5}')
    iowait=$(echo $cpu_line | awk '{print $6}')
    irq=$(echo $cpu_line | awk '{print $7}')
    softirq=$(echo $cpu_line | awk '{print $8}')
    steal=$(echo $cpu_line | awk '{print $9}')
    
    prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    prev_idle=$idle
    
    # Wait 1 second for accurate measurement
    sleep 1
    
    # Read new CPU values
    cpu_line=$(head -1 /proc/stat)
    user=$(echo $cpu_line | awk '{print $2}')
    nice=$(echo $cpu_line | awk '{print $3}')
    system=$(echo $cpu_line | awk '{print $4}')
    idle=$(echo $cpu_line | awk '{print $5}')
    iowait=$(echo $cpu_line | awk '{print $6}')
    irq=$(echo $cpu_line | awk '{print $7}')
    softirq=$(echo $cpu_line | awk '{print $8}')
    steal=$(echo $cpu_line | awk '{print $9}')
    
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    
    # Calculate CPU usage percentage
    diff_idle=$((idle - prev_idle))
    diff_total=$((total - prev_total))
    
    if [ $diff_total -gt 0 ]; then
        cpu=$((100 * (diff_total - diff_idle) / diff_total))
    else
        cpu=0
    fi
    
    # 2. Memory usage using free
    mem_info=$(free -m | grep Mem)
    mem_total=$(echo $mem_info | awk '{print $2}')
    mem_used=$(echo $mem_info | awk '{print $3}')
    
    # Convert to GB with 2 decimal places
    mem_total_gb=$(awk "BEGIN {printf \"%.2f\", $mem_total/1024}")
    mem_used_gb=$(awk "BEGIN {printf \"%.2f\", $mem_used/1024}")
    
    # 3. Save clean output
    echo "󰍛 CPU: ${cpu}% | 󰘚 RAM: ${mem_used_gb}GB/${mem_total_gb}GB" > "$OUTPUT"
    
    # Wait 5 seconds before next sample (minus the 1 second we already waited)
    sleep 4
done
