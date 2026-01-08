# RealSense 相机绑定指南

## 查找相机序列号和 index

```bash
# 查看指定设备的属性
udevadm info -a -n /dev/video4 | grep -E "ATTR{name}|ATTR{index}|ATTRS{serial}"
```

输出示例：
```
ATTR{name}=="Intel(R) RealSense(TM) Depth Ca"
ATTR{index}=="2"
ATTRS{serial}=="243223070649"
```

## 1. 创建 udev 规则文件

创建文件 `/etc/udev/rules.d/99-realsense-camera.rules`，内容如下：

```bash
# RealSense 相机绑定
# top_cam: 序列号 243223070649, index==2
SUBSYSTEM=="video4linux", ATTRS{serial}=="243223070649", ATTR{index}=="2", SYMLINK+="top_cam"
# gripper_cam: 序列号 242623070370, index==2
SUBSYSTEM=="video4linux", ATTRS{serial}=="242623070370", ATTR{index}=="2", SYMLINK+="gripper_cam"
```

## 2. 执行命令

```bash
# 创建规则文件（需要 sudo 权限）
sudo bash -c 'echo "SUBSYSTEM==\"video4linux\", ATTRS{serial}==\"243223070649\", ATTR{index}==\"2\", SYMLINK+=\"top_cam\"" > /etc/udev/rules.d/99-realsense-camera.rules'
sudo bash -c 'echo "SUBSYSTEM==\"video4linux\", ATTRS{serial}==\"242623070370\", ATTR{index}==\"2\", SYMLINK+=\"gripper_cam\"" > /etc/udev/rules.d/99-realsense-camera.rules'

sudo bash -c 'cat > /etc/udev/rules.d/99-realsense-camera.rules << EOF
SUBSYSTEM=="video4linux", ATTRS{serial}=="243223070649", ATTR{index}=="2", SYMLINK+="top_cam"
SUBSYSTEM=="video4linux", ATTRS{serial}=="242623070370", ATTR{index}=="2", SYMLINK+="gripper_cam"
EOF'

# 重新加载 udev 规则
sudo udevadm control --reload-rules

# 触发规则生效
sudo udevadm trigger
```

## 3. 验证绑定

```bash
# 检查符号链接是否创建成功
ls -la /dev/top_cam

# 查看链接指向的实际设备
readlink -f /dev/top_cam
```

## 注意事项

- `ATTR{index}` 是同一物理设备的多个视频流索引，不是 `/dev/videoX` 的编号
- RealSense 相机会创建多个 video 设备（深度、彩色、红外等）
- 需要通过 `udevadm info` 查找正确的 index 值

