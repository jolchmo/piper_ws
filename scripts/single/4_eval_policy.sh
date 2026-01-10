#!/bin/bash
# 评估策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"





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

NUM_EPISODES=$DEFAULT_NUM_EPISODES


MODEL_NAME=${1:-"None"}
if [ "$MODEL_NAME" = "None" ]; then
    echo "⚠️ 未指定模型名称，请在命令行第一个参数中提供模型名称"
    exit 1
fi

if ls  "$LOCAL_MODEL_DIR/$MODEL_NAME" | grep -q "checkpoints"; then
    echo "✅ 找到模型 $MODEL_NAME"
else
    echo "❌ 未找到模型 $MODEL_NAME，请检查模型名称是否正确"
    exit 1
fi

STEPS=${2:-"last"}
CHECKPOINT="$LOCAL_MODEL_DIR/$MODEL_NAME/checkpoints/$STEPS/pretrained_model"
EVAL_DATASET_NAME="$LOCAL_DATASET_DIR/eval_$RUN_ID"
EVAL_REPO_DATASET_NAME="$REPO_USER/eval_$RUN_ID"



echo "=========================================="
echo "  Piper 单臂策略部署脚本"
echo "=========================================="
echo "RUN_ID" : $RUN_ID
echo "模型: $CHECKPOINT"
echo "任务: $MISSION_NAME"
echo "使用权重$CHECKPOINT 评估策略，评估数据集保存在 $EVAL_DATASET_NAME"
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
    --display_data=true