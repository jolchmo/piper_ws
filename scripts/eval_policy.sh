#!/bin/bash
# 评估策略脚本

CHECKPOINT=${1:-"outputs/train/act/checkpoints/last.pt"}

lerobot-eval \
    --robot.type=piper_follower \
    --robot.port=can0 \
    --robot.id=follower \
    --robot.discover_packages_path=piper_lerobot \
    --policy.path=$CHECKPOINT \
    --teleop.discover_packages_path=piper_lerobot \
    --display_data=true
