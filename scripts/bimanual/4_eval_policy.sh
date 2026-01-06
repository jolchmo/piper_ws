#!/bin/bash
# 双臂评估策略脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 命令行参数
CHECKPOINT=${1:-"outputs/train/$DEFAULT_POLICY/checkpoints/last.pt"}

echo "=========================================="
echo "  Piper 双臂策略评估脚本"
echo "=========================================="

# 检查 CAN 接口
check_can_ready() {
    local all_ready=true
    for can_name in "$CAN_LEFT_FOLLOWER" "$CAN_RIGHT_FOLLOWER"; do
        if ! ip link show "$can_name" &>/dev/null; then
            all_ready=false
            break
        fi
    done
    echo $all_ready
}

if [ "$(check_can_ready)" = "false" ]; then
    echo "⚠️  CAN 接口不存在，正在调用 1_setup.sh 初始化..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/1_setup.sh"

    if [ "$(check_can_ready)" = "false" ]; then
        echo "❌ CAN 接口初始化失败，退出"
        exit 1
    fi
else
    echo "✅ 所有 CAN 接口已就绪"
fi

echo ""
echo "🤖 启动双臂策略评估..."
echo ""

lerobot-eval \
    --robot.type=piper_bimanual \
    --robot.left_port="$CAN_LEFT_FOLLOWER" \
    --robot.right_port="$CAN_RIGHT_FOLLOWER" \
    --robot.id=follower \
    --robot.discover_packages_path=piper_lerobot \
    --policy.path=$CHECKPOINT \
    --display_data=true
