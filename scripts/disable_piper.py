#!/usr/bin/env python3
# -*-coding:utf8-*-
"""
示例:
    # 禁用所有机械臂（默认单臂模式）
    python disable_piper.py
"""
import time
import argparse
import sys

from piper_sdk import C_PiperInterface_V2


def disable_arm(can_name: str, timeout: float = 5.0) -> bool:
    """
    禁用指定 CAN 接口上的机械臂

    Args:
        can_name: CAN 接口名称，如 "can_leader" 或 "can_follower"
        timeout: 超时时间（秒）

    Returns:
        bool: 成功返回 True，失败返回 False
    """
    print(f"🔧 正在连接 {can_name}...")

    try:
        piper = C_PiperInterface_V2(can_name=can_name)
        piper.ConnectPort()

        print(f"✅ 已连接到 {can_name}")
        print(f"🔧 正在失能 {can_name} 上的机械臂...")

        start_time = time.time()
        while piper.DisablePiper():
            time.sleep(0.01)
            if time.time() - start_time > timeout:
                print(f"❌ {can_name} 失能超时")
                return False

        print(f"✅ {can_name} 失能成功!")
        return True

    except Exception as e:
        print(f"❌ {can_name} 失能失败: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="禁用 Piper 机械臂",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    # 双臂模式参数
    parser.add_argument(
        "--bimanual",
        action="store_true",
        help="双臂模式"
    )

    args = parser.parse_args()
    fail_name = []
    print("=" * 50)
    print("  Piper 双臂机械臂失能脚本")
    print("=" * 50)
    if args.bimanual:
        arms_to_disable = ["can_r_leader", "can_r_follower", "can_l_leader", "can_l_follower"]
    else:
        arms_to_disable = ["can_leader", "can_follower"]
    total = len(arms_to_disable)
    for i, can_name in enumerate(arms_to_disable):
        print(f"[{i}/{total}] 处理  ({can_name})")
        print("-" * 50)
        if not disable_arm(can_name, 5):
            fail_name.append(can_name)
        print()

    print("=" * 50)
    if not fail_name:
        print("✅ 所有机械臂已成功失能!")
    else:
        print("⚠️  部分机械臂失能失败，请检查连接")
        print("失败机械臂列表:")
        for name in fail_name:
            print(f" - {name}")
        sys.exit(1)
    print("=" * 50)
    return


if __name__ == "__main__":
    main()
