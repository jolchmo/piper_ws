#!/usr/bin/env python
# Copyright 2025 WeGo-Robotics Inc. EDU team. All rights reserved.
# Licensed under the Apache License, Version 2.0
"""
Piper 机械臂数据录制脚本 - 支持 Reset 时自动回零位

键盘控制：
    - 右箭头 →: 结束当前 episode，保存数据，从臂回零位
    - 左箭头 ←: 重新录制当前 episode
    - S 键: 确认场景已 reset，开始下一个 episode
    - ESC: 停止整个录制过程
"""

from lerobot.utils.visualization_utils import init_rerun, log_rerun_data
from lerobot.utils.utils import get_safe_torch_device, init_logging, log_say
from lerobot.utils.robot_utils import precise_sleep
from lerobot.utils.control_utils import (
    is_headless,
    predict_action,
    sanity_check_dataset_name,
    sanity_check_dataset_robot_compatibility,
)
from lerobot.utils.constants import ACTION, OBS_STR
from lerobot.teleoperators.keyboard.teleop_keyboard import KeyboardTeleop
from lerobot.processor.rename_processor import rename_stats
from lerobot.processor import (
    PolicyAction,
    PolicyProcessorPipeline,
    RobotAction,
    RobotObservation,
    RobotProcessorPipeline,
    make_default_processors,
)
from lerobot.policies.utils import make_robot_action
from lerobot.policies.pretrained import PreTrainedPolicy
from lerobot.policies.factory import make_policy, make_pre_post_processors
from lerobot.datasets.video_utils import VideoEncodingManager
from lerobot.datasets.utils import build_dataset_frame, combine_feature_dicts
from lerobot.datasets.pipeline_features import (
    aggregate_pipeline_dataset_features,
    create_initial_features,
)
from lerobot.datasets.lerobot_dataset import LeRobotDataset
from lerobot.datasets.image_writer import safe_stop_image_writer
from lerobot.configs.policies import PreTrainedConfig
from lerobot.configs import parser
from lerobot.utils.import_utils import register_third_party_plugins
import logging
import os
import time
import traceback
from dataclasses import asdict, dataclass, field
from pathlib import Path
from pprint import pformat
from typing import Any
from functools import cache

# 优先使用本地缓存，避免重复下载模型
os.environ.setdefault("HF_HUB_ETAG_TIMEOUT", "0")
os.environ.setdefault("HUGGINGFACE_HUB_CACHE", os.path.expanduser("~/.cache/huggingface/hub"))

# 必须在所有 lerobot 导入之前注册第三方插件（如 intelrealsense 相机）
register_third_party_plugins()

from lerobot.cameras import CameraConfig  # noqa: F401
from lerobot.cameras.opencv.configuration_opencv import (  # noqa: F401
    OpenCVCameraConfig,
)
from lerobot.robots import Robot, RobotConfig, make_robot_from_config  # noqa: F401
from lerobot.teleoperators import (  # noqa: F401
    Teleoperator,
    TeleoperatorConfig,
    make_teleoperator_from_config,
)

logger = logging.getLogger(__name__)


# ============================================================================
# 自定义键盘监听器 - 支持 S 键确认场景已 reset
# ============================================================================
@cache
def _is_headless():
    """检测是否在无头环境中运行"""
    try:
        import pynput  # noqa
        return False
    except Exception:
        print(
            "Error trying to import pynput. Switching to headless mode. "
            "Keyboard inputs will not be available."
        )
        traceback.print_exc()
        return True


def init_piper_keyboard_listener():
    """
    初始化 Piper 专用键盘监听器，支持以下按键：
    - 右箭头: 结束当前 episode
    - 左箭头: 重新录制当前 episode
    - ESC: 停止录制
    - S 键: 确认场景已 reset，开始下一个 episode
    """
    events = {
        "exit_early": False,
        "rerecord_episode": False,
        "stop_recording": False,
        "scene_reset_confirmed": False,  # 新增：场景 reset 确认
    }

    if _is_headless():
        logging.warning(
            "Headless environment detected. "
            "Keyboard inputs will not be available."
        )
        return None, events

    from pynput import keyboard

    def on_press(key):
        try:
            if key == keyboard.Key.right:
                print("\n→ 右箭头: 结束当前 episode...")
                events["exit_early"] = True
            elif key == keyboard.Key.left:
                print("\n← 左箭头: 重新录制当前 episode...")
                events["rerecord_episode"] = True
                events["exit_early"] = True
            elif key == keyboard.Key.esc:
                print("\nESC: 停止录制...")
                events["stop_recording"] = True
                events["exit_early"] = True
            elif hasattr(key, 'char') and key.char == 's':
                print("\nS 键: 场景已 reset，开始下一个 episode...")
                events["scene_reset_confirmed"] = True
        except Exception as e:
            print(f"Error handling key press: {e}")

    listener = keyboard.Listener(on_press=on_press)
    listener.start()
    return listener, events


