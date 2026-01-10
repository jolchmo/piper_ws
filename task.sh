#!/bin/bash
SBATCH --job-name=junxi_debug
SBATCH --output=logs/debug_%j.out
#SBATCH --error=logs/debug_%j.err
SBATCH --cpus-per-task=8
SBATCH --gres=gpu:1
SBATCH --mem=64G
SBATCH --time=4:00:00

# 此处进入环境
source /home/junxi/piper_ws/.venv/bin/activate

task_file=${1:-"/home/junxi/piper_ws/scripts/single/3_train_policy.sh"}


# 此处执行命令（建议加上 srun，方便被 slurm 监控）
srun bash $task_file
