
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.venv/bin/activate"

# 停用 Piper 机器人脚本
python  "$SCRIPT_DIR/../disable_piper.py"