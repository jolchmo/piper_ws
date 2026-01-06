#!/usr/bin/env python3
# -*-coding:utf8-*-
"""
Piper 机械臂失能脚本

用于禁用 can_leader 和 can_follower 两个 CAN 接口上的机械臂。

USB 端口映射（与 teleoperate.sh 保持一致）:
    USB_PORTS["1-2:1.0"] = can_leader
    USB_PORTS["1-1:1.0"] = can_follower

参考: ref-piper/piper_sdk/piper_sdk/demo/V2/piper_ctrl_disable.py
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
        epilog="""
示例:
    # 禁用所有机械臂（默认）
    python disable_piper.py
    
    # 只禁用 leader 臂
    python disable_piper.py --leader
    
    # 只禁用 follower 臂
    python disable_piper.py --follower
    
    # 指定自定义 CAN 接口名称
    python disable_piper.py --can-leader can0 --can-follower can1
        """
    )

    parser.add_argument(
        "--leader",
        action="store_true",
        help="只禁用 leader 臂"
    )
    parser.add_argument(
        "--follower",
        action="store_true",
        help="只禁用 follower 臂"
    )
    parser.add_argument(
        "--can-leader",
        type=str,
        default="can_leader",
        help="Leader 臂的 CAN 接口名称 (默认: can_leader)"
    )
    parser.add_argument(
        "--can-follower",
        type=str,
        default="can_follower",
        help="Follower 臂的 CAN 接口名称 (默认: can_follower)"
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="失能超时时间（秒）(默认: 5.0)"
    )

    args = parser.parse_args()

    # 如果没有指定 --leader 或 --follower，则禁用所有
    disable_leader = args.leader or (not args.leader and not args.follower)
    disable_follower = args.follower or (not args.leader and not args.follower)

    print("=" * 50)
    print("  Piper 机械臂失能脚本")
    print("=" * 50)
    print()

    success = True
    total = (1 if disable_leader else 0) + (1 if disable_follower else 0)
    current = 0

    if disable_leader:
        current += 1
        print(f"[{current}/{total}] 处理 Leader 臂 ({args.can_leader})")
        print("-" * 50)
        if not disable_arm(args.can_leader, args.timeout):
            success = False
        print()

    if disable_follower:
        current += 1
        print(f"[{current}/{total}] 处理 Follower 臂 ({args.can_follower})")
        print("-" * 50)
        if not disable_arm(args.can_follower, args.timeout):
            success = False
        print()

    print("=" * 50)
    if success:
        print("✅ 所有机械臂已成功失能!")
    else:
        print("⚠️  部分机械臂失能失败，请检查连接")
        sys.exit(1)
    print("=" * 50)


if __name__ == "__main__":
    main()
