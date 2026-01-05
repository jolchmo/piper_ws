#!/bin/bash
# 训练策略脚本

DATASET_NAME=${1:-"piper_dataset"}
POLICY=${2:-"act"}

python lerobot/scripts/train.py \
    policy=$POLICY \
    dataset.repo_id=$DATASET_NAME \
    env.name=piper
