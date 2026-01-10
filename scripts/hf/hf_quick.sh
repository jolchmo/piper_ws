#!/bin/bash
# HuggingFace 快捷命令脚本

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   HuggingFace 管理工具快捷脚本${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 显示菜单
echo -e "${GREEN}可用命令:${NC}"
echo "  1) 查看我的信息"
echo "  2) 列出我的数据集"
echo "  3) 列出我的模型"
echo "  4) 查看仓库信息"
echo "  5) 创建标签"
echo "  6) 批量创建标签"
echo "  7) 同步本地数据集到 Hub"
echo "  8) 退出"
echo ""

read -p "请选择 (1-8): " choice

case $choice in
    1)
        python3 hf_manager.py whoami
        ;;
    2)
        python3 hf_manager.py list --type dataset
        ;;
    3)
        python3 hf_manager.py list --type model
        ;;
    4)
        read -p "请输入仓库 ID (如: jolch/piper_pickandplace): " repo_id
        read -p "仓库类型 [dataset/model] (默认: dataset): " repo_type
        repo_type=${repo_type:-dataset}
        python3 hf_manager.py info "$repo_id" --type "$repo_type"
        ;;
    5)
        read -p "请输入仓库 ID: " repo_id
        read -p "请输入标签名 (如: v1.0): " tag_name
        read -p "仓库类型 [dataset/model] (默认: dataset): " repo_type
        repo_type=${repo_type:-dataset}
        python3 hf_manager.py tag "$repo_id" "$tag_name" --type "$repo_type"
        ;;
    6)
        python3 hf_batch.py batch-tag
        ;;
    7)
        read -p "请输入本地路径: " local_path
        read -p "请输入目标仓库 ID: " repo_id
        python3 hf_batch.py sync "$local_path" "$repo_id"
        ;;
    8)
        echo -e "${YELLOW}再见!${NC}"
        exit 0
        ;;
    *)
        echo -e "${YELLOW}无效选择${NC}"
        exit 1
        ;;
esac
