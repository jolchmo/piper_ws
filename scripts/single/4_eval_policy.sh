#!/bin/bash
# 评估策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 命令行参数
if [ "$1" = "--force" ]; then
    echo "❌强制覆盖现有评估数据集"
    rm -rf "$LOCAL_DATASET_DIR/eval_$MISSION_NAME"
fi

# 使用绝对路径，确保无论从哪个目录运行脚本都能正确找到模型
CHECKPOINT="$(cd "$SCRIPT_DIR/../.." && pwd)/outputs/model/vla_0110/checkpoints/002000/pretrained_model"
# CHECKPOINT="$REPO_USER/model_name"
# CHECKPOINT="$REPO_USER/piper_dp"

NUM_EPISODES=$DEFAULT_NUM_EPISODES


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

EVAL_UNIT="smolvla_0110_001"
EVAL_REPO_DATASET_NAME="$REPO_USER/eval_${MISSION_NAME}_$EVAL_UNIT"
EVAL_DATASET_NAME="$LOCAL_DATASET_DIR/eval_${MISSION_NAME}_$EVAL_UNIT"
echo "$EVAL_REPO_DATASET_NAME"
echo "使用权重$CHECKPOINT 评估策略，评估数据集保存在 $EVAL_DATASET_NAME"

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
    --display_data=true