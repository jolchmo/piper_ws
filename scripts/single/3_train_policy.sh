#!/usr/bin/env bash
# Piper 单臂训练（针对 wall_x 调优）—— 可调参数见 config.env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

# 命令行第一个参数可覆盖训练用的数据集根目录（默认用 config.env 推导的本地数据集）
TRAIN_DATASET_ROOT="${1:-$LOCAL_DATASET_NAME}"

# input_features 由 CAMERAS + STATE_DIM 自动生成，增减相机无需改本脚本
INPUT_FEATURES=$(build_input_features)

# 某些机器编译 wall_x 需要额外的 CPATH
[ -n "$EXTRA_CPATH" ] && export CPATH="$EXTRA_CPATH:$CPATH"

echo "=========================================="
echo "  Piper 单臂策略训练"
echo "------------------------------------------"
echo "  策略     : $POLICY (wall_x flow)"
echo "  数据集   : $TRAIN_DATASET_ROOT"
echo "  输出目录 : $SAVE_MODEL_NAME (push=$MODEL_PUSH_TO_HUB)"
echo "  训练步数 : $TRAIN_STEPS   batch=$BATCH_SIZE   gpus=$NUM_GPUS"
echo "  wandb    : enable=$WANDB_ENABLE project=$WANDB_PROJECT run=$WANDB_RUN_ID"
echo "=========================================="

# 输出目录已存在 -> 询问是否清理后重训
if [ -d "$SAVE_MODEL_NAME" ]; then
    echo "⚠️  输出目录已存在: $SAVE_MODEL_NAME"
    if [ "${AUTO_CONFIRM:-0}" = "1" ]; then
        echo "AUTO_CONFIRM=1 -> 删除旧目录重训"
        rm -rf "$SAVE_MODEL_NAME"
    else
        read -p "删除旧目录并重新训练? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$SAVE_MODEL_NAME"
            echo "✅ 已清理。"
        else
            echo "🛑 已取消。"
            exit 1
        fi
    fi
fi

confirm_or_exit

torchrun --nproc_per_node=$NUM_GPUS $(which lerobot-train) \
    --policy.type=wall_x \
    --policy.pretrained_name_or_path=x-square-robot/wall-oss-flow \
    --policy.prediction_mode=diffusion \
    --policy.attn_implementation=flash_attention_2 \
    --policy.device=cuda \
    --policy.dtype=bfloat16 \
    --policy.input_features="$INPUT_FEATURES" \
    --output_dir=$SAVE_MODEL_NAME \
    --policy.repo_id=$REPO_MODEL_NAME \
    --policy.push_to_hub=$MODEL_PUSH_TO_HUB \
    --dataset.root="$TRAIN_DATASET_ROOT" \
    --dataset.repo_id=$REPO_DATASET_NAME \
    --dataset.video_backend=pyav \
    --robot.discover_packages_path=piper_lerobot \
    --steps=$TRAIN_STEPS \
    --batch_size=$BATCH_SIZE \
    --num_workers=$NUM_WORKERS \
    --eval_freq=-1 \
    --save_freq=$SAVE_FREQ \
    --log_freq=$LOG_FREQ \
    --wandb.enable=$WANDB_ENABLE \
    --wandb.project=$WANDB_PROJECT \
    --wandb.run_id="$WANDB_RUN_ID"

# 没有 ffmpeg，所以 --dataset.video_backend=pyav
# wandb 需先 `wandb login`；wall_x 需要 flash_attention_2 + bfloat16
