#!/usr/bin/env bash
# Piper 单臂训练（针对 wall_x 调优）—— 可调参数见 config.env
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$WS_DIR/scripts/lib.sh"

# input_features 由 CAMERAS + STATE_DIM 自动生成，增减相机无需改本脚本
INPUT_FEATURES=$(build_input_features)
# 按 DATASET_SOURCE 填充数据集参数（local 从本地盘 / remote 从 HF 拉）
set_dataset_train_args

# 某些机器编译 wall_x 需要额外的 CPATH
[ -n "$EXTRA_CPATH" ] && export CPATH="$EXTRA_CPATH:$CPATH"

if [ "$DATASET_SOURCE" = "remote" ]; then DATASET_SHOWN="$DATASET_REMOTE (HF)"; else DATASET_SHOWN="$DATASET_LOCAL (本地)"; fi

echo "=========================================="
echo "  Piper 单臂策略训练"
echo "------------------------------------------"
echo "  策略     : $POLICY (wall_x flow)"
echo "  数据集   : $DATASET_SHOWN"
echo "  输出目录 : $MODEL_LOCAL"
echo "  上传模型 : push=$MODEL_PUSH_TO_HUB -> $MODEL_REMOTE"
echo "  训练步数 : $TRAIN_STEPS   batch=$BATCH_SIZE   gpus=$NUM_GPUS"
echo "  wandb    : enable=$WANDB_ENABLE project=$WANDB_PROJECT run=$WANDB_RUN_ID"
echo "=========================================="

# 输出目录已存在 -> 询问是否清理后重训
if [ -d "$MODEL_LOCAL" ]; then
    echo "⚠️  输出目录已存在: $MODEL_LOCAL"
    if [ "${AUTO_CONFIRM:-0}" = "1" ]; then
        echo "AUTO_CONFIRM=1 -> 删除旧目录重训"
        rm -rf "$MODEL_LOCAL"
    else
        read -p "删除旧目录并重新训练? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$MODEL_LOCAL"
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
    --output_dir=$MODEL_LOCAL \
    --policy.repo_id=$MODEL_REMOTE \
    --policy.push_to_hub=$MODEL_PUSH_TO_HUB \
    "${DATASET_ARGS[@]}" \
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
