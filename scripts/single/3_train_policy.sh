#!/bin/bash
# 训练策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"



# 输入是数据集，可以是本地的也可以是远程huggingface的，一定需要指定数据集
# 可以指定策略类型，默认是配置文件中的DEFAULT_POLICY
# 输出以"${ROBOT}_${DEFAULT_POLICY}_${TIMESTAMP}"命名保存模型
# 输出是模型，一定会保存到本地，也可以保存到远程huggingface
# 可以通过${MODEL_PUSH_TO_HUB}控制是否上传到远程huggingface，远端是REPO_MODEL_NAME


# 命令行参数覆盖默认值
TRAIN_DATASET_NAME=${1:-"None"}
POLICY=${2:-"$POLICY"}

if [ "$TRAIN_DATASET_NAME" != "None" ]; then
    echo "训练模型一定需要指定数据集，使用命令行第一个参数覆盖配置文件中的默认数据集"
    exit 1
fi

if [ -n "$TRAIN_DATASET_NAME" ] && [ -f "$TRAIN_DATASET_NAME" ]; then
    echo "使用本地数据集进行训练"
    LOCAL_DATASET_NAME=$TRAIN_DATASET_NAME
    use_remote_dataset=false
else
    echo "使用远程数据集: $REPO_DATASET_NAME"
    use_remote_dataset=true
fi

echo "=========================================="
echo "  Piper 单臂策略训练脚本"
echo "=========================================="
echo "任务: $MISSION_NAME"
if [ "$use_remote_dataset" = true ]; then
    echo "数据集: $REPO_DATASET_NAME (远程)"
else
    echo "数据集: $LOCAL_DATASET_NAME (本地)"
fi
echo "策略: $POLICY"
echo "模型输出: $LOCAL_MODEL_NAME"
echo “是否保存到huggingface: $MODEL_PUSH_TO_HUB”
echo "保存模型到"
echo "=========================================="


lerobot-train \
    --policy.type=$POLICY \
    --policy.device=cuda \
    --policy.input_features='{"observation.images.top_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.images.gripper_cam": {"shape": [3, 480, 640], "type": "VISUAL"}, "observation.state": {"shape": [7], "type": "STATE"}}' \
    --output_dir=$LOCAL_MODEL_NAME \
    --policy.repo_id=${REPO_MODEL_NAME} \
    --policy.push_to_hub=$MODEL_PUSH_TO_HUB\
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

#因为没有ffmpeg，所以使用pyav
#wandb需要先登录