# ============================================================================
# 配置类
# ============================================================================
@dataclass
class DatasetRecordConfig:
    repo_id: str
    single_task: str
    root: str | Path | None = None
    fps: int = 30
    episode_time_s: int | float = 60
    reset_time_s: int | float = 60
    num_episodes: int = 50
    video: bool = True
    push_to_hub: bool = True
    private: bool = False
    tags: list[str] | None = None
    num_image_writer_processes: int = 0
    num_image_writer_threads_per_camera: int = 4
    video_encoding_batch_size: int = 1
    rename_map: dict[str, str] = field(default_factory=dict)

    def __post_init__(self):
        if self.single_task is None:
            raise ValueError(
                "You need to provide a task as argument in `single_task`."
            )


@dataclass
class PiperRecordConfig:
    robot: RobotConfig
    dataset: DatasetRecordConfig
    teleop: TeleoperatorConfig | None = None
    policy: PreTrainedConfig | None = None
    display_data: bool = False
    play_sounds: bool = True
    resume: bool = False
    auto_reset_to_origin: bool = True

    def __post_init__(self):
        policy_path = parser.get_path_arg("policy")
        if policy_path:
            cli_overrides = parser.get_cli_overrides("policy")
            self.policy = PreTrainedConfig.from_pretrained(
                policy_path, cli_overrides=cli_overrides
            )
            self.policy.pretrained_path = policy_path

        if self.teleop is None and self.policy is None:
            raise ValueError(
                "Choose a policy, a teleoperator or both to control the robot"
            )

    @classmethod
    def __get_path_fields__(cls) -> list[str]:
        return ["policy"]


# ============================================================================
# 录制循环
# ============================================================================
@safe_stop_image_writer
def record_loop(
    robot: Robot,
    events: dict,
    fps: int,
    teleop_action_processor,
    robot_action_processor,
    robot_observation_processor,
    dataset: LeRobotDataset | None = None,
    teleop: Teleoperator | list[Teleoperator] | None = None,
    policy: PreTrainedPolicy | None = None,
    preprocessor=None,
    postprocessor=None,
    control_time_s: int | None = None,
    single_task: str | None = None,
    display_data: bool = False,
):
    """录制循环"""
    if dataset is not None and dataset.fps != fps:
        raise ValueError(
            f"Dataset fps should equal requested fps "
            f"({dataset.fps} != {fps})."
        )

    teleop_arm = teleop_keyboard = None
    if isinstance(teleop, list):
        teleop_keyboard = next(
            (t for t in teleop if isinstance(t, KeyboardTeleop)), None
        )
        teleop_arm = next(
            (t for t in teleop if not isinstance(t, KeyboardTeleop)), None
        )

    if policy is not None and preprocessor is not None:
        policy.reset()
        preprocessor.reset()
        if postprocessor:
            postprocessor.reset()

    timestamp = 0
    start_episode_t = time.perf_counter()
    while control_time_s is None or timestamp < control_time_s:
        start_loop_t = time.perf_counter()

        if events["exit_early"]:
            events["exit_early"] = False
            break

        obs = robot.get_observation()
        obs_processed = robot_observation_processor(obs)

        if policy is not None or dataset is not None:
            observation_frame = build_dataset_frame(
                dataset.features, obs_processed, prefix=OBS_STR
            )

        if policy is not None and preprocessor is not None:
            action_values = predict_action(
                observation=observation_frame,
                policy=policy,
                device=get_safe_torch_device(policy.config.device),
                preprocessor=preprocessor,
                postprocessor=postprocessor,
                use_amp=policy.config.use_amp,
                task=single_task,
                robot_type=robot.robot_type,
            )
            act_processed = make_robot_action(action_values, dataset.features)
        elif policy is None and isinstance(teleop, Teleoperator):
            act = teleop.get_action()
            act_processed = teleop_action_processor((act, obs))
        elif policy is None and isinstance(teleop, list) and teleop_arm:
            arm_action = teleop_arm.get_action()
            arm_action = {f"arm_{k}": v for k, v in arm_action.items()}
            if teleop_keyboard:
                keyboard_action = teleop_keyboard.get_action()
                base_action = robot._from_keyboard_to_base_action(
                    keyboard_action
                )
                if len(base_action) > 0:
                    act = {**arm_action, **base_action}
                else:
                    act = arm_action
            else:
                act = arm_action
            act_processed = teleop_action_processor((act, obs))
        else:
            logging.info("No policy or teleoperator provided.")
            continue

        action_values = act_processed
        robot_action_to_send = robot_action_processor((act_processed, obs))
        robot.send_action(robot_action_to_send)

        if dataset is not None:
            action_frame = build_dataset_frame(
                dataset.features, action_values, prefix=ACTION
            )
            frame = {**observation_frame, **action_frame, "task": single_task}
            dataset.add_frame(frame)

        if display_data:
            log_rerun_data(observation=obs_processed, action=action_values)

        dt_s = time.perf_counter() - start_loop_t
        precise_sleep(1 / fps - dt_s)
        timestamp = time.perf_counter() - start_episode_t


