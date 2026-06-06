#!/usr/bin/env bash
# Piper 双臂训练 —— 可调参数见 config.env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

# input_features 由 CAMERAS + STATE_DIM(=14) 自动生成，增减相机无需改本脚本
INPUT_FEATURES=$(build_input_features)
# 按 DATASET_SOURCE 填充数据集参数（local 从本地盘 / remote 从 HF 拉）
set_dataset_train_args

if [ "$DATASET_SOURCE" = "remote" ]; then DATASET_SHOWN="$DATASET_REMOTE (HF)"; else DATASET_SHOWN="$DATASET_LOCAL (本地)"; fi

echo "=========================================="
echo "  Piper 双臂策略训练"
echo "------------------------------------------"
echo "  策略     : $POLICY"
echo "  数据集   : $DATASET_SHOWN"
echo "  输出目录 : $MODEL_LOCAL"
echo "  上传模型 : push=$MODEL_PUSH_TO_HUB -> $MODEL_REMOTE"
echo "  训练步数 : $TRAIN_STEPS   batch=$BATCH_SIZE   state=$STATE_DIM"
echo "=========================================="
confirm_or_exit

lerobot-train \
    --policy.type=$POLICY \
    --policy.device=cuda \
    --policy.input_features="$INPUT_FEATURES" \
    --output_dir=$MODEL_LOCAL \
    --policy.repo_id=$MODEL_REMOTE \
    --policy.push_to_hub=$MODEL_PUSH_TO_HUB \
    "${DATASET_ARGS[@]}" \
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
    --wandb.run_id="$WANDB_RUN_ID"
