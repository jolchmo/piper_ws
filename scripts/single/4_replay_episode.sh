#!/bin/bash
# 回放数据集脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 命令行参数
DATASET_NAME=${1:-"$REPO_DATASET_NAME"}
EPISODE=${2:-0}

lerobot-replay \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.discover_packages_path=piper_lerobot \
    --dataset.repo_id=$DATASET_NAME \
    --dataset.root="$LOCAL_DATASET_DIR/$MISSION_NAME" \
    --dataset.episode=$EPISODE