def wait_for_scene_reset(events: dict, play_sounds: bool = True):
    """
    等待用户按 S 键确认场景已 reset。

    在从臂回零位后调用此函数，等待用户手动 reset 场景，
    然后按 S 键确认，才会开始下一个 episode 的同步操作。
    """
    log_say(
        "Waiting for scene reset. Press S to continue.",
        play_sounds
    )
    print("\n" + "=" * 50)
    print("⏸️  从臂已回零位，请手动 reset 场景")
    print("   按 S 键确认场景已 reset，开始下一个 episode")
    print("   按 ESC 停止录制")
    print("=" * 50 + "\n")

    events["scene_reset_confirmed"] = False
    while not events["scene_reset_confirmed"]:
        if events["stop_recording"]:
            return False
        time.sleep(0.1)

    events["scene_reset_confirmed"] = False
    return True


# ============================================================================
# 主录制函数
# ============================================================================
@parser.wrap()
def piper_record(cfg: PiperRecordConfig) -> LeRobotDataset:
    """Piper 机械臂数据录制主函数"""
    init_logging()
    logging.info(pformat(asdict(cfg)))
    if cfg.display_data:
        init_rerun(session_name="piper_recording")

    robot = make_robot_from_config(cfg.robot)
    teleop = None
    if cfg.teleop is not None:
        teleop = make_teleoperator_from_config(cfg.teleop)

    (
        teleop_action_processor,
        robot_action_processor,
        robot_observation_processor,
    ) = make_default_processors()

    dataset_features = combine_feature_dicts(
        aggregate_pipeline_dataset_features(
            pipeline=teleop_action_processor,
            initial_features=create_initial_features(
                action=robot.action_features
            ),
            use_videos=cfg.dataset.video,
        ),
        aggregate_pipeline_dataset_features(
            pipeline=robot_observation_processor,
            initial_features=create_initial_features(
                observation=robot.observation_features
            ),
            use_videos=cfg.dataset.video,
        ),
    )

    dataset = None
    listener = None

    try:
        if cfg.resume:
            dataset = LeRobotDataset(
                cfg.dataset.repo_id,
                root=cfg.dataset.root,
                batch_encoding_size=cfg.dataset.video_encoding_batch_size,
            )
            if hasattr(robot, "cameras") and len(robot.cameras) > 0:
                dataset.start_image_writer(
                    num_processes=cfg.dataset.num_image_writer_processes,
                    num_threads=(
                        cfg.dataset.num_image_writer_threads_per_camera
                        * len(robot.cameras)
                    ),
                )
            sanity_check_dataset_robot_compatibility(
                dataset, robot, cfg.dataset.fps, dataset_features
            )
        else:
            sanity_check_dataset_name(cfg.dataset.repo_id, cfg.policy)
            dataset = LeRobotDataset.create(
                cfg.dataset.repo_id,
                cfg.dataset.fps,
                root=cfg.dataset.root,
                robot_type=robot.name,
                features=dataset_features,
                use_videos=cfg.dataset.video,
                image_writer_processes=cfg.dataset.num_image_writer_processes,
                image_writer_threads=(
                    cfg.dataset.num_image_writer_threads_per_camera
                    * len(robot.cameras)
                ),
                batch_encoding_size=cfg.dataset.video_encoding_batch_size,
            )

        policy = None
        if cfg.policy is not None:
            # 如果指定了微调模型路径，直接从该路径加载权重，
            # 避免重复下载基础模型
            if cfg.policy.pretrained_path:
                cfg.policy.pretrained_name_or_path = cfg.policy.pretrained_path
            policy = make_policy(cfg.policy, ds_meta=dataset.meta)
        preprocessor = None
        postprocessor = None
        if cfg.policy is not None:
            preprocessor, postprocessor = make_pre_post_processors(
                policy_cfg=cfg.policy,
                pretrained_path=cfg.policy.pretrained_path,
                dataset_stats=rename_stats(
                    dataset.meta.stats, cfg.dataset.rename_map
                ),
                preprocessor_overrides={
                    "device_processor": {"device": cfg.policy.device},
                    "rename_observations_processor": {
                        "rename_map": cfg.dataset.rename_map
                    },
                },
            )

        robot.connect()
        if teleop is not None:
            teleop.connect()

        # 使用自定义键盘监听器
        listener, events = init_piper_keyboard_listener()

        print("\n" + "=" * 50)
        print("🎬 Piper 数据录制")
        print("=" * 50)
        print("键盘控制：")
        print("  → 右箭头: 结束当前 episode")
        print("  ← 左箭头: 重新录制当前 episode")
        print("  S 键: 确认场景已 reset")
        print("  ESC: 停止录制")
        print("=" * 50 + "\n")

        with VideoEncodingManager(dataset):
            recorded_episodes = 0
            num_episodes = cfg.dataset.num_episodes

            while recorded_episodes < num_episodes:
                if events["stop_recording"]:
                    break

                log_say(
                    f"Recording episode {dataset.num_episodes}",
                    cfg.play_sounds
                )
                print(f"\n🔴 录制 Episode {dataset.num_episodes}...")

                # 录制 episode
                record_loop(
                    robot=robot,
                    events=events,
                    fps=cfg.dataset.fps,
                    teleop_action_processor=teleop_action_processor,
                    robot_action_processor=robot_action_processor,
                    robot_observation_processor=robot_observation_processor,
                    teleop=teleop,
                    policy=policy,
                    preprocessor=preprocessor,
                    postprocessor=postprocessor,
                    dataset=dataset,
                    control_time_s=cfg.dataset.episode_time_s,
                    single_task=cfg.dataset.single_task,
                    display_data=cfg.display_data,
                )

                # 处理重新录制
                if events["rerecord_episode"]:
                    log_say("Re-record episode", cfg.play_sounds)
                    events["rerecord_episode"] = False
                    events["exit_early"] = False
                    dataset.clear_episode_buffer()
                    continue

                # 保存 episode
                dataset.save_episode()
                recorded_episodes += 1
                print(f"✅ Episode {recorded_episodes} 已保存")

                # 检查是否还需要录制更多 episode
                if events["stop_recording"]:
                    break
                if recorded_episodes >= num_episodes:
                    print("\n" + "🎉" * 20)
                    print(f"🎉 所有 {num_episodes} 个 episode 录制完成!")
                    print("🎉" * 20 + "\n")
                    break

                # ========== Reset 阶段 ==========
                remaining = num_episodes - recorded_episodes
                print(f"\n📋 还需录制 {remaining} 个 episode")
                log_say("Reset the environment", cfg.play_sounds)

                # 1. 从臂自动回零位
                if cfg.auto_reset_to_origin and hasattr(robot, 'parking'):
                    print("🔄 从臂回零位中...")
                    robot.parking()
                    print("✅ 从臂已回零位")

                # 2. 等待用户按 S 键确认场景已 reset
                if not wait_for_scene_reset(events, cfg.play_sounds):
                    break  # 用户按了 ESC

                print("✅ 场景已 reset，准备开始下一个 episode")

    finally:
        log_say("Stop recording", cfg.play_sounds, blocking=True)

        if dataset:
            dataset.finalize()

        if robot.is_connected:
            robot.disconnect()
        if teleop and teleop.is_connected:
            teleop.disconnect()

        if not _is_headless() and listener:
            listener.stop()

        if cfg.dataset.push_to_hub:
            dataset.push_to_hub(
                tags=cfg.dataset.tags, private=cfg.dataset.private
            )

        log_say("Exiting", cfg.play_sounds)
    return dataset


def main():
    piper_record()


if __name__ == "__main__":
    main()
