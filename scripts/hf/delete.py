from lerobot.datasets.utils import load_nested_dataset, get_hf_features_from_features
from lerobot.datasets.dataset_tools import delete_episodes
from lerobot.datasets.lerobot_dataset import LeRobotDatasetMetadata
from pathlib import Path
import sys
sys.path.insert(0, "./lerobot/src")


DATASET_PATH = Path("./datasets/piper_20260108")

# 只加载元数据
meta = LeRobotDatasetMetadata(repo_id="piper_20260108", root=DATASET_PATH)

# 构建最小化 dataset 对象


class MinimalDataset:
    def __init__(self, meta, root):
        self.meta = meta
        self.root = root
        self.repo_id = meta.repo_id
        self.image_transforms = None
        self.delta_timestamps = None
        self.tolerance_s = 1e-4
        features = get_hf_features_from_features(meta.features)
        self.hf_dataset = load_nested_dataset(root / "data", features=features)


dataset = MinimalDataset(meta, DATASET_PATH)

# 删除 episode 37
new_dataset = delete_episodes(
    dataset=dataset,
    episode_indices=[35, 36, 37, 38, 39, 40, 41, 42, 43, 55],
    output_dir=Path("./datasets/piper_cleaned"),
    repo_id="piper_cleaned",
)
print(f"新数据集: {new_dataset.meta.total_episodes} episodes")
