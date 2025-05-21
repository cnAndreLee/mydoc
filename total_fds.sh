#!/bin/bash

total_fds=0

# 遍历/proc目录下所有进程
for pid in /proc/[0-9]*; do
    # 确保该目录下存在fd子目录
    if [ -d "$pid/fd" ]; then
        # 计算每个进程的文件描述符数量
        fds=$(ls "$pid/fd" | wc -l)
        # 汇总总数
        total_fds=$((total_fds + fds))
    fi
done

echo "Total file descriptors used by all processes: $total_fds"
