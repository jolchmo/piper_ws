@echo off
REM 训练策略脚本

set DATASET_NAME=%1
set POLICY=%2

if "%DATASET_NAME%"=="" set DATASET_NAME=piper_dataset
if "%POLICY%"=="" set POLICY=act

python lerobot/scripts/train.py ^
    policy=%POLICY% ^
    dataset.repo_id=%DATASET_NAME% ^
    env.name=piper
