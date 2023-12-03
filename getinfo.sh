#!/bin/bash

# 设置数据采集的时间间隔（秒）
INTERVAL=5

# InfluxDB的配置
INFLUXDB_DATABASE="system_performance"
INFLUXDB_HOST="localhost"
INFLUXDB_PORT="8086"

while true; do
    # 获取CPU和内存使用率
    CPU_USAGE=$(top -bn2 | grep "Cpu(s)" | tail -n1 | awk '{print $2 + $4}')
    MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    
    # 使用InfluxDB的HTTP API将数据写入数据库
    curl -i -XPOST "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/write?db=${INFLUXDB_DATABASE}" --data-binary "cpu_usage value=$CPU_USAGE
memory_usage value=$MEMORY_USAGE"
    
    # 等待下一个间隔
    sleep ${INTERVAL}
done

