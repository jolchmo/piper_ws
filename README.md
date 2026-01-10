环境配置:
uv init 
uv venv -p 3.10 

uv pip install -e ./lerobot
uv pip install -e ./piper_lerobot

uv pip install lerobot[smolvla]


# 绑定相机(重要)
查看docs/bind_cam





可视化数据集
lerobot-dataset-viz --root '/home/john/piper_ws/datasets/piper_pickandplace_20260109_221601' --repo-id jolch/piper_pickandplace --episode-index 1