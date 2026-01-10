#!/usr/bin/env python3
"""
HuggingFace 批量操作脚本
基于配置文件进行批量操作
"""

import yaml
from pathlib import Path
from hf_manager import HFManager
import argparse


def load_config(config_path: str = "hf_config.yaml") -> dict:
    """加载配置文件"""
    with open(config_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def batch_create_tags(manager: HFManager, config: dict):
    """批量创建标签"""
    print("开始批量创建标签...")
    
    operations = config.get('batch_operations', {}).get('tag_repos', [])
    
    for op in operations:
        repo_id = op['repo_id']
        tag = op['tag']
        repo_type = op.get('repo_type', 'dataset')
        
        print(f"\n处理: {repo_id}")
        manager.create_tag(repo_id, tag, repo_type=repo_type)
    
    print("\n✓ 批量创建标签完成")


def batch_list_info(manager: HFManager, config: dict, repo_type: str = "dataset"):
    """批量显示仓库信息"""
    print(f"开始批量显示{repo_type}信息...")
    
    repos = config.get(f'{repo_type}s', [])
    
    for repo in repos:
        repo_id = repo['repo_id']
        print(f"\n{'='*60}")
        manager.repo_info(repo_id, repo_type=repo_type)
    
    print(f"\n{'='*60}")
    print("✓ 批量显示完成")


def sync_local_to_hub(manager: HFManager, local_path: str, repo_id: str, 
                      repo_type: str = "dataset", create_if_not_exists: bool = True):
    """同步本地文件夹到 HuggingFace Hub"""
    print(f"同步 {local_path} 到 {repo_id}...")
    
    # 检查仓库是否存在，不存在则创建
    if create_if_not_exists:
        try:
            manager.repo_info(repo_id, repo_type=repo_type)
        except Exception:
            print(f"仓库不存在，正在创建...")
            manager.create_repo(repo_id, repo_type=repo_type)
    
    # 上传文件夹
    manager.upload_folder(repo_id, local_path, repo_type=repo_type)
    print("✓ 同步完成")


def create_all_from_config(manager: HFManager, config: dict):
    """根据配置文件创建所有仓库"""
    print("开始根据配置创建仓库...")
    
    # 创建数据集
    datasets = config.get('datasets', [])
    for ds in datasets:
        repo_id = ds['repo_id']
        private = ds.get('private', config['defaults'].get('private', False))
        print(f"\n创建数据集: {repo_id}")
        manager.create_repo(repo_id, repo_type="dataset", private=private)
    
    # 创建模型
    models = config.get('models', [])
    for model in models:
        repo_id = model['repo_id']
        private = model.get('private', config['defaults'].get('private', False))
        print(f"\n创建模型: {repo_id}")
        manager.create_repo(repo_id, repo_type="model", private=private)
    
    print("\n✓ 批量创建完成")


def main():
    parser = argparse.ArgumentParser(description="HuggingFace 批量操作脚本")
    parser.add_argument("--config", default="hf_config.yaml", help="配置文件路径")
    parser.add_argument("--token", help="HuggingFace API token")
    
    subparsers = parser.add_subparsers(dest="command", help="可用命令")
    
    # batch-tag 命令
    subparsers.add_parser("batch-tag", help="批量创建标签")
    
    # batch-info 命令
    batch_info_parser = subparsers.add_parser("batch-info", help="批量显示仓库信息")
    batch_info_parser.add_argument("--type", choices=["dataset", "model"], 
                                   default="dataset", help="仓库类型")
    
    # sync 命令
    sync_parser = subparsers.add_parser("sync", help="同步本地文件夹到 Hub")
    sync_parser.add_argument("local_path", help="本地文件夹路径")
    sync_parser.add_argument("repo_id", help="目标仓库 ID")
    sync_parser.add_argument("--type", choices=["dataset", "model"], 
                           default="dataset", help="仓库类型")
    sync_parser.add_argument("--no-create", action="store_true", 
                           help="如果仓库不存在，不自动创建")
    
    # create-all 命令
    subparsers.add_parser("create-all", help="根据配置创建所有仓库")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # 加载配置
    config = load_config(args.config)
    manager = HFManager(token=args.token)
    
    if args.command == "batch-tag":
        batch_create_tags(manager, config)
    elif args.command == "batch-info":
        batch_list_info(manager, config, repo_type=args.type)
    elif args.command == "sync":
        sync_local_to_hub(manager, args.local_path, args.repo_id, 
                         repo_type=args.type, 
                         create_if_not_exists=not args.no_create)
    elif args.command == "create-all":
        create_all_from_config(manager, config)


if __name__ == "__main__":
    main()
