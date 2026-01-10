#!/bin/bash
# 训练策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"


# 命令行参数覆盖默认值
POLICY=${1:-"$DEFAULT_POLICY"}


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


RUN_ID="piper_0110_smol"


lerobot-train \
    --policy.type=$POLICY \
    --policy.device=cuda \
    --policy.repo_id=jolch/piper_${POLICY} \
    --policy.input_features='{"observation.images.top_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.images.gripper_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.state": {"shape": [7], "type": "STATE"}}' \
    --output_dir=../../../DATA/disk0/junxi/model/piper_smaolvla_0110 \
    --dataset.repo_id=$REPO_DATASET_NAME \
    --robot.discover_packages_path=piper_lerobot \
    --dataset.video_backend=pyav\
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
    # --dataset.root="$LOCAL_DATASET_DIR/$MISSION_NAME" \

#因为没有ffmpeg，所以使用pyav
#wandb需要先登录

