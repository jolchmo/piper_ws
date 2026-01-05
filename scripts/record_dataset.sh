#!/bin/bash
# 录制数据集脚本

DATASET_NAME=${1:-"piper_dataset"}
NUM_EPISODES=${2:-50}

lerobot-record \
    --robot.type=piper_follower \
    --robot.port=can0 \
    --robot.id=follower \
    --robot.cameras="{ front: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30}}" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_leader \
    --teleop.port=can1 \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --dataset.repo_id=$DATASET_NAME \
    --dataset.num_episodes=$NUM_EPISODES \
    --display_data=true
