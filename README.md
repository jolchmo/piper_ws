环境配置:
uv init 
uv venv -p 3.10 

uv pip install -e ./lerobot
uv pip install -e ./piper_lerobot

uv pip install lerobot[smolvla]


# 绑定相机(重要)
查看docs/bind_cam


上传模型
hf upload jolch/piper_smolvla_0110 ../../../DATA/disk0/junxi/model/piper_smolvla_20260110_1807/checkpoints/001000/1200  
hf upload-large-folder jolch/piper_dp ../../../DATA/disk0/junxi/model/smolvla_piper_0109_dp/ --repo-type model

上传数据库
hf upload jolch/piper_pickandplace ./piper_pickandplace_20260109_221601 --repo-type=dataset

可视化数据集
lerobot-dataset-viz --root '/home/john/piper_ws/datasets/piper_pickandplace_20260109_221601' --repo-id jolch/piper_pickandplace --episode-index 1



 
 
hf upload-large-folder jolch/piper_dp ../../../DATA/disk0/junxi/model/smolvla_piper_0109_dp/ --repo-type model