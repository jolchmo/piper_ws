#!/usr/bin/env bash
# Piper 单臂数据采集 —— 所有设置见 config.env（数据集始终写到本地 DATASET_LOCAL）
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

ensure_can "$SCRIPT_DIR/1_setup.sh" "$CAN_LEADER" "$CAN_FOLLOWER"
CAMERAS_CONFIG=$(build_cameras_config)

echo "=========================================="
echo "  Piper 单臂数据采集"
echo "------------------------------------------"
echo "  任务描述 : $TASK_DESC"
echo "  数据集   : $DATASET_LOCAL"
echo "  远程仓库 : $DATASET_REMOTE (push=$DATASET_PUSH_TO_HUB)"
echo "  采集数量 : $NUM_EPISODES episodes (resume=$RESUME)"
show_cameras_info
echo "------------------------------------------"
echo "  快捷键: → 结束当前 episode    ESC 停止录制"
echo "=========================================="
confirm_or_exit

lerobot-record \
    --resume="$RESUME" \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_leader \
    --teleop.port="$CAN_LEADER" \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --dataset.single_task="$TASK_DESC" \
    --dataset.root="$DATASET_LOCAL" \
    --dataset.repo_id="$DATASET_REMOTE" \
    --dataset.push_to_hub=$DATASET_PUSH_TO_HUB \
    --dataset.num_episodes=$NUM_EPISODES \
    --display_data=true
