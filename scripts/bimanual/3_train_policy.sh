#!/usr/bin/env bash
# Piper 双臂训练 —— 可调参数见 config.env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

# 命令行参数覆盖：$1=数据集根目录  $2=策略类型
TRAIN_DATASET_ROOT="${1:-$LOCAL_DATASET_NAME}"
POLICY="${2:-$POLICY}"

# input_features 由 CAMERAS + STATE_DIM(=14) 自动生成，增减相机无需改本脚本
INPUT_FEATURES=$(build_input_features)

echo "=========================================="
echo "  Piper 双臂策略训练"
echo "------------------------------------------"
echo "  策略     : $POLICY"
echo "  数据集   : $TRAIN_DATASET_ROOT"
echo "  输出目录 : $LOCAL_MODEL_NAME (push=$MODEL_PUSH_TO_HUB)"
echo "  训练步数 : $TRAIN_STEPS   batch=$BATCH_SIZE"
echo "  状态维度 : $STATE_DIM"
echo "=========================================="
confirm_or_exit

lerobot-train \
    --policy.type=$POLICY \
    --policy.device=cuda \
    --policy.input_features="$INPUT_FEATURES" \
    --output_dir=$LOCAL_MODEL_NAME \
    --policy.repo_id=$REPO_MODEL_NAME \
    --policy.push_to_hub=$MODEL_PUSH_TO_HUB \
    --dataset.root="$TRAIN_DATASET_ROOT" \
    --dataset.repo_id=$REPO_DATASET_NAME \
    --dataset.video_backend=pyav \
    --robot.discover_packages_path=piper_lerobot \
    --env.type=piper \
    --batch_size=$BATCH_SIZE \
    --num_workers=$NUM_WORKERS \
    --steps=$TRAIN_STEPS \
    --eval_freq=-1 \
    --save_freq=$SAVE_FREQ \
    --log_freq=$LOG_FREQ \
    --wandb.enable=$WANDB_ENABLE \
    --wandb.project=$WANDB_PROJECT \
    --wandb.run_id=$RUN_ID
