#!/bin/bash
# 双臂回放数据集脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 命令行参数
DATASET_NAME=${1:-"$DEFAULT_DATASET_NAME"}
EPISODE=${2:-0}

echo "=========================================="
echo "  Piper 双臂回放脚本"
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
echo "🤖 启动双臂回放..."
echo ""

lerobot-replay \
    --robot.type=piper_bimanual \
    --robot.left_port="$CAN_LEFT_FOLLOWER" \
    --robot.right_port="$CAN_RIGHT_FOLLOWER" \
    --robot.id=follower \
    --robot.discover_packages_path=piper_lerobot \
    --dataset.repo_id=$DATASET_NAME \
    --dataset.root="./datasets" \
    --dataset.episode=$EPISODE
