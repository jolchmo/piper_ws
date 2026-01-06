#!/usr/bin/env bash
# 双臂遥操作 CAN 初始化脚本
# 参考: 1_setup.sh (单臂版本)

set -e

# ============================================================================
# 加载配置文件
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# 是否忽略 CAN 数量检查
IGNORE_CHECK=false

# ============================================================================
# 解析命令行参数
# ============================================================================
for arg in "$@"; do
    case "$arg" in
        --ignore)
            IGNORE_CHECK=true
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --ignore    忽略 CAN 接口数量检查"
            echo "  --help, -h  显示帮助信息"
            echo ""
            echo "USB 端口配置 (请根据实际情况修改脚本中的 USB_PORTS):"
            for k in "${!USB_PORTS[@]}"; do
                echo "  \"$k\" => \"${USB_PORTS[$k]}\""
            done
            exit 0
            ;;
    esac
done

# ============================================================================
# 检查 USB_PORTS 配置是否有重复
# ============================================================================
check_config() {
    echo "🔧 检查 USB_PORTS 配置..."
    declare -A TARGET_NAMES_COUNT
    local has_duplicate=false
    local line_num=0

    for k in "${!USB_PORTS[@]}"; do
        line_num=$((line_num + 1))
        IFS=':' read -r name bitrate <<< "${USB_PORTS[$k]}"

        if [[ -n "${TARGET_NAMES_COUNT[$name]}" ]]; then
            echo "  [$line_num] \"$k\"=\"${USB_PORTS[$k]}\"  ❌ 重复的目标 CAN 名称: '$name'"
            has_duplicate=true
        else
            echo "  [$line_num] \"$k\"=\"${USB_PORTS[$k]}\""
            TARGET_NAMES_COUNT["$name"]=1
        fi
    done

    if $has_duplicate; then
        echo "❌ [错误]: 发现重复的目标 CAN 接口名称，请修复配置后重试。"
        return 1
    fi
    return 0
}

# ============================================================================
# 初始化 CAN 接口
# ============================================================================
init_can() {
    echo ""
    echo "🔧 初始化 CAN 接口..."

    # 加载 gs_usb 模块
    if ! sudo modprobe gs_usb; then
        echo "❌ [错误]: 无法加载 gs_usb 模块"
        return 1
    fi

    # 检查 CAN 接口数量
    local predefined_count=${#USB_PORTS[@]}
    local current_can_count=$(ip link show type can 2>/dev/null | grep -c "link/can" || echo 0)

    if [ "$IGNORE_CHECK" = false ] && [ "$current_can_count" -ne "$predefined_count" ]; then
        echo "⚠️  [警告]: 检测到的 CAN 模块数量 ($current_can_count) 与预期数量 ($predefined_count) 不匹配"
        read -p "是否继续? (y/N): " user_input
        case "$user_input" in
            [yY]|[yY][eE][sS])
                echo "继续执行..."
                ;;
            *)
                echo "已退出。"
                return 1
                ;;
        esac
    fi

    # 获取系统中的 CAN 接口
    local interfaces=$(ip -br link show type can 2>/dev/null | awk '{print $1}')

    if [ -z "$interfaces" ]; then
        echo "❌ 未检测到 CAN 接口，请检查 USB 连接"
        return 1
    fi

    echo ""
    echo "🔍 [信息]: 系统中检测到以下 CAN 接口:"
    for iface in $interfaces; do
        echo "  - $iface"
    done

    local success_count=0
    local failed_count=0
    declare -A USB_PORT_STATUS
    for k in "${!USB_PORTS[@]}"; do
        USB_PORT_STATUS["$k"]="pending"
    done

    echo ""
    for iface in $interfaces; do
        echo "--------------------------- $iface ------------------------------"
        local bus_info=$(sudo ethtool -i "$iface" 2>/dev/null | grep "bus-info" | awk '{print $2}')

        if [ -z "$bus_info" ]; then
            echo "❌ [错误]: 无法获取接口 '$iface' 的 bus-info 信息"
            continue
        fi

        echo "[信息]: 系统接口 '$iface' 连接到 USB 端口 '$bus_info'"

        if [ -n "${USB_PORTS[$bus_info]}" ]; then
            IFS=':' read -r target_name target_bitrate <<< "${USB_PORTS[$bus_info]}"

            # 检查接口是否已激活
            local is_link_up=$(ip link show "$iface" | grep -q "UP" && echo "yes" || echo "no")
            local current_bitrate=$(ip -details link show "$iface" | grep -oP 'bitrate \K\d+' || echo 0)

            if [ "$is_link_up" = "yes" ] && [ "$current_bitrate" -eq "$target_bitrate" ]; then
                echo "[信息]: 接口 '$iface' 已激活，波特率为 $target_bitrate"

                if [ "$iface" != "$target_name" ]; then
                    if ip link show "$target_name" &>/dev/null; then
                        echo "⚠️  [警告]: 无法将 '$iface' 重命名为 '$target_name'，因为 '$target_name' 已存在"
                        continue
                    fi
                    echo "[信息]: 将接口 '$iface' 重命名为 '$target_name'"
                    sudo ip link set "$iface" down
                    sudo ip link set "$iface" name "$target_name"
                    sudo ip link set "$target_name" up
                    echo "[信息]: 接口已重命名为 '$target_name' 并重新激活"
                else
                    echo "[信息]: USB 端口 '$bus_info' 的接口名称已经是 '$target_name'"
                fi
            else
                if ip link show "$target_name" &>/dev/null && [ "$iface" != "$target_name" ]; then
                    echo "⚠️  [警告]: 无法将 '$iface' 重命名为 '$target_name'，因为 '$target_name' 已存在"
                    continue
                fi

                if [ "$is_link_up" = "yes" ]; then
                    echo "[信息]: 接口 '$iface' 已激活，但波特率 $current_bitrate 与设定的 $target_bitrate 不匹配"
                else
                    echo "[信息]: 接口 '$iface' 未激活或波特率未设置"
                fi

                # 设置接口波特率并激活
                sudo ip link set "$iface" down
                sudo ip link set "$iface" type can bitrate $target_bitrate
                sudo ip link set "$iface" up
                echo "[信息]: 接口 '$iface' 已设置波特率 $target_bitrate 并激活"

                # 重命名接口
                if [ "$iface" != "$target_name" ]; then
                    echo "[信息]: 将接口 '$iface' 重命名为 '$target_name'"
                    sudo ip link set "$iface" down
                    sudo ip link set "$iface" name "$target_name"
                    sudo ip link set "$target_name" up
                    echo "[信息]: 接口已重命名为 '$target_name' 并重新激活"
                fi
            fi
            success_count=$((success_count + 1))
            USB_PORT_STATUS["$bus_info"]="success"
        else
            echo "❌ [错误]: 接口 '$iface' 的 USB 端口 '$bus_info' 不在预定义的 USB_PORTS 列表中"
            echo "[信息]: 当前预定义的 USB_PORTS 配置:"
            for k in "${!USB_PORTS[@]}"; do
                echo "        '$k'"
            done
            echo "[提示]: 请检查 USB 设备是否插入正确的端口，或更新 USB_PORTS 配置"
        fi
        echo "-----------------------------------------------------------------"
    done

    # 检查失败的 USB 端口
    for k in "${!USB_PORT_STATUS[@]}"; do
        if [ "${USB_PORT_STATUS[$k]}" != "success" ]; then
            echo "❌ 预期的 CAN 接口在 USB 端口 '$k' 未找到或未激活"
            failed_count=$((failed_count + 1))
        fi
    done

    echo ""
    if [ "$success_count" -gt 0 ]; then
        echo "[结果]: ✅ $success_count 个预期的 CAN 接口处理成功"
    else
        echo "[结果]: ❌ 没有 USB 接口匹配预设的 CAN 配置，请检查 USB 端口连接是否正确"
        return 1
    fi

    if [ "$failed_count" -gt 0 ]; then
        echo "[结果]: 🚫 $failed_count 个预期的 CAN 接口激活失败或未找到"
    fi

    return 0
}

