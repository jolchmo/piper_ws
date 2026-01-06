#!/bin/bash
# 录制数据集脚本

DATASET_NAME=${1:-"jolch/piper_pickandplace"}
NUM_EPISODES=${2:-50}

# CAN 接口名称
CAN_LEADER="can_leader"
CAN_FOLLOWER="can_follower"

# 相机配置
# 设置为空字符串 "" 禁用相机
CAMERA_PATH="/dev/video6"
CAMERA_FPS=30
CAMERA_WIDTH=640
CAMERA_HEIGHT=480

echo "=========================================="
echo "  Piper 数据采集脚本"
echo "=========================================="

# 检查 can_leader 是否存在
if ! ip link show "$CAN_LEADER" &>/dev/null; then
    echo "⚠️  $CAN_LEADER 接口不存在，正在调用 setup.sh 初始化..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/setup.sh"
    
    # 再次检查
    if ! ip link show "$CAN_LEADER" &>/dev/null; then
        echo "❌ CAN 接口初始化失败，退出"
        exit 1
    fi
else
    echo "✅ $CAN_LEADER 已就绪"
fi

# 构建相机配置
if [ -n "$CAMERA_PATH" ]; then
    CAMERAS_CONFIG="{ gripper_cam: {type: opencv, index_or_path: \"$CAMERA_PATH\", fps: $CAMERA_FPS, width: $CAMERA_WIDTH, height: $CAMERA_HEIGHT} }"
    echo "📷 相机已启用: $CAMERA_PATH"
else
    CAMERAS_CONFIG="{}"
    echo "📷 相机已禁用"
fi

echo ""
echo "🤖 启动遥操作..."
echo ""

lerobot-record \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_leader \
    --teleop.port="$CAN_LEADER" \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --dataset.repo_id=$DATASET_NAME \
    --dataset.root="./datasets"  \              # 指定本地保存路径
    --dataset.push_to_hub=false \               # 禁用上传到 Hub
    --dataset.num_episodes=$NUM_EPISODES \
    --display_data=true
