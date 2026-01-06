#!/bin/bash
# 评估策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 命令行参数
CHECKPOINT=${1:-"outputs/train/$DEFAULT_POLICY/checkpoints/last.pt"}

lerobot-eval \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.discover_packages_path=piper_lerobot \
    --policy.path=$CHECKPOINT \
    --display_data=true