# ============================================================================
# 检查 CAN 接口是否就绪 (双臂: 4个接口)
# ============================================================================
check_can() {
    local left_leader_ready=false
    local right_leader_ready=false
    local left_follower_ready=false
    local right_follower_ready=false

    if ip link show "$CAN_LEFT_LEADER" &>/dev/null; then
        local state=$(ip link show "$CAN_LEFT_LEADER" | grep -oP 'state \K\w+')
        if [ "$state" = "UP" ]; then
            echo "✅ $CAN_LEFT_LEADER 已就绪"
            left_leader_ready=true
        fi
    fi

    if ip link show "$CAN_RIGHT_LEADER" &>/dev/null; then
        local state=$(ip link show "$CAN_RIGHT_LEADER" | grep -oP 'state \K\w+')
        if [ "$state" = "UP" ]; then
            echo "✅ $CAN_RIGHT_LEADER 已就绪"
            right_leader_ready=true
        fi
    fi

    if ip link show "$CAN_LEFT_FOLLOWER" &>/dev/null; then
        local state=$(ip link show "$CAN_LEFT_FOLLOWER" | grep -oP 'state \K\w+')
        if [ "$state" = "UP" ]; then
            echo "✅ $CAN_LEFT_FOLLOWER 已就绪"
            left_follower_ready=true
        fi
    fi

    if ip link show "$CAN_RIGHT_FOLLOWER" &>/dev/null; then
        local state=$(ip link show "$CAN_RIGHT_FOLLOWER" | grep -oP 'state \K\w+')
        if [ "$state" = "UP" ]; then
            echo "✅ $CAN_RIGHT_FOLLOWER 已就绪"
            right_follower_ready=true
        fi
    fi

    if $left_leader_ready && $right_leader_ready && $left_follower_ready && $right_follower_ready; then
        return 0
    fi

    echo "⚠️  CAN 接口未就绪，尝试初始化..."
    init_can || return 1

    # 再次检查
    for can_name in "$CAN_LEFT_LEADER" "$CAN_RIGHT_LEADER" "$CAN_LEFT_FOLLOWER" "$CAN_RIGHT_FOLLOWER"; do
        if ! ip link show "$can_name" &>/dev/null; then
            echo "❌ $can_name 初始化失败"
            return 1
        fi
    done

    return 0
}

# ============================================================================
# 主程序
# ============================================================================
echo "=========================================="
echo "  Piper 双臂 CAN 初始化脚本"
echo "=========================================="
echo ""

# 检查配置
check_config || exit 1

# 检查并初始化 CAN
check_can || exit 1

echo ""
echo "可以继续执行双臂遥操作命令了！"
echo ""
