#!/usr/bin/env bash
# Piper 双臂遥操作 —— 设置见 config.env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

ensure_can "$SCRIPT_DIR/1_setup.sh" \
    "$CAN_LEFT_LEADER" "$CAN_RIGHT_LEADER" "$CAN_LEFT_FOLLOWER" "$CAN_RIGHT_FOLLOWER"
CAMERAS_CONFIG=$(build_cameras_config)

echo "=========================================="
echo "  Piper 双臂遥操作"
echo "------------------------------------------"
echo "  leader   : $CAN_LEFT_LEADER / $CAN_RIGHT_LEADER"
echo "  follower : $CAN_LEFT_FOLLOWER / $CAN_RIGHT_FOLLOWER"
show_cameras_info
echo "=========================================="
confirm_or_exit

lerobot-teleoperate \
    --robot.type=piper_bimanual \
    --robot.left_port="$CAN_LEFT_FOLLOWER" \
    --robot.right_port="$CAN_RIGHT_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_bimanual_leader \
    --teleop.left_port="$CAN_LEFT_LEADER" \
    --teleop.right_port="$CAN_RIGHT_LEADER" \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --display_data=true
