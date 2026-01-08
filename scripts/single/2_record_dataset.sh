#!/bin/bash
# Piper 数据录制脚本 - 支持 Reset 时自动回零位
#
# 键盘控制：
#   - 右箭头 →: 提前结束当前 episode
#   - 左箭头 ←: 重新录制当前 episode
#   - ESC: 停止整个录制过程


# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 参数说明:
#   --resume <数据集目录名>: 断点续采指定数据集
#   $1: episode 数量 (可选，默认使用 config.env 中的值)
#
# 使用示例:
#   ./2_record_dataset.sh                    # 新建数据集，使用默认 episode 数
#   ./2_record_dataset.sh 20                 # 新建数据集，录制 20 个 episode
#   ./2_record_dataset.sh --resume piper_pickandplace_20260107_232138  # 断点续采

# 解析参数
IS_RESUME="false"
RESUME_DATASET=""

# 检查是否有 --resume 参数
if [ "$1" = "--resume" ]; then
    IS_RESUME="true"
    RESUME_DATASET="$2"
    NUM_EPISODES=${3:-$DEFAULT_NUM_EPISODES}
    
    if [ -z "$RESUME_DATASET" ]; then
        echo "❌ 错误: --resume 需要指定数据集目录名"
        echo "   用法: ./2_record_dataset.sh --resume <数据集目录名>"
        exit 1
    fi
    LOCAL_DATASET_NAME="${LOCAL_DATASET_DIR%/*}/${RESUME_DATASET}"
else
    # 新建数据集
    NUM_EPISODES=${1:-$DEFAULT_NUM_EPISODES}
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    LOCAL_DATASET_NAME="${LOCAL_DATASET_DIR%/*}/${MISSION_NAME}_${TIMESTAMP}"
fi

echo "=========================================="
echo "  Piper 数据采集脚本 (支持自动回零位)"
echo "=========================================="
echo ""
echo "键盘控制："
echo "  → 右箭头: 结束当前 episode"
echo "  ← 左箭头: 重新录制当前 episode"
echo "  ESC: 停止录制"
echo ""

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

echo "📁 数据集名称: $MISSION_NAME"
echo "📂 存储路径: $LOCAL_DATASET_NAME"
echo ""
echo "🤖 启动数据录制..."
echo ""

# 使用自定义的 piper_record.py 脚本，支持 Reset 时自动回零位
python "$SCRIPT_DIR/piper_record.py" \
    --resume "$IS_RESUME" \
    --robot.type=piper_follower \
    --robot.port="$CAN_FOLLOWER" \
    --robot.id=follower \
    --robot.cameras="$CAMERAS_CONFIG" \
    --robot.discover_packages_path=piper_lerobot \
    --teleop.type=piper_leader \
    --teleop.port="$CAN_LEADER" \
    --teleop.id=leader \
    --teleop.discover_packages_path=piper_lerobot \
    --dataset.repo_id="$REPO_DATASET_NAME" \
    --dataset.single_task="$MISSION_NAME" \
    --dataset.root="$LOCAL_DATASET_NAME" \
    --dataset.push_to_hub=false \
    --dataset.num_episodes=$NUM_EPISODES \
    --auto_reset_to_origin=true \
    --display_data=true

# lerobot-record \
#     --robot.type=piper_follower \
#     --robot.port="$CAN_FOLLOWER" \
#     --robot.id=follower \
#     --robot.cameras="$CAMERAS_CONFIG" \
#     --robot.discover_packages_path=piper_lerobot \
#     --teleop.type=piper_leader \
#     --teleop.port="$CAN_LEADER" \
#     --teleop.id=leader \
#     --teleop.discover_packages_path=piper_lerobot \
#     --dataset.repo_id=$DATASET_NAME \
#     --dataset.root="$LOCAL_DATASET_DIR/$MISSION_NAME"  \
#     --dataset.push_to_hub=false \
#     --dataset.num_episodes=$NUM_EPISODES \