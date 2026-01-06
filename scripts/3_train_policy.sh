#!/bin/bash
# 训练策略脚本

DATASET_NAME=${1:-"jolch/piper_pickandplace"}
POLICY=${2:-"act"} 
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
    dataset.root="./datasets" \
    env.name=piper