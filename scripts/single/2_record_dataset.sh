#!/bin/bash
# 录制数据集脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 命令行参数覆盖默认值
DATASET_NAME=${1:-"$DEFAULT_DATASET_NAME"}
NUM_EPISODES=${2:-$DEFAULT_NUM_EPISODES}

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
    --dataset.root="$LOCAL_DATASET_DIR/$MISSION_NAME"  \              # 指定本地保存路径
    --dataset.push_to_hub=false \               # 禁用上传到 Hub
    --dataset.num_episodes=$NUM_EPISODES \
    --display_data=true
