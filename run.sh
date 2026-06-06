#!/usr/bin/env bash
# ============================================================================
# Piper 工作流统一入口（交互式菜单）
#   用法:  ./run.sh
# 进入后依次选择「机械臂模式」和「阶段」，无需记忆脚本路径。
# 所有具体参数仍由对应的 scripts/<模式>/config.env 控制。
# ============================================================================
set -e
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "        🦾  Piper 工作流"
echo "=========================================="
echo "请选择机械臂模式:"
echo "  1) 单臂   single"
echo "  2) 双臂   bimanual"
read -p "输入序号 [1]: " arm_choice
case "${arm_choice:-1}" in
    1) ARM="single" ;;
    2) ARM="bimanual" ;;
    *) echo "❌ 无效选择"; exit 1 ;;
esac
DIR="$WS_DIR/scripts/$ARM"

echo ""
echo "已选择: $ARM"
echo "------------------------------------------"
echo "请选择要执行的阶段:"
echo "  0) 查找 CAN 端口   (find can port)"
echo "  1) 初始化 CAN      (setup)"
echo "  2) 遥操作          (teleoperate)"
echo "  3) 录制数据集      (record dataset)"
echo "  4) 训练策略        (train policy)"
echo "  5) 评估 / 部署     (eval policy)"
echo "  6) 下电 / 失能机械臂 (disable arms)"
echo "  q) 退出"
read -p "输入序号: " stage

ARGS=()
case "$stage" in
    0) SCRIPT="0_find_all_can_port.sh" ;;
    1) SCRIPT="1_setup.sh" ;;
    2) SCRIPT="2_teleoperate.sh" ;;
    3) SCRIPT="2_record_dataset.sh" ;;
    4) SCRIPT="3_train_policy.sh" ;;
    5) SCRIPT="4_eval_policy.sh"
       read -p "请输入模型路径或 HF 仓库 (留空则用 config.env 的 EVAL_MODEL): " model
       [ -n "$model" ] && ARGS+=("$model") ;;
    6) SCRIPT="0_disable_piper.sh" ;;
    q|Q) echo "再见 👋"; exit 0 ;;
    *) echo "❌ 无效选择"; exit 1 ;;
esac

TARGET="$DIR/$SCRIPT"
if [ ! -f "$TARGET" ]; then
    echo "❌ 找不到脚本: $TARGET"
    exit 1
fi

echo ""
echo "▶ 执行: scripts/$ARM/$SCRIPT ${ARGS[*]}"
echo ""
bash "$TARGET" "${ARGS[@]}"
