#!/bin/bash
# 双臂训练策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 命令行参数覆盖默认值
DATASET_NAME=${1:-"$REPO_DATASET_NAME"}
POLICY=${2:-"$DEFAULT_POLICY"}


echo "=========================================="
echo "  Piper 单臂策略训练脚本"
echo "=========================================="
echo "数据集: $LOCAL_DATASET_DIR/$MISSION_NAME"
echo "策略: $POLICY"
echo "=========================================="




lerobot-train \
    --policy.type=$POLICY \
    --policy.device=cuda \
    --policy.input_features='{"observation.images.top_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.images.gripper_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.state": {"shape": [7], "type": "STATE"}}' \
    --output_dir=$LOCAL_MODEL_NAME \
    --policy.repo_id=${REPO_MODEL_NAME} \
    --policy.push_to_hub=false\
    --dataset.root="$LOCAL_DATASET_NAME" \
    --dataset.repo_id=$REPO_DATASET_NAME \
    --dataset.video_backend=pyav\
    --robot.discover_packages_path=piper_lerobot \
    --env.type=piper \
    --batch_size=64 \
    --num_workers=8 \
    --steps=20000 \
    --eval_freq=-1 \
    --save_freq=2000 \
    --log_freq=100 \
    --wandb.enable=true \
    --wandb.project=piper_training \
    --wandb.run_id=$RUN_ID \
    # --resume=true \