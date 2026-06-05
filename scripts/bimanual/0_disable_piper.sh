#!/usr/bin/env bash
# 停用 Piper 双臂机器人脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 激活虚拟环境
source "$SCRIPT_DIR/../../.venv/bin/activate"

# 运行双臂失能脚本
python "$SCRIPT_DIR/../disable_piper.py" --bimanual "$@"