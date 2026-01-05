@echo off
REM 回放数据集脚本

set DATASET_NAME=%1
set EPISODE=%2

if "%DATASET_NAME%"=="" set DATASET_NAME=piper_dataset
if "%EPISODE%"=="" set EPISODE=0

lerobot-replay ^
    --robot.type=piper_follower ^
    --robot.port=can0 ^
    --robot.id=follower ^
    --robot.discover_packages_path=piper_lerobot ^
    --dataset.repo_id=%DATASET_NAME% ^
    --dataset.episode=%EPISODE%
