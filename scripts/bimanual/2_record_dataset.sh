#!/usr/bin/env bash
# Piper 双臂数据采集 —— 设置见 config.env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

ensure_can "$SCRIPT_DIR/1_setup.sh" \
    "$CAN_LEFT_LEADER" "$CAN_RIGHT_LEADER" "$CAN_LEFT_FOLLOWER" "$CAN_RIGHT_FOLLOWER"

# 双臂当前用单个 OpenCV 相机
if [ -n "$CAMERA_PATH" ]; then
    CAMERAS_CONFIG="{ gripper_cam: {type: opencv, index_or_path: \"$CAMERA_PATH\", fps: $CAMERA_FPS, width: $CAMERA_WIDTH, height: $CAMERA_HEIGHT} }"
    echo "  📷 相机已启用: $CAMERA_PATH"
else
    CAMERAS_CONFIG="{}"
    echo "  📷 相机已禁用"
fi

echo "=========================================="
echo "  Piper 双臂数据采集"
echo "------------------------------------------"
echo "  任务     : $MISSION_NAME"
echo "  数据集   : $LOCAL_DATASET_NAME"
echo "  采集数量 : $NUM_EPISODES episodes (resume=$RESUME)"
echo "=========================================="
confirm_or_exit

lerobot-record \
    --resume="$RESUME" \
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
    --dataset.single_task="$MISSION_NAME" \
    --dataset.root="$LOCAL_DATASET_NAME" \
    --dataset.repo_id="$REPO_DATASET_NAME" \
    --dataset.push_to_hub=$DATASET_PUSH_TO_HUB \
    --dataset.num_episodes=$NUM_EPISODES \
    --auto_reset_to_origin=true \
    --display_data=true
