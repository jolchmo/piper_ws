#!/usr/bin/env bash
# Piper 单臂策略部署/评估 —— 设置见 config.env
# 模型(ckpt)优先级：命令行第一个参数 > EVAL_MODEL > 按 MODEL_SOURCE 取本地/远程
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

# ckpt 可以是本地 checkpoint 目录，也可以是 HF 仓库（如 jolch/xxx）
CKPT=$(resolve_ckpt "${1:-$EVAL_MODEL}")
if [ -z "$CKPT" ]; then
    echo "❌ 未能确定要评估的模型。请用命令行传入 ckpt，或设置 EVAL_MODEL / MODEL_SOURCE。"
    exit 1
fi

ensure_can "$SCRIPT_DIR/1_setup.sh" "$CAN_FOLLOWER"
CAMERAS_CONFIG=$(build_cameras_config)

# 评估数据集名取自 ckpt（本地 last 目录则退回用 MODEL_ID），并自动编号避免覆盖
CKPT_TAG=$(basename "$CKPT")
[ "$CKPT_TAG" = "pretrained_model" ] && CKPT_TAG="$MODEL_ID"
CKPT_TAG="${CKPT_TAG//\//_}"
counter=0
while true; do
    suffix=$(printf "%03d" $counter)
    EVAL_DATASET_LOCAL="$LOCAL_DATASET_DIR/eval_${CKPT_TAG}_${suffix}"
    [ ! -d "$EVAL_DATASET_LOCAL" ] && break
    counter=$((counter + 1))
done
EVAL_DATASET_REMOTE="$REPO_USER/eval_${CKPT_TAG}_${suffix}"

echo "=========================================="
echo "  Piper 单臂策略部署/评估"
echo "------------------------------------------"
echo "  模型     : $CKPT"
echo "  任务描述 : $EVAL_DESC"
echo "  评估数据 : $EVAL_DATASET_LOCAL"
echo "  采集数量 : $NUM_EPISODES episodes"
show_cameras_info
echo "=========================================="
confirm_or_exit

lerobot-record \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --dataset.repo_id="$EVAL_DATASET_REMOTE" \
    --dataset.single_task="$EVAL_DESC" \
    --dataset.root="$EVAL_DATASET_LOCAL" \
    --dataset.push_to_hub=false \
    --dataset.num_episodes=$NUM_EPISODES \
    --policy.path="$CKPT" \
    --policy.device=cuda \
    --display_data=true
