#!/usr/bin/env python3
# -*-coding:utf8-*-
"""
示例:
    # 禁用所有机械臂（默认单臂模式）
    python disable_piper.py

    # 只禁用 leader 臂
    python disable_piper.py --leader

    # 只禁用 follower 臂
    python disable_piper.py --follower

    # 指定自定义 CAN 接口名称
    python disable_piper.py --can-leader can0 --can-follower can1

    # 双臂模式：禁用所有 4 个机械臂
    python disable_piper.py --bimanual

    # 双臂模式：只禁用左臂
    python disable_piper.py --bimanual --left

    # 双臂模式：只禁用右臂
    python disable_piper.py --bimanual --right

    # 双臂模式：指定自定义 CAN 接口名称
    python disable_piper.py --bimanual --can-left-leader can0 --can-right-leader can1
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
    # 双臂模式参数
    parser.add_argument(
        "--bimanual",
        action="store_true",
        help="双臂模式"
    )
    parser.add_argument(
        "--left",
        action="store_true",
        help="双臂模式下只禁用左臂"
    )
    parser.add_argument(
        "--right",
        action="store_true",
        help="双臂模式下只禁用右臂"
    )
    parser.add_argument(
        "--can-left-leader",
        type=str,
        default="can_left_leader",
        help="左 Leader 臂的 CAN 接口名称 (默认: can_left_leader)"
    )
    parser.add_argument(
        "--can-left-follower",
        type=str,
        default="can_left_follower",
        help="左 Follower 臂的 CAN 接口名称 (默认: can_left_follower)"
    )
    parser.add_argument(
        "--can-right-leader",
        type=str,
        default="can_right_leader",
        help="右 Leader 臂的 CAN 接口名称 (默认: can_right_leader)"
    )
    parser.add_argument(
        "--can-right-follower",
        type=str,
        default="can_right_follower",
        help="右 Follower 臂的 CAN 接口名称 (默认: can_right_follower)"
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="失能超时时间（秒）(默认: 5.0)"
    )

    args = parser.parse_args()

    # 双臂模式
    if args.bimanual:
        print("=" * 50)
        print("  Piper 双臂机械臂失能脚本")
        print("=" * 50)
        print()

        # 确定要禁用哪些臂
        disable_left = args.left or (not args.left and not args.right)
        disable_right = args.right or (not args.left and not args.right)

        arms_to_disable = []
        if disable_left:
            if args.leader or (not args.leader and not args.follower):
                arms_to_disable.append(("左 Leader", args.can_left_leader))
            if args.follower or (not args.leader and not args.follower):
                arms_to_disable.append(("左 Follower", args.can_left_follower))
        if disable_right:
            if args.leader or (not args.leader and not args.follower):
                arms_to_disable.append(("右 Leader", args.can_right_leader))
            if args.follower or (not args.leader and not args.follower):
                arms_to_disable.append(("右 Follower", args.can_right_follower))

        success = True
        total = len(arms_to_disable)
        for i, (name, can_name) in enumerate(arms_to_disable, 1):
            print(f"[{i}/{total}] 处理 {name} 臂 ({can_name})")
            print("-" * 50)
            if not disable_arm(can_name, args.timeout):
                success = False
            print()

        print("=" * 50)
        if success:
            print("✅ 所有机械臂已成功失能!")
        else:
            print("⚠️  部分机械臂失能失败，请检查连接")
            sys.exit(1)
        print("=" * 50)
        return

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
