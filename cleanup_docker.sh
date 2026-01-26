#!/bin/bash
while true; do
    sleep 1200  # 20 分钟
    echo "[$(date)] 开始清理 Docker..."
    docker container prune -f 2>/dev/null
    docker image prune -f --filter "until=1h" 2>/dev/null
    docker builder prune -f --keep-storage=30GB 2>/dev/null
    docker images --format "{{.ID}} {{.Repository}}" | grep "ghcr.io/openhands/runtime" | awk '{print $1}' | head -50 | xargs -r docker rmi -f 2>/dev/null
    echo "[$(date)] 清理完成"
    df -h / | tail -1
done
