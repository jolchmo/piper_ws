#!/usr/bin/env bash
# ============================================================================
# Piper 工作流公共函数库
# 各阶段脚本先 `source config.env`，再 `source "$WS_DIR/scripts/lib.sh"`。
# ============================================================================

# ----------------------------------------------------------------------------
# 由 CAMERAS 关联数组构建 lerobot --robot.cameras 的 JSON（Intel RealSense）。
# 依赖: CAMERAS, CAMERA_FPS, CAMERA_WIDTH, CAMERA_HEIGHT
# ----------------------------------------------------------------------------
build_cameras_config() {
    local config="{" first=true cam_name cam_path
    for cam_name in "${!CAMERAS[@]}"; do
        cam_path="${CAMERAS[$cam_name]}"
        [ -z "$cam_path" ] && continue
        if $first; then first=false; else config+=", "; fi
        config+="$cam_name: {type: intelrealsense, serial_number_or_name: \"$cam_path\", fps: $CAMERA_FPS, width: $CAMERA_WIDTH, height: $CAMERA_HEIGHT}"
    done
    config+="}"
    echo "$config"
}

# ----------------------------------------------------------------------------
# 打印当前启用的相机（给操作者看的，不参与命令构建）。
# ----------------------------------------------------------------------------
show_cameras_info() {
    if [ "${#CAMERAS[@]}" -eq 0 ]; then
        echo "  📷 相机: 已禁用"
        return
    fi
    local cam_name has=false
    for cam_name in "${!CAMERAS[@]}"; do
        if [ -n "${CAMERAS[$cam_name]}" ]; then
            echo "  📷 相机 $cam_name: ${CAMERAS[$cam_name]}"
            has=true
        fi
    done
    $has || echo "  📷 相机: 已禁用"
}

# ----------------------------------------------------------------------------
# 由 CAMERAS + STATE_DIM 动态生成 --policy.input_features 的 JSON。
# 这样在 config.env 增减相机后训练维度会自动同步，无需再手改训练脚本。
# ----------------------------------------------------------------------------
build_input_features() {
    local feats="" first=true cam_name
    for cam_name in "${!CAMERAS[@]}"; do
        [ -z "${CAMERAS[$cam_name]}" ] && continue
        if $first; then first=false; else feats+=", "; fi
        feats+="\"observation.images.$cam_name\": {\"shape\": [3, $CAMERA_HEIGHT, $CAMERA_WIDTH], \"type\": \"VISUAL\"}"
    done
    [ -n "$feats" ] && feats+=", "
    feats+="\"observation.state\": {\"shape\": [$STATE_DIM], \"type\": \"STATE\"}"
    echo "{$feats}"
}

# ----------------------------------------------------------------------------
# 确保给定的 CAN 接口都已就绪，否则 source 指定的 setup 脚本初始化。
# 用法: ensure_can <setup脚本路径> <can名1> [<can名2> ...]
# ----------------------------------------------------------------------------
ensure_can() {
    local setup_script="$1"; shift
    local can missing=false
    for can in "$@"; do
        ip link show "$can" &>/dev/null || missing=true
    done
    if $missing; then
        echo "⚠️  CAN 接口未就绪，正在调用 $(basename "$setup_script") 初始化..."
        source "$setup_script"
        for can in "$@"; do
            if ! ip link show "$can" &>/dev/null; then
                echo "❌ CAN 接口 '$can' 初始化失败，退出"
                exit 1
            fi
        done
    else
        echo "✅ CAN 接口已就绪: $*"
    fi
}

# ----------------------------------------------------------------------------
# 按 DATASET_SOURCE(local|remote) 把训练用的数据集参数填进全局数组 DATASET_ARGS。
#   local  -> --dataset.root=<本地> --dataset.repo_id=<远程>（从本地盘读）
#   remote -> 仅 --dataset.repo_id=<远程>（从 HuggingFace 拉取）
# 依赖: DATASET_LOCAL, DATASET_REMOTE
# ----------------------------------------------------------------------------
set_dataset_train_args() {
    DATASET_ARGS=(--dataset.repo_id="$DATASET_REMOTE")
    if [ "${DATASET_SOURCE:-local}" != "remote" ]; then
        DATASET_ARGS+=(--dataset.root="$DATASET_LOCAL")
    fi
}

# ----------------------------------------------------------------------------
# 解析评估用的 checkpoint：显式传参($1，即命令行参数或 EVAL_MODEL)优先；
# 留空则按 MODEL_SOURCE 取 CKPT_LOCAL(本地) 或 CKPT_REMOTE(HF 仓库)。
# ----------------------------------------------------------------------------
resolve_ckpt() {
    if [ -n "$1" ]; then echo "$1"; return; fi
    if [ "${MODEL_SOURCE:-local}" = "remote" ]; then echo "$CKPT_REMOTE"; else echo "$CKPT_LOCAL"; fi
}

# ----------------------------------------------------------------------------
# 打印配置后请操作者确认。设置 AUTO_CONFIRM=1 可跳过（用于无人值守/脚本调用）。
# ----------------------------------------------------------------------------
confirm_or_exit() {
    [ "${AUTO_CONFIRM:-0}" = "1" ] && return 0
    echo ""
    local ans
    read -p "确认以上配置并开始? [Y/n]: " ans
    case "$ans" in
        [nN]|[nN][oO]) echo "已取消。"; exit 0 ;;
    esac
}
