#!/bin/bash

# 设置数据采集的时间间隔（秒）
INTERVAL=3

# InfluxDB的配置
INFLUXDB_DATABASE="system_performance4"
INFLUXDB_HOST="l192.168.153.128"
INFLUXDB_PORT="8086"

# 自动检测主网络接口
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

# 获取所有物理磁盘名称（排除loop、RAM和光盘驱动器设备）
DISK_DEVICES=$(lsblk -nd --output NAME | grep -v '^loop\|^ram\|^sr')

while true; do
    # 获取网络接口的初始接收（RX）和发送（TX）字节数
    RX_BYTES_BEFORE=$(cat /sys/class/net/$MAIN_INTERFACE/statistics/rx_bytes)
    TX_BYTES_BEFORE=$(cat /sys/class/net/$MAIN_INTERFACE/statistics/tx_bytes)
    # 等待指定的时间间隔
    sleep 5
    # 获取间隔后的接收（RX）和发送（TX）字节数
    RX_BYTES_AFTER=$(cat /sys/class/net/$MAIN_INTERFACE/statistics/rx_bytes)
    TX_BYTES_AFTER=$(cat /sys/class/net/$MAIN_INTERFACE/statistics/tx_bytes)
    # # 计算每秒的接收和发送速率
    # RX_RATE=$(( ($RX_BYTES_AFTER - $RX_BYTES_BEFORE) / 2 ))
    # TX_RATE=$(( ($TX_BYTES_AFTER - $TX_BYTES_BEFORE) / 2 ))
    # 使用bc进行浮点数运算，计算每秒的接收和发送速率
    RX_RATE=$(echo "scale=2; ($RX_BYTES_AFTER - $RX_BYTES_BEFORE) / 5" | bc)
    TX_RATE=$(echo "scale=2; ($TX_BYTES_AFTER - $TX_BYTES_BEFORE) / 5" | bc)

    # CPU和内存使用率,swap
    CPU_USAGE=$(top -bn2 | grep "Cpu(s)" | tail -n1 | awk '{print $2 + $4}')
    MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    SWAP_USAGE=$(free | grep Swap | awk '{print $3/$2 * 100.0}')
    # 获取CPU数量和核数
    CPU_COUNT=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    CPU_CORES=$(lscpu | grep "^Core(s) per socket:" | awk '{print $4}')

    # 获取进程数量
    PROCESS_COUNT=$(ps -aux | wc -l)

    # 获取内存大小
    TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
    TOTAL_SWAP=$(free -m | grep Swap | awk '{print $2}')
    # 统计TCP连接数量
    TCP_CONNECTIONS=$(netstat -tun | grep -c '^tcp')
    # 统计TCPv6连接数量
    TCP6_CONNECTIONS=$(netstat -tun | grep -c '^tcp6')
    # 统计UDP连接数量
    UDP_CONNECTIONS=$(netstat -tun | grep -c '^udp')
    # 统计ESTABLISHED状态的连接数量
    ESTABLISHED_CONNECTIONS=$(netstat -tun | grep -c 'ESTABLISHED')
    # 统计TIME_WAIT状态的连接数量
    TIME_WAIT_CONNECTIONS=$(netstat -tun | grep -c 'TIME_WAIT')

    # 初始化InfluxDB数据字符串
    INFLUX_DATA="cpu_usage value=$CPU_USAGE
memory_usage value=$MEMORY_USAGE
swap_usage value=$SWAP_USAGE
cpu_count value=$CPU_COUNT
cpu_cores value=$CPU_CORES
process_count value=$PROCESS_COUNT
total_mem value=$TOTAL_MEM
total_swap value=$TOTAL_SWAP
tcp_connections value=$TCP_CONNECTIONS
tcp6_connections value=$TCP6_CONNECTIONS
udp_connections value=$UDP_CONNECTIONS
established_connections value=$ESTABLISHED_CONNECTIONS
time_wait_connections value=$TIME_WAIT_CONNECTIONS
net_rx_rate value=$RX_RATE
net_tx_rate value=$TX_RATE
net_rx_packets value=$(ifconfig $MAIN_INTERFACE | grep 'RX packets' | awk '{print $3}')
net_tx_packets value=$(ifconfig $MAIN_INTERFACE | grep 'TX packets' | awk '{print $3}')
"

    # 添加磁盘使用率数据
    for DISK in $DISK_DEVICES; do
    # 获取磁盘使用率
        DISK_USAGE_PERCENT=$(df -h | grep "/dev/$DISK" | awk '$6 == "/" {print $5}' | sed 's/%//')
        INFLUX_DATA+="disk_usage_$DISK value=$DISK_USAGE_PERCENT 
"
    done
    
    # 添加磁盘I/O统计信息
    for DISK in $DISK_DEVICES; do
        READ_SPEED=$(iostat -dx $DISK | awk '/^'"$DISK"'/ {print $3}')
        WRITE_SPEED=$(iostat -dx $DISK | awk '/^'"$DISK"'/ {print $9}')
        INFLUX_DATA+="disk_io_read_$DISK value=$READ_SPEED
"
        INFLUX_DATA+="disk_io_write_$DISK value=$WRITE_SPEED
"
    done
    # 发送数据到InfluxDB
    curl -i -XPOST "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/write?db=${INFLUXDB_DATABASE}" --data-binary "$INFLUX_DATA"
    
    # 等待下一个间隔
    sleep ${INTERVAL}
done
