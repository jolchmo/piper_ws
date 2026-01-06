# LeRobot 数据集说明

## 概述

LeRobot 数据集是用于机器人学习的标准化数据格式,包含观测数据、动作数据和任务信息。支持图像、视频等多模态数据,并提供统计信息用于模型训练。

## 数据集配置参数

### 基本参数

- **`repo_id`**: 数据集标识符
  - 格式: `{hf_username}/{dataset_name}` (例如 `jolch/piper_pickandplace`)
  - 用途: 
    - 组织本地目录结构 (`{root}/{repo_id}/`)
    - Hugging Face Hub 仓库地址(如果上传)
    - 数据集元数据标识

- **`root`**: 本地存储根目录
  - 示例: `"./datasets"`
  - 实际路径: `{root}/{repo_id}/` (如 `./datasets/jolch/piper_pickandplace/`)

- **`push_to_hub`**: 是否上传到 Hugging Face Hub
  - `true`: 上传到 HF Hub (需要登录凭证)
  - `false`: 仅保存到本地

### 录制参数

- **`fps`**: 数据采集帧率 (默认: 30)
- **`num_episodes`**: 录制的 episode 数量 (默认: 50)
- **`episode_time_s`**: 每个 episode 的录制时间(秒) (默认: 60)
- **`reset_time_s`**: episode 间的重置时间(秒) (默认: 60)
- **`single_task`**: 任务描述 (必填)
- **`video`**: 是否将图像编码为视频 (默认: true)

## 目录结构

```
{root}/{repo_id}/
├── meta/
│   ├── info.json           # 数据集元信息
│   ├── stats.safetensors   # 统计数据(均值/标准差等)
│   ├── tasks.jsonl         # 任务列表
│   └── episodes/           # Episode 元数据
│       └── chunk-{chunk_index}/
│           └── {file_index}.parquet
├── data/                   # 数据文件(parquet 格式)
│   └── chunk-{chunk_index}/
│       └── {file_index}.parquet
└── videos/                 # 视频文件(MP4,可选)
    └── {camera_name}/      # 例如: gripper_cam
        └── chunk-{chunk_index}/
            └── {file_index}.mp4
```

### 示例路径

假设配置:
- `root = "./datasets"`
- `repo_id = "jolch/piper_pickandplace"`

实际路径为:
```
./datasets/jolch/piper_pickandplace/
├── meta/
├── data/
└── videos/
```

## 数据内容

### 1. 观测数据 (Observation)

每帧包含的观测信息:

- **机器人状态**
  - 关节位置 (joint positions)
  - 关节速度 (joint velocities)
  - 末端执行器状态 (gripper state)
  - 其他传感器数据

- **相机数据**
  - 各个视角的图像/视频
  - 支持多个相机同时录制
  - 可配置分辨率、帧率

- **时间戳**
  - 每帧的精确时间信息
  - 用于同步和回放

### 2. 动作数据 (Action)

机器人执行的动作:

- 关节目标位置
- 关节目标速度
- 末端执行器指令
- 其他控制信号

### 3. 任务信息 (Task)

- 任务描述字符串
- 用于多任务学习和条件策略

### 4. Episode 元数据

每个 episode 包含:

- Episode 索引
- 起止帧索引
- 持续时间
- 数据文件位置索引
- 任务标签

## 文件格式

| 类型     | 格式            | 用途                              |
| -------- | --------------- | --------------------------------- |
| 数值数据 | **Parquet**     | 高效的列式存储,用于观测和动作数据 |
| 视频数据 | **MP4**         | 压缩视频格式,节省存储空间         |
| 元数据   | **JSON/JSONL**  | 数据集信息、任务列表              |
| 统计数据 | **SafeTensors** | 归一化参数(均值、标准差等)        |

## 统计数据 (Stats)

`meta/stats.safetensors` 包含训练时需要的归一化参数:

- **均值 (mean)**: 各特征的平均值
- **标准差 (std)**: 各特征的标准差
- **最小值 (min)**: 各特征的最小值
- **最大值 (max)**: 各特征的最大值

这些统计信息用于:
- 数据标准化/归一化
- 提高模型训练稳定性
- 保证输入数据在合理范围内

## 特征 (Features)

数据集的 features 定义了每个数据项的:

- **名称** (key)
- **数据类型** (dtype): `image`, `video`, `float`, `int` 等
- **形状** (shape): 数据维度
- **名称映射** (names): 维度的语义名称(如关节名称)

### 示例 Features

```python
features = {
    "observation.images.gripper_cam": {
        "dtype": "video",  # 或 "image"
        "shape": [480, 640, 3],  # [height, width, channels]
        "names": ["height", "width", "channel"]
    },
    "observation.state": {
        "dtype": "float",
        "shape": [7],  # 7个关节
        "names": ["joint_0", "joint_1", ..., "joint_6"]
    },
    "action": {
        "dtype": "float",
        "shape": [7],
        "names": ["joint_0", "joint_1", ..., "joint_6"]
    }
}
```

## 使用示例

### 录制数据集

```bash
lerobot-record \
    --robot.type=piper_follower \
    --robot.port=can_follower \
    --robot.cameras='{ gripper_cam: {type: opencv, index_or_path: "/dev/video6", fps: 30, width: 640, height: 480} }' \
    --teleop.type=piper_leader \
    --teleop.port=can_leader \
    --dataset.repo_id=jolch/piper_pickandplace \
    --dataset.root=./datasets \
    --dataset.push_to_hub=false \
    --dataset.num_episodes=50 \
    --dataset.single_task="Pick and place object"
```

### 加载数据集

```python
from lerobot.datasets.lerobot_dataset import LeRobotDataset

# 从本地加载
dataset = LeRobotDataset(
    repo_id="jolch/piper_pickandplace",
    root="./datasets"
)

# 访问数据
print(f"Total episodes: {dataset.meta.total_episodes}")
print(f"Total frames: {dataset.meta.total_frames}")
print(f"Features: {dataset.meta.features.keys()}")
print(f"Stats: {dataset.meta.stats.keys()}")

# 获取一帧数据
frame = dataset[0]
```

## 注意事项

### 存储空间

- **图像模式**: 每帧保存为 PNG,占用空间大
- **视频模式**: 压缩为 MP4,大幅减少存储空间(推荐)
- 建议设置 `--dataset.video=true`

### 数据质量

- 确保 `single_task` 准确描述任务
- 录制前测试相机和机器人连接
- 注意 FPS 稳定性,避免掉帧

### 版本兼容性

- 数据集格式版本: `v3.0`
- 使用 `codebase_version` 字段标识
- 旧版本数据集可能需要迁移

## 相关工具

### 编辑数据集

```bash
# 删除特定 episodes
lerobot-edit-dataset \
    --repo_id jolch/piper_pickandplace \
    --operation.type delete_episodes \
    --operation.episode_indices "[0, 2, 5]"

# 转换图像为视频
lerobot-edit-dataset \
    --repo_id jolch/piper_pickandplace \
    --new_repo_id jolch/piper_pickandplace_video \
    --operation.type convert_to_video
```

### 数据集统计

```bash
# 查看数据集信息
lerobot-visualize-dataset \
    --repo_id jolch/piper_pickandplace \
    --root ./datasets
```

## 参考资料

- [LeRobot 官方文档](https://github.com/huggingface/lerobot)
- [Hugging Face Datasets](https://huggingface.co/docs/datasets)
- [Parquet 格式说明](https://parquet.apache.org/)
