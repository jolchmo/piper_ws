#!/bin/bash
# 训练策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"


# 命令行参数覆盖默认值
MISSION_NAME=${1:-"$MISSION_NAME"}
POLICY=${2:-"$DEFAULT_POLICY"}


echo "=========================================="
echo "  Piper 单臂策略训练脚本"
echo "=========================================="
echo "数据集: $LOCAL_DATASET_DIR/$MISSION_NAME"
echo "策略: $POLICY"
echo "=========================================="


if [ "$POLICY" = "smolvla" ]; then
    pretrained_path="lerobot/smolvla_base"
elif [ "$POLICY" = "clip-vitb32" ]; then
    pretrained_path="openai/clip-vit-base-patch32"
else
    pretrained_path=""
fi

#policy.repo_id  -> hub
#output_dir -> local

# dataset.repo_id -> hub
# dataset.root -> local


lerobot-train \
    --policy.path=$pretrained_path \
    --policy.device=cuda \
    --policy.repo_id=jolch/piper_${POLICY} \
    --policy.input_features='{"observation.images.top_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.images.gripper_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.state": {"shape": [7], "type": "STATE"}}' \
    --output_dir=outputs/model/smolvla_piper \
    --dataset.repo_id=$REPO_DATASET_NAME \
    --dataset.root="$LOCAL_DATASET_DIR/$MISSION_NAME" \
    --robot.discover_packages_path=piper_lerobot \
    --dataset.video_backend=pyav\
    --env.type=piper \
    --batch_size=64 \
    --num_workers=8 \
    --steps=20000  \
    --eval_freq=500 \
    --save_freq=500 \
    --log_freq=100

#因为没有ffmpeg