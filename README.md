环境配置:
uv init 
uv venv -p 3.10 

uv pip install -e ./lerobot
uv pip install -e ./piper_lerobot

uv pip install lerobot[smolvla]
