#!/usr/bin/env python3
"""
HuggingFace 数据集和模型管理工具
提供命令行界面来管理 HuggingFace Hub 上的数据集和模型
"""

import os
import argparse
from pathlib import Path
from typing import Optional, Literal
from huggingface_hub import HfApi, login, logout, whoami, list_repo_files
from huggingface_hub.utils import HfHubHTTPError
import json


class HFManager:
    """HuggingFace Hub 管理器"""
    
    def __init__(self, token: Optional[str] = None):
        """初始化管理器"""
        self.token = token or os.getenv("HUGGINGFACE_TOKEN")
        self.api = HfApi(token=self.token)
        
    def login(self):
        """登录到 HuggingFace Hub"""
        try:
            if self.token:
                login(token=self.token, add_to_git_credential=True)
                print("✓ 成功登录到 HuggingFace Hub")
            else:
                login()
                print("✓ 成功登录到 HuggingFace Hub")
            info = whoami()
            print(f"  用户名: {info['name']}")
        except Exception as e:
            print(f"✗ 登录失败: {e}")
    
    def logout(self):
        """登出 HuggingFace Hub"""
        logout()
        print("✓ 已登出 HuggingFace Hub")
    
    def whoami(self):
        """显示当前用户信息"""
        try:
            info = whoami(token=self.token)
            print(f"当前用户: {info['name']}")
            print(f"用户类型: {info.get('type', 'user')}")
            if 'orgs' in info:
                print(f"所属组织: {', '.join([org['name'] for org in info['orgs']])}")
        except Exception as e:
            print(f"✗ 获取用户信息失败: {e}")
            print("  提示: 请先运行 'python hf_manager.py login' 进行登录")
    
    def list_repos(self, repo_type: Literal["dataset", "model"] = "dataset", author: Optional[str] = None):
        """列出仓库"""
        try:
            if not author:
                info = whoami(token=self.token)
                author = info['name']
            
            repos = list(self.api.list_repos(author=author, token=self.token))
            repos = [r for r in repos if r.id.startswith(f"{author}/")]
            
            if repo_type == "dataset":
                datasets = list(self.api.list_datasets(author=author, token=self.token))
                print(f"\n{author} 的数据集 ({len(datasets)} 个):")
                for ds in datasets:
                    print(f"  • {ds.id}")
            else:
                models = list(self.api.list_models(author=author, token=self.token))
                print(f"\n{author} 的模型 ({len(models)} 个):")
                for model in models:
                    print(f"  • {model.id}")
        except Exception as e:
            print(f"✗ 列出仓库失败: {e}")
    
    def create_repo(self, repo_id: str, repo_type: Literal["dataset", "model"] = "dataset", private: bool = False):
        """创建新仓库"""
        try:
            url = self.api.create_repo(
                repo_id=repo_id,
                repo_type=repo_type,
                private=private,
                token=self.token,
                exist_ok=False
            )
            print(f"✓ 成功创建 {repo_type}: {repo_id}")
            print(f"  URL: {url}")
        except Exception as e:
            print(f"✗ 创建仓库失败: {e}")
    
    def delete_repo(self, repo_id: str, repo_type: Literal["dataset", "model"] = "dataset"):
        """删除仓库"""
        confirm = input(f"确认删除 {repo_type} '{repo_id}'? (yes/no): ")
        if confirm.lower() != 'yes':
            print("已取消删除")
            return
        
        try:
            self.api.delete_repo(repo_id=repo_id, repo_type=repo_type, token=self.token)
            print(f"✓ 成功删除 {repo_type}: {repo_id}")
        except Exception as e:
            print(f"✗ 删除仓库失败: {e}")
    
    def repo_info(self, repo_id: str, repo_type: Literal["dataset", "model"] = "dataset"):
        """查看仓库信息"""
        try:
            if repo_type == "dataset":
                info = self.api.dataset_info(repo_id=repo_id, token=self.token)
            else:
                info = self.api.model_info(repo_id=repo_id, token=self.token)
            
            print(f"\n仓库信息: {repo_id}")
            print(f"  类型: {repo_type}")
            print(f"  作者: {info.author}")
            print(f"  私有: {info.private}")
            print(f"  创建时间: {info.created_at}")
            print(f"  最后更新: {info.last_modified}")
            if hasattr(info, 'downloads'):
                print(f"  下载次数: {info.downloads}")
            if hasattr(info, 'likes'):
                print(f"  点赞数: {info.likes}")
            
            # 列出文件
            files = list_repo_files(repo_id=repo_id, repo_type=repo_type, token=self.token)
            print(f"\n  文件列表 ({len(files)} 个):")
            for f in files[:20]:  # 只显示前20个
                print(f"    • {f}")
            if len(files) > 20:
                print(f"    ... 还有 {len(files) - 20} 个文件")
        except Exception as e:
            print(f"✗ 获取仓库信息失败: {e}")
    
    def create_tag(self, repo_id: str, tag: str, repo_type: Literal["dataset", "model"] = "dataset", 
                   revision: str = "main", message: Optional[str] = None):
        """为仓库创建标签"""
        try:
            self.api.create_tag(
                repo_id=repo_id,
                tag=tag,
                repo_type=repo_type,
                revision=revision,
                tag_message=message,
                token=self.token
            )
            print(f"✓ 成功为 {repo_id} 创建标签: {tag}")
        except Exception as e:
            print(f"✗ 创建标签失败: {e}")
    
    def delete_tag(self, repo_id: str, tag: str, repo_type: Literal["dataset", "model"] = "dataset"):
        """删除标签"""
        try:
            self.api.delete_tag(
                repo_id=repo_id,
                tag=tag,
                repo_type=repo_type,
                token=self.token
            )
            print(f"✓ 成功删除标签: {tag}")
        except Exception as e:
            print(f"✗ 删除标签失败: {e}")
    
    def list_tags(self, repo_id: str, repo_type: Literal["dataset", "model"] = "dataset"):
        """列出所有标签"""
        try:
            if repo_type == "dataset":
                info = self.api.dataset_info(repo_id=repo_id, token=self.token)
            else:
                info = self.api.model_info(repo_id=repo_id, token=self.token)
            
            tags = getattr(info, 'tags', [])
            print(f"\n{repo_id} 的标签:")
            if tags:
                for tag in tags:
                    print(f"  • {tag}")
            else:
                print("  (暂无标签)")
        except Exception as e:
            print(f"✗ 获取标签列表失败: {e}")
    
    def update_repo_visibility(self, repo_id: str, private: bool, repo_type: Literal["dataset", "model"] = "dataset"):
        """更新仓库可见性"""
        try:
            self.api.update_repo_visibility(
                repo_id=repo_id,
                private=private,
                repo_type=repo_type,
                token=self.token
            )
            visibility = "私有" if private else "公开"
            print(f"✓ 成功将 {repo_id} 设置为{visibility}")
        except Exception as e:
            print(f"✗ 更新仓库可见性失败: {e}")
    
    def upload_file(self, repo_id: str, file_path: str, path_in_repo: Optional[str] = None,
                    repo_type: Literal["dataset", "model"] = "dataset"):
        """上传文件到仓库"""
        try:
            if path_in_repo is None:
                path_in_repo = Path(file_path).name
            
            self.api.upload_file(
                path_or_fileobj=file_path,
                path_in_repo=path_in_repo,
                repo_id=repo_id,
                repo_type=repo_type,
                token=self.token
            )
            print(f"✓ 成功上传文件: {file_path} -> {repo_id}/{path_in_repo}")
        except Exception as e:
            print(f"✗ 上传文件失败: {e}")
    
    def upload_folder(self, repo_id: str, folder_path: str, path_in_repo: str = ".",
                      repo_type: Literal["dataset", "model"] = "dataset"):
        """上传文件夹到仓库"""
        try:
            self.api.upload_folder(
                folder_path=folder_path,
                path_in_repo=path_in_repo,
                repo_id=repo_id,
                repo_type=repo_type,
                token=self.token
            )
            print(f"✓ 成功上传文件夹: {folder_path} -> {repo_id}/{path_in_repo}")
        except Exception as e:
            print(f"✗ 上传文件夹失败: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="HuggingFace 数据集和模型管理工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例用法:
  # 登录
  python hf_manager.py login
  
  # 查看当前用户
  python hf_manager.py whoami
  
  # 列出我的数据集
  python hf_manager.py list --type dataset
  
  # 列出我的模型
  python hf_manager.py list --type model
  
  # 创建新数据集
  python hf_manager.py create username/my-dataset --type dataset
  
  # 查看仓库信息
  python hf_manager.py info username/my-dataset --type dataset
  
  # 创建标签
  python hf_manager.py tag username/my-dataset v1.0 --type dataset
  
  # 列出标签
  python hf_manager.py tags username/my-dataset --type dataset
  
  # 上传文件
  python hf_manager.py upload username/my-dataset data.parquet --type dataset
  
  # 上传文件夹
  python hf_manager.py upload-folder username/my-dataset ./data --type dataset
  
  # 设置为私有
  python hf_manager.py set-private username/my-dataset --type dataset
  
  # 设置为公开
  python hf_manager.py set-public username/my-dataset --type dataset
  
  # 删除仓库
  python hf_manager.py delete username/my-dataset --type dataset
        """
    )
    
    parser.add_argument("--token", help="HuggingFace API token (或使用环境变量 HUGGINGFACE_TOKEN)")
    
    subparsers = parser.add_subparsers(dest="command", help="可用命令")
    
    # login 命令
    subparsers.add_parser("login", help="登录到 HuggingFace Hub")
    
    # logout 命令
    subparsers.add_parser("logout", help="登出 HuggingFace Hub")
    
    # whoami 命令
    subparsers.add_parser("whoami", help="显示当前用户信息")
    
    # list 命令
    list_parser = subparsers.add_parser("list", help="列出仓库")
    list_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    list_parser.add_argument("--author", help="作者名称 (默认为当前用户)")
    
    # create 命令
    create_parser = subparsers.add_parser("create", help="创建新仓库")
    create_parser.add_argument("repo_id", help="仓库 ID (格式: username/repo-name)")
    create_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    create_parser.add_argument("--private", action="store_true", help="创建私有仓库")
    
    # delete 命令
    delete_parser = subparsers.add_parser("delete", help="删除仓库")
    delete_parser.add_argument("repo_id", help="仓库 ID")
    delete_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    
    # info 命令
    info_parser = subparsers.add_parser("info", help="查看仓库信息")
    info_parser.add_argument("repo_id", help="仓库 ID")
    info_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    
    # tag 命令
    tag_parser = subparsers.add_parser("tag", help="创建标签")
    tag_parser.add_argument("repo_id", help="仓库 ID")
    tag_parser.add_argument("tag", help="标签名称 (如: v1.0)")
    tag_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    tag_parser.add_argument("--revision", default="main", help="基于的分支/提交 (默认: main)")
    tag_parser.add_argument("--message", help="标签消息")
    
    # delete-tag 命令
    delete_tag_parser = subparsers.add_parser("delete-tag", help="删除标签")
    delete_tag_parser.add_argument("repo_id", help="仓库 ID")
    delete_tag_parser.add_argument("tag", help="标签名称")
    delete_tag_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    
    # tags 命令
    tags_parser = subparsers.add_parser("tags", help="列出所有标签")
    tags_parser.add_argument("repo_id", help="仓库 ID")
    tags_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    
    # set-private 命令
    set_private_parser = subparsers.add_parser("set-private", help="设置为私有仓库")
    set_private_parser.add_argument("repo_id", help="仓库 ID")
    set_private_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    
    # set-public 命令
    set_public_parser = subparsers.add_parser("set-public", help="设置为公开仓库")
    set_public_parser.add_argument("repo_id", help="仓库 ID")
    set_public_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    
    # upload 命令
    upload_parser = subparsers.add_parser("upload", help="上传文件")
    upload_parser.add_argument("repo_id", help="仓库 ID")
    upload_parser.add_argument("file_path", help="本地文件路径")
    upload_parser.add_argument("--path-in-repo", help="仓库中的路径 (默认为文件名)")
    upload_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    
    # upload-folder 命令
    upload_folder_parser = subparsers.add_parser("upload-folder", help="上传文件夹")
    upload_folder_parser.add_argument("repo_id", help="仓库 ID")
    upload_folder_parser.add_argument("folder_path", help="本地文件夹路径")
    upload_folder_parser.add_argument("--path-in-repo", default=".", help="仓库中的路径 (默认为根目录)")
    upload_folder_parser.add_argument("--type", choices=["dataset", "model"], default="dataset", help="仓库类型")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    manager = HFManager(token=args.token)
    
    if args.command == "login":
        manager.login()
    elif args.command == "logout":
        manager.logout()
    elif args.command == "whoami":
        manager.whoami()
    elif args.command == "list":
        manager.list_repos(repo_type=args.type, author=args.author)
    elif args.command == "create":
        manager.create_repo(args.repo_id, repo_type=args.type, private=args.private)
    elif args.command == "delete":
        manager.delete_repo(args.repo_id, repo_type=args.type)
    elif args.command == "info":
        manager.repo_info(args.repo_id, repo_type=args.type)
    elif args.command == "tag":
        manager.create_tag(args.repo_id, args.tag, repo_type=args.type, 
                          revision=args.revision, message=args.message)
    elif args.command == "delete-tag":
        manager.delete_tag(args.repo_id, args.tag, repo_type=args.type)
    elif args.command == "tags":
        manager.list_tags(args.repo_id, repo_type=args.type)
    elif args.command == "set-private":
        manager.update_repo_visibility(args.repo_id, private=True, repo_type=args.type)
    elif args.command == "set-public":
        manager.update_repo_visibility(args.repo_id, private=False, repo_type=args.type)
    elif args.command == "upload":
        manager.upload_file(args.repo_id, args.file_path, 
                          path_in_repo=args.path_in_repo, repo_type=args.type)
    elif args.command == "upload-folder":
        manager.upload_folder(args.repo_id, args.folder_path, 
                            path_in_repo=args.path_in_repo, repo_type=args.type)


if __name__ == "__main__":
    main()
