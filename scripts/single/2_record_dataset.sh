#!/bin/bash
# Piper 数据录制脚本 - 支持 Reset 时自动回零位

# 输入是自己手动采的数据
# 输出是数据集，一定会保存到本地
# 可以通过${DATASET_PUSH_TO_HUB}控制是否上传到远程huggingface，远端是REPO_DATASET_NAME

echo "=========================================="
echo "  Piper 数据采集脚本"
echo "=========================================="
echo ""
echo "键盘控制："
echo "  → 右箭头: 结束当前 episode"
echo "  ESC: 停止录制"
echo ""

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"


# 检查 can_leader 是否存在
if ! ip link show "$CAN_LEADER" &>/dev/null; then
    echo "⚠️  $CAN_LEADER 接口不存在，正在调用 setup.sh 初始化..."
    source "$SCRIPT_DIR/1_setup.sh"
    
    # 再次检查
    if ! ip link show "$CAN_LEADER" &>/dev/null; then
        echo "❌ CAN 接口初始化失败，退出"
        exit 1
    fi
else
    echo "✅ $CAN_LEADER 已就绪"
fi

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
            config+="$cam_name: {type: intelrealsense, serial_number_or_name: \"$cam_path\", fps: $CAMERA_FPS, width: $CAMERA_WIDTH, height: $CAMERA_HEIGHT}"
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



# 如果没有push_to_hub，则不会上传到远程仓库,但是一定需要id
# REPO_DATASET_NAME="$REPO_USER/$MISSION_NAME"

echo "=========================================="
echo "📁 数据集名称: $MISSION_NAME"
echo "📂 存储路径: $LOCAL_DATASET_NAME"
echo "📂 远程仓库: $REPO_DATASET_NAME"
echo "🎯 采集任务: $NUM_EPISODES 个 episode "
echo "=========================================="



DATASET_NAME="pig_rgy"
LOCAL_DATASET_NAME="$LOCAL_DATASET_DIR/${DATASET_NAME}_dataset"
REPO_DATASET_NAME="$REPO_USER/${DATASET_NAME}_dataset"
DATASET_PUSH_TO_HUB=true
NUM_EPISODES=50

# 使用自定义的 piper_record.py 脚本，支持 Reset 时自动回零位
# python "$SCRIPT_DIR/../piper_record.py" \
lerobot-record \
    --resume "true" \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_leader \
    --teleop.port="$CAN_LEADER" \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --dataset.single_task="Place the toy into the yellow bowl" \
    --dataset.root="$LOCAL_DATASET_NAME" \
    --dataset.repo_id="$REPO_DATASET_NAME" \
    --dataset.push_to_hub=$DATASET_PUSH_TO_HUB \
    --dataset.num_episodes=$NUM_EPISODES \
    --display_data=true