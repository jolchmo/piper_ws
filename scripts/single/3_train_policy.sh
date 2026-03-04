#!/bin/bash
# 训练策略脚本

TRAIN_DATASET_NAME=${1:-"None"}
if [ -n "$TRAIN_DATASET_NAME" ] && [ -f "$TRAIN_DATASET_NAME" ]; then
    echo "使用本地数据集进行训练"
    LOCAL_DATASET_NAME=$TRAIN_DATASET_NAME
    use_remote_dataset=false
else
    echo "未指定本地数据集，使用远程仓库数据集进行训练"
    LOCAL_DATASET_NAME="$LOCAL_DATASET_DIR/${MISSION_NAME}_dataset"
    use_remote_dataset=true
fi
# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# eg. pig_rgy_dataset
DATASET_NAME="pig_rgy"
TRAIN_DATASET_NAME="$LOCAL_DATASET_DIR/${DATASET_NAME}_dataset"
REPO_DATASET_NAME="$REPO_USER/${DATASET_NAME}_dataset"

# eg. piper_wall_x_pig_rgy
MISSION_NAME="pig_rgy"
MODEL_NAME="${ROBOT}_${POLICY}_${MISSION_NAME}"
SAVE_MODEL_NAME="$LOCAL_MODEL_DIR/$MODEL_NAME"
REPO_MODEL_NAME="$REPO_USER/$MODEL_NAME"
MODEL_PUSH_TO_HUB=false

# --- 检测文件夹是否存在 ---
if [ -d "$SAVE_MODEL_NAME" ]; then
    echo "⚠️  警告: 文件夹 $SAVE_MODEL_NAME 已存在。"
    
    # 询问用户是否删除 (-n 1 表示只需要输入一个字符，不需要回车)
    read -p "确认要删除旧文件夹并重新开始训练吗？[y/N]: " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "正在清理旧数据: $SAVE_MODEL_NAME"
        rm -rf "$SAVE_MODEL_NAME"
        echo "✅ 已清理。"
    else
        echo "🛑 已取消。为了安全，脚本将停止运行。"
        exit 1
    fi
fi



echo "=========================================="
echo "  Piper 单臂策略训练脚本"
echo "=========================================="
echo "任务: $MISSION_NAME"
echo "数据集: $TRAIN_DATASET_NAME (本地)"
echo "策略: $POLICY"
echo "模型输出: $SAVE_MODEL_NAME"
echo “是否保存到huggingface: $MODEL_PUSH_TO_HUB”
echo "=========================================="


export CPATH=/home/junxi/piper_ws/.venv/Include:/home/junxi/piper_ws/.venv/PC:$CPATH

torchrun --nproc_per_node=4 $(which lerobot-train) \
    --policy.type=wall_x \
    --policy.pretrained_name_or_path=x-square-robot/wall-oss-flow \
    --policy.prediction_mode=diffusion \
    --policy.attn_implementation=flash_attention_2 \
    --policy.device=cuda \
    --policy.dtype=bfloat16 \
    --policy.input_features='{"observation.images.top_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.images.gripper_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.state": {"shape": [7], "type": "STATE"}}' \
    --output_dir=$SAVE_MODEL_NAME \
    --policy.repo_id=${REPO_MODEL_NAME} \
    --policy.push_to_hub=$MODEL_PUSH_TO_HUB\
    --dataset.root="$TRAIN_DATASET_NAME" \
    --dataset.repo_id=$REPO_DATASET_NAME \
    --dataset.video_backend=pyav\
    --robot.discover_packages_path=piper_lerobot \
    --steps=10000  \
    --batch_size=16 \
    --num_workers=16 \
    --eval_freq=-1 \
    --save_freq=2000 \
    --log_freq=100 \
    --wandb.enable=true \
    --wandb.project=piper_training \
    --wandb.run_id="wallx_pig_rgy"

#因为没有ffmpeg，所以使用pyav
#wandb需要先登录



# ----------------------------------
#  training with smolvla, but it seems that smolvla is not good for this task, so we switch to wall_x
# ----------------------------------

# lerobot-train \
#     --policy.type=smolvla \
#     --policy.pretrained_path="lerobot/smolvla_base" \
#     --policy.device=cuda \
#     --policy.input_features='{"observation.images.top_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.images.gripper_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.state": {"shape": [7], "type": "STATE"}}' \
#     --output_dir=$LOCAL_MODEL_NAME \
#     --policy.repo_id=${REPO_MODEL_NAME} \
#     --policy.push_to_hub=$MODEL_PUSH_TO_HUB\
#     --dataset.root="$LOCAL_DATASET_NAME" \
#     --dataset.repo_id=$REPO_DATASET_NAME \
#     --dataset.video_backend=pyav\
#     --robot.discover_packages_path=piper_lerobot \
#     --env.type=piper \
#     --batch_size=64 \
#     --num_workers=8 \
#     --steps=20000 \
#     --eval_freq=-1 \
#     --save_freq=2000 \
#     --log_freq=100 \
#     --wandb.enable=true \
#     --wandb.project=piper_training \
#     --wandb.run_id=$RUN_ID \
#     # --resume=true \


