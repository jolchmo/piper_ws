#!/usr/bin/env bash

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

echo "=========================================="
echo "  Piper 遥操作启动脚本"
echo "=========================================="

# 检查 can_leader 是否存在
if ! ip link show "$CAN_LEADER" &>/dev/null; then
    echo "⚠️  $CAN_LEADER 接口不存在，正在调用 1_setup.sh 初始化..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

echo ""
echo "🤖 启动遥操作..."
echo ""

# 运行 lerobot-teleoperate
# 使用 entry_point 注册的命令
# discover_packages_path 用于发现第三方插件包
lerobot-teleoperate \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_leader \
    --teleop.port="$CAN_LEADER" \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --display_data=true
