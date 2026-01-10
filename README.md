环境配置:
uv init 
uv venv -p 3.10 

uv pip install -e ./lerobot
uv pip install -e ./piper_lerobot

uv pip install lerobot[smolvla]


上传模型
hf upload-large-folder jolch/piper_dp ../../../DATA/disk0/junxi/model/smolvla_piper_0109_dp/checkpoints/last/pretrained_model/  --repo-type model

download jolch/piper_pickandplace   --repo-type dataset   --local-dir /DATA/disk0/junxi/.cache/huggingface/lerobot/jolch/piper_pickandplace