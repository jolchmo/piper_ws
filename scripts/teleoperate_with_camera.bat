@echo off
REM 带摄像头的遥操作脚本

lerobot-teleoperate ^
    --robot.type=piper_follower ^
    --robot.port=can0 ^
    --robot.id=follower ^
    --robot.discover_packages_path=piper_lerobot ^
    --robot.cameras="{ front: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30}}" ^
    --teleop.type=piper_leader ^
    --teleop.port=can1 ^
    --teleop.id=leader ^
    --teleop.discover_packages_path=piper_lerobot ^
    --display_data=true
