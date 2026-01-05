@echo off
REM 评估策略脚本

set CHECKPOINT=%1

if "%CHECKPOINT%"=="" set CHECKPOINT=outputs/train/act/checkpoints/last.pt

lerobot-eval ^
    --robot.type=piper_follower ^
    --robot.port=can0 ^
    --robot.id=follower ^
    --robot.discover_packages_path=piper_lerobot ^
    --policy.path=%CHECKPOINT% ^
    --display_data=true
