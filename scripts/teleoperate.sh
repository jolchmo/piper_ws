#!/usr/bin/env bash
# 基础遥操作脚本

lerobot-teleoperate \
    --robot.type=piper_follower \
    --robot.port=can1 \
    --robot.id=follower \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_leader \
    --teleop.port=can0 \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --display_data=true
