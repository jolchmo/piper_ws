#!/bin/bash
# 回放数据集脚本

DATASET_NAME=${1:-"piper_dataset"}
EPISODE=${2:-0}

lerobot-replay \
    --robot.type=piper_follower \
    --robot.port=can0 \
    --robot.id=follower \
    --robot.discover_packages_path=piper_lerobot \
    --dataset.repo_id=$DATASET_NAME \
    --dataset.episode=$EPISODE
