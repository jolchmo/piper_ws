@echo off
REM 录制数据集脚本

set DATASET_NAME=%1
set NUM_EPISODES=%2

if "%DATASET_NAME%"=="" set DATASET_NAME=piper_dataset
if "%NUM_EPISODES%"=="" set NUM_EPISODES=50

lerobot-record ^
    --robot.type=piper_follower ^
    --robot.port=can0 ^
    --robot.id=follower ^
    --robot.discover_packages_path=piper_lerobot ^
    --robot.cameras="{ front: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30}}" ^
    --teleop.type=piper_leader ^
    --teleop.port=can1 ^
    --teleop.id=leader ^
    --teleop.discover_packages_path=piper_lerobot ^
    --dataset.repo_id=%DATASET_NAME% ^
    --dataset.num_episodes=%NUM_EPISODES% ^
    --display_data=true
