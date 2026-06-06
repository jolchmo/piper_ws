#!/usr/bin/env bash
# Piper 双臂策略部署/评估 —— 设置见 config.env
# 必须指定模型：命令行第一个参数，或 config.env 里的 EVAL_MODEL
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

# 模型：本地 checkpoint 路径或 HF 仓库
EVAL_MODEL_NAME="${1:-$EVAL_MODEL}"
if [ -z "$EVAL_MODEL_NAME" ]; then
    echo "❌ 评估必须指定模型。"
    echo "   用法: bash 4_eval_policy.sh <模型路径或HF仓库>"
    echo "   或在 config.env 设置 EVAL_MODEL，或 EVAL_MODEL=... bash 4_eval_policy.sh"
    exit 1
fi

ensure_can "$SCRIPT_DIR/1_setup.sh" "$CAN_LEFT_FOLLOWER" "$CAN_RIGHT_FOLLOWER"
CAMERAS_CONFIG=$(build_cameras_config)

# 评估数据集自动编号，避免覆盖：eval_<模型名>_000, _001, ...
MODEL_BASE_NAME=$(basename "$EVAL_MODEL_NAME")
counter=0
while true; do
    suffix=$(printf "%03d" $counter)
    EVAL_DATASET_NAME="$LOCAL_DATASET_DIR/eval_${MODEL_BASE_NAME}_${suffix}"
    [ ! -d "$EVAL_DATASET_NAME" ] && break
    counter=$((counter + 1))
done
EVAL_REPO_DATASET_NAME="$REPO_USER/eval_${MODEL_BASE_NAME}_${suffix}"

echo "=========================================="
echo "  Piper 双臂策略部署/评估"
echo "------------------------------------------"
echo "  模型     : $EVAL_MODEL_NAME"
echo "  任务描述 : $EVAL_TASK"
echo "  评估数据 : $EVAL_DATASET_NAME"
echo "  采集数量 : $NUM_EPISODES episodes"
show_cameras_info
echo "=========================================="
confirm_or_exit

lerobot-record \
    --robot.type=piper_bimanual \
    --robot.left_port="$CAN_LEFT_FOLLOWER" \
    --robot.right_port="$CAN_RIGHT_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --dataset.repo_id="$EVAL_REPO_DATASET_NAME" \
    --dataset.single_task="$EVAL_TASK" \
    --dataset.root="$EVAL_DATASET_NAME" \
    --dataset.push_to_hub=false \
    --dataset.num_episodes=$NUM_EPISODES \
    --policy.path="$EVAL_MODEL_NAME" \
    --policy.device=cuda \
    --display_data=true
