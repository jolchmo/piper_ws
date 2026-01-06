#!/usr/bin/env bash

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

echo "=========================================="
echo "  Piper 双臂遥操作启动脚本"
echo "=========================================="

# 检查 CAN 接口是否存在
check_can_ready() {
    local all_ready=true
    for can_name in "$CAN_LEFT_LEADER" "$CAN_RIGHT_LEADER" "$CAN_LEFT_FOLLOWER" "$CAN_RIGHT_FOLLOWER"; do
        if ! ip link show "$can_name" &>/dev/null; then
            all_ready=false
            break
        fi
    done
    echo $all_ready
}

if [ "$(check_can_ready)" = "false" ]; then
    echo "⚠️  CAN 接口不存在，正在调用 1_setup_bimanual.sh 初始化..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/1_setup_bimanual.sh"

    # 再次检查
    if [ "$(check_can_ready)" = "false" ]; then
        echo "❌ CAN 接口初始化失败，退出"
        exit 1
    fi
else
    echo "✅ 所有 CAN 接口已就绪"
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
echo "🤖 启动双臂遥操作..."
echo ""

# 运行 lerobot-teleoperate (双臂模式)
lerobot-teleoperate \
    --robot.type=piper_bimanual \
    --robot.left_port="$CAN_LEFT_FOLLOWER" \
    --robot.right_port="$CAN_RIGHT_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_bimanual_leader \
    --teleop.left_port="$CAN_LEFT_LEADER" \
    --teleop.right_port="$CAN_RIGHT_LEADER" \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --display_data=true
