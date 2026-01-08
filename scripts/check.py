import blob
import pandas as pd
import argparse

parser = argparse.ArgumentParser(
    description="查看lerobot数据集中包含的episode索引",
    formatter_class=argparse.RawDescriptionHelpFormatter,
)

parser.add_argument(
    "--dataset",
    type=str,
    help="只禁用 leader 臂"
)
args = parser.parse_args()

num_file = blob.get_num_files(f"datasets/{args.dataset}/data/chunk-000")

for i in range(num_file):
    df = pd.read_parquet(f"datasets/{args.dataset}/data/chunk-000/file-00{i}.parquet")
    print("第" + str(i) + "个文件包含的episode索引: " + str(df['episode_index'].unique()))  # 例如输出 [20, 21, 22]
