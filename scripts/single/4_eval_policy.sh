#!/bin/bash
# 评估策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"


# 输入是模型，可以是本地的也可以是远程huggingface的，一定需要指定所使用的模型
# 输出以"eval_${MODEL_NAME}"命名保存数据集
# EVAL_DATASET_NAME 是评估所产生的数据集，一定会保存到本地，没有保存到远程huggingface的必要

# 可以是jolch/piper_smolvla 也可以是本地路径 ./outputs/smolvla_202406_1234
EVAL_MODEL_NAME=${1:-"None"}


if [ "$EVAL_MODEL_NAME" == "None" ]; then
    echo "评估模型一定需要指定模型，使用命令行第一个参数覆盖配置文件中的默认模型"
    exit 1
fi

MODEL_BASE_NAME=$(basename "$EVAL_MODEL_NAME")

# 2. 初始化计数器
counter=0
# 3. 循环检查目录是否存在
# printf "%03d" 会将 1 变成 001, 10 变成 010
while true; do
    suffix=$(printf "%03d" $counter)
    CURRENT_DIR="$LOCAL_DATASET_DIR/eval_${MODEL_BASE_NAME}_${suffix}"
    echo "Checking directory: $CURRENT_DIR"
    # Check if directory exists (-d)
    if [ ! -d "$CURRENT_DIR" ]; then
        # 如果目录不存在，说明这个序号可用，跳出循环
        break
    fi
    
    # 如果存在，计数器加1，继续寻找
    counter=$((counter + 1))
done



EVAL_DATASET_NAME="$LOCAL_DATASET_DIR/eval_${MODEL_BASE_NAME}_${suffix}"
EVAL_REPO_DATASET_NAME="$REPO_USER/eval_${MODEL_BASE_NAME}_${suffix}"



# 构建多相机配置
# 从 CAMERAS 关联数组构建 JSON 格式的相机配置
build_cameras_config() {
    local config="{"
    local first=true
    
    for cam_name in "${!CAMERAS[@]}"; do
        cam_path="${CAMERAS[$cam_name]}"
        if [ -n "$cam_path" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                config+=", "
            fi
            config+="$cam_name: {type: opencv, index_or_path: \"$cam_path\", fps: $CAMERA_FPS, width: $CAMERA_WIDTH, height: $CAMERA_HEIGHT}"
        fi
    done
    
    config+="}"
    echo "$config"
}

# 显示相机信息
show_cameras_info() {
    for cam_name in "${!CAMERAS[@]}"; do
        cam_path="${CAMERAS[$cam_name]}"
        if [ -n "$cam_path" ]; then
            echo "📷 相机 $cam_name: $cam_path"
        fi
    done
}
# 检查是否有相机配置
if [ ${#CAMERAS[@]} -gt 0 ]; then
    CAMERAS_CONFIG=$(build_cameras_config)
    show_cameras_info
else
    CAMERAS_CONFIG="{}"
    echo "📷 相机已禁用"
fi


CHECKPOINT=$EVAL_MODEL_NAME


echo "=========================================="
echo "  Piper 单臂策略部署脚本"
echo "=========================================="
echo "RUN_ID" : $RUN_ID
echo "模型: $CHECKPOINT"
echo "任务: $MISSION_NAME"
echo "估数据集保存在: $EVAL_DATASET_NAME"
echo "=========================================="




python "$SCRIPT_DIR/../piper_record.py" \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --dataset.repo_id="$EVAL_REPO_DATASET_NAME" \
    --dataset.single_task="$MISSION_NAME" \
    --dataset.root="$EVAL_DATASET_NAME" \
    --dataset.push_to_hub=false \
    --dataset.num_episodes=$NUM_EPISODES \
    --policy.path="$CHECKPOINT" \
    --policy.device=cuda \
    --auto_reset_to_origin=true \
    --display_data=true \
    # --dataset.rename_map='{"observation.images.gripper_cam": "observation.images.camera1", "observation.images.top_cam": "observation.images.camera2"}' \