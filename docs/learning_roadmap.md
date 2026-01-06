Transformer 自回归 (ACT)
    ▼
Diffusion (DDPM/DDIM)
    │
    ▼
Flow Matching (更快、更稳定)
    │
    ├──► SmolVLA (小 VLM)
    ├──► Wall-X (Qwen2.5-VL)
    └──► PI0/PI0.5 (PaliGemma)



** 对于VLA 模型需要
{
    "observation.images.xxx": ...,   # 多个相机
    "observation.state": ...,        # 双臂关节状态
    "action": ...,                   # 双臂动作
    "task": "任务描述"               # 可选，VLA 模型用
}
