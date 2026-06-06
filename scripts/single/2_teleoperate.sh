#!/usr/bin/env bash
# Piper 单臂遥操作 —— 所有设置见 config.env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

ensure_can "$SCRIPT_DIR/1_setup.sh" "$CAN_LEADER" "$CAN_FOLLOWER"
CAMERAS_CONFIG=$(build_cameras_config)

echo "=========================================="
echo "  Piper 单臂遥操作"
echo "------------------------------------------"
echo "  leader   : $CAN_LEADER"
echo "  follower : $CAN_FOLLOWER"
show_cameras_info
echo "=========================================="
confirm_or_exit

lerobot-teleoperate \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_leader \
    --teleop.port="$CAN_LEADER" \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --display_data=true
