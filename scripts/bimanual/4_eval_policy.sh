#!/usr/bin/env bash
# Piper 双臂策略评估 —— 设置见 config.env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

# 模型：命令行第一个参数，或默认 last checkpoint
CHECKPOINT="${1:-outputs/train/$POLICY/checkpoints/last.pt}"

ensure_can "$SCRIPT_DIR/1_setup.sh" "$CAN_LEFT_FOLLOWER" "$CAN_RIGHT_FOLLOWER"

echo "=========================================="
echo "  Piper 双臂策略评估"
echo "------------------------------------------"
echo "  模型 : $CHECKPOINT"
echo "=========================================="
confirm_or_exit

lerobot-eval \
    --robot.type=piper_bimanual \
    --robot.left_port="$CAN_LEFT_FOLLOWER" \
    --robot.right_port="$CAN_RIGHT_FOLLOWER" \
    --robot.id=follower \
    --robot.discover_packages_path=piper_lerobot \
    --policy.path=$CHECKPOINT \
    --display_data=true
