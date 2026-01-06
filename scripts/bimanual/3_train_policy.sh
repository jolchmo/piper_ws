#!/bin/bash
# 双臂训练策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 命令行参数覆盖默认值
DATASET_NAME=${1:-"$DEFAULT_DATASET_NAME"}
POLICY=${2:-"$DEFAULT_POLICY"}
# act
# diffusion
# groot
# pi0
# pi05
# rtc
# sac
# sarm
# smolvla
# tdmpc
# vqbet
# wall_x
# xvla

python lerobot/scripts/train.py \
    policy=$POLICY \
    dataset.repo_id=$DATASET_NAME \
    dataset.root="$LOCAL_DATASET_DIR/$MISSION_NAME" \
    env.name=piper_bimanual
