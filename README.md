# piper_ws

AgileX **Piper** 机械臂(单臂 / 双臂)的遥操作、数据采集与模仿学习训练 / 部署工作区。
本仓库是围绕 HuggingFace [**LeRobot**](https://github.com/huggingface/lerobot) 的一层封装:
提供了 Piper 的自定义机器人插件,以及一套面向操作者的工作流脚本;CLI 工具、训练循环、
数据集格式等核心能力都来自 `lerobot` 子模块。

---

## 1. 克隆与子模块初始化

`lerobot/`、`piper_lerobot/`、`piper_sdk/` 都是 git 子模块,新克隆后是空的,先初始化:

```bash
git submodule update --init --recursive
```

- `lerobot/` — HuggingFace LeRobot 上游,所有 `lerobot-*` 命令的来源
- `piper_lerobot/` — 自定义插件,注册 `piper_follower` / `piper_leader` / `piper_bimanual` 等类型
- `piper_sdk/` — AgileX Piper SDK(CAN 层驱动)

## 2. 环境配置

使用 **uv**(Python 3.10):

```bash
uv venv -p 3.10
uv pip install -e ./lerobot
uv pip install -e ./piper_lerobot
uv pip install lerobot[smolvla]
```

依赖系统工具:`ethtool`、`can-utils`(CAN 接口);相机为 Intel RealSense。

```bash
sudo apt update && sudo apt install ethtool can-utils
```

绑定 RealSense 相机到稳定的 `/dev` 符号链接见 [`docs/cam_bind.md`](docs/cam_bind.md)。

---

## 3. 快速开始

最简单的方式是仓库根目录的交互式菜单:

```bash
./run.sh
```

先选「单臂 / 双臂」,再选要执行的阶段(查找 CAN / 初始化 / 遥操作 / 录制 / 训练 / 评估 / 下电)。
每个阶段也可以直接单独运行,例如:

```bash
bash scripts/single/2_record_dataset.sh
```

| 阶段 | 单臂脚本 | 说明 |
|------|----------|------|
| 0 | `0_find_all_can_port.sh` | 列出 USB bus-info ↔ CAN 接口的对应关系 |
| 1 | `1_setup.sh` | 加载 `gs_usb`、按 `USB_PORTS` 激活并重命名 CAN 接口 |
| 2 | `2_teleoperate.sh` / `2_record_dataset.sh` | leader→follower 遥操作 / 用 `lerobot-record` 采集数据 |
| 3 | `3_train_policy.sh` | 用 `lerobot-train` 训练策略(`torchrun` 多卡) |
| 4 | `4_eval_policy.sh` | 部署 checkpoint 并录制评估数据(模型路径用第一个参数指定) |

录制 / 遥操作 / 评估脚本在 CAN 接口缺失时会自动调用 `1_setup.sh`。

---

## 4. 配置:只改 `config.env`

所有端口、相机、策略、路径都集中在 `scripts/single/config.env` 和
`scripts/bimanual/config.env`,**改配置请改这个文件,不要改各阶段脚本**。

凡是写成 `${VAR:-默认值}` 的项,都可以用环境变量临时覆盖,无需编辑文件:

```bash
NUM_EPISODES=30 bash scripts/single/2_record_dataset.sh
POLICY=act TRAIN_STEPS=50000 bash scripts/single/3_train_policy.sh
```

设置 `AUTO_CONFIRM=1` 可跳过启动前的确认提示(无人值守)。

常用约定:

- **CAN 接口** 用物理 USB bus-info(如 `1-12:1.0`)在 `USB_PORTS` 里映射到逻辑名
  (`can_leader` / `can_follower`;双臂为 `can_l_*` / `can_r_*`)。
  用 `sudo ethtool -i <iface>` 查 bus-info。
- **相机** 为 Intel RealSense,按序列号写在 `CAMERAS` 数组里;key 会成为数据集特征名
  (如 `observation.images.top_cam`),并自动进入训练的 `--policy.input_features`。
  清空 `CAMERAS` 数组即可禁用相机。
- `POLICY` / `ROBOT` / `REPO_USER` / `LOCAL_*_DIR` 决定派生出的数据集、模型命名。

> 单臂 `3_train_policy.sh` 目前针对 **wall_x** 调优(预训练路径、`flash_attention_2`、
> `bfloat16`);其 `input_features` 由 `CAMERAS` + `STATE_DIM` 自动生成。
> 双臂状态维度默认为 `STATE_DIM=14`(左右各 7)。

---

## 5. HuggingFace Hub

数据集与模型推送到 `$REPO_USER`(`jolch`)名下,用脚本里的 `*_PUSH_TO_HUB` 开关控制。
常用命令:

```bash
# 上传模型(单个 checkpoint 目录)
hf upload jolch/<model_repo> <本地checkpoint目录>

# 上传大模型目录
hf upload-large-folder jolch/pig_rgy \
    /DATA/disk0/junxi/model/piper_wall_x_pig_rgy/checkpoints/last/pretrained_model/ \
    --repo-type model

# 上传数据集
hf upload jolch/<dataset_repo> <本地数据集目录> --repo-type=dataset

# 下载
hf download jolch/pig_rgy

# 可视化数据集
lerobot-dataset-viz \
    --root ./datasets/pig_rgy_dataset \
    --repo-id jolch/pig_rgy_dataset \
    --episode-index 1
```

更多见 [`docs/huggingface.md`](docs/huggingface.md)。

---

## 6. 注意事项

- 训练使用 `--dataset.video_backend=pyav`,因为目标环境没有 ffmpeg。
- `--wandb.enable=true` 需要先 `wandb login`。
- `wall_x` 策略需要 `flash_attention_2` 与 `bfloat16`(见 `3_train_policy.sh`)。
- `datasets/`、`dataset/`、`outputs/`、`wandb/` 已被 gitignore(生成的产物)。
- 给 Claude Code 的仓库说明见 [`CLAUDE.md`](CLAUDE.md)。
