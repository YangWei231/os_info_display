#!/bin/bash

# 设置数据采集的时间间隔（秒）
INTERVAL=5

# InfluxDB的配置
INFLUXDB_DATABASE="system_performance"
INFLUXDB_HOST="localhost"
INFLUXDB_PORT="8086"

# 用于计算CPU使用率的函数
calculate_cpu_usage() {
    # 从 /proc/stat 读取 CPU 时间统计
    local cpu_stat_1=($(head -n 1 /proc/stat))
    local idle_1="${cpu_stat_1[4]}"
    
    sleep ${INTERVAL}

    local cpu_stat_2=($(head -n 1 /proc/stat))
    local idle_2="${cpu_stat_2[4]}"

    local total_1=0
    local total_2=0
    
    # 计算总 CPU 时间
    for value in "${cpu_stat_1[@]:1}"; do
        let "total_1=$total_1+$value"
    done

    for value in "${cpu_stat_2[@]:1}"; do
        let "total_2=$total_2+$value"
    done

    # 计算 CPU 使用率
    local total_diff=$((total_2 - total_1))
    local idle_diff=$((idle_2 - idle_1))
    local usage=$((100 * (total_diff - idle_diff) / total_diff))
    echo "${usage}"
}

# xingneng shuju
#!/bin/bash

# CPU 数量和核数
cpu_count=$(grep -c ^processor /proc/cpuinfo)
cores_per_cpu=$(grep ^cpu\ cores /proc/cpuinfo | uniq | awk '{print $4}')
total_cores=$((cpu_count * cores_per_cpu))

# CPU 占用率 (1分钟平均)
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')

# 进程数量
process_count=$(ps -A --no-headers | wc -l)

# 内存信息
mem_info=$(free -h | grep Mem)
total_mem=$(echo $mem_info | awk '{print $2}')
used_mem=$(echo $mem_info | awk '{print $3}')
mem_usage=$(free | grep Mem | awk '{printf("%.2f%"), $3/$2 * 100.0}')

# 磁盘信息
disk_info=$(df -h /)
disk_total=$(echo $disk_info | awk 'NR==2 {print $2}')
disk_used=$(echo $disk_info | awk 'NR==2 {print $3}')
disk_usage=$(echo $disk_info | awk 'NR==2 {print $5}')

# 磁盘IO
disk_io=$(iostat -dx)

# 网络连接信息
net_connections=$(netstat -an)

# 网络接口流量 (取决于接口名称，这里假设是 eth0)
net_traffic=$(ifconfig eth0 | grep "RX packets" -A 1)

# IPC、Cache Misses (需要安装 perf 工具)
ipc=$(perf stat -e instructions,cycles -- sleep 1 2>&1 | grep "insn per cycle" | awk '{print $4}')
cache_misses=$(perf stat -e cache-misses -- sleep 1 2>&1 | grep "cache-misses" | awk '{print $1}')

# 输出结果
echo "CPU Count: $cpu_count"
echo "Total Cores: $total_cores"
echo "CPU Usage: $cpu_usage"
echo "Process Count: $process_count"
echo "Total Memory: $total_mem"
echo "Used Memory: $used_mem"
echo "Memory Usage: $mem_usage"
echo "Disk Total: $disk_total"
echo "Disk Used: $disk_used"
echo "Disk Usage: $disk_usage"
echo "Disk IO:"
echo "$disk_io"
echo "Network Connections:"
echo "$net_connections"
echo "Network Traffic:"
echo "$net_traffic"
echo "IPC: $ipc"
echo "Cache Misses: $cache_misses"


# # 主循环
# while true; do
#     # 获取CPU使用率
#     CPU_USAGE=$(calculate_cpu_usage)
    
#     # 获取内存使用率
#     MEMORY_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
#     MEMORY_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
#     MEMORY_BUFFERS=$(grep Buffers /proc/meminfo | awk '{print $2}')
#     MEMORY_CACHED=$(grep '^Cached' /proc/meminfo | awk '{print $2}')
#     MEMORY_USAGE=$(awk "BEGIN {print 100.0 * ($MEMORY_TOTAL - $MEMORY_FREE - $MEMORY_BUFFERS - $MEMORY_CACHED) / $MEMORY_TOTAL}")
    
#     # 使用InfluxDB的HTTP API将数据写入数据库
#     curl -i -XPOST "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/write?db=${INFLUXDB_DATABASE}" --data-binary "cpu_usage value=$CPU_USAGE
# memory_usage value=$MEMORY_USAGE"
# done


# xingnengshuju
