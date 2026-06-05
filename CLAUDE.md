# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A robotics workspace for teleoperating, recording demonstration data from, and
training/deploying imitation-learning policies on the **AgileX Piper** robot arm
(single-arm and bimanual). It is glue around HuggingFace **LeRobot** — this repo
contributes a custom robot plugin and a set of operator workflow scripts; the
heavy lifting (CLI tools, training loops, dataset format) lives in the `lerobot`
submodule.

## Repository layout & submodules

The three top-level directories `lerobot/`, `piper_lerobot/`, and `piper_sdk/`
are **git submodules** (see `.gitmodules`) and are typically empty on a fresh
clone. Initialize before doing anything real:

```bash
git submodule update --init --recursive
```

- `lerobot/` — HuggingFace LeRobot (upstream). Source of all `lerobot-*` CLI commands.
- `piper_lerobot/` — custom LeRobot plugin registering the Piper robot/teleop types
  (`piper_follower`, `piper_leader`, `piper_bimanual`). Referenced at runtime via
  `--robot.discover_packages_path=piper_lerobot`, which is how LeRobot's CLI
  discovers these third-party types.
- `piper_sdk/` — AgileX Piper SDK (`piper-sdk==0.6.0`), the CAN-level arm driver.
  Used directly in `scripts/disable_piper.py`.
- `main.py` is a placeholder, not an entry point.

## Environment setup

Uses **uv** (Python 3.10, pinned in `.python-version`; `pyproject.toml` requires
`>=3.10,<3.11`). `lerobot` and `piper_lerobot` are uv workspace members installed
editable; torch comes from the CUDA 12.8 index.

```bash
uv venv -p 3.10
uv pip install -e ./lerobot
uv pip install -e ./piper_lerobot
uv pip install lerobot[smolvla]
```

There is no test suite, linter config, or build step in this repo — work here is
operational scripting plus configuration, validated by running the workflow against
hardware.

## Operator workflow (the core of this repo)

`scripts/single/` (single arm) and `scripts/bimanual/` (two arms) each contain a
numbered pipeline. All scripts `source config.env` for their settings — **edit
`config.env`, not the scripts**, for ports/cameras/policy/paths.

| Stage | Single-arm script | Purpose |
|-------|-------------------|---------|
| 0 | `0_find_all_can_port.sh` | Map USB bus-info → CAN interface (needs `ethtool`, `can-utils`) |
| 1 | `1_setup.sh` | `modprobe gs_usb`, bring up & rename CAN interfaces per `USB_PORTS` |
| 2 | `2_teleoperate.sh` / `2_record_dataset.sh` | Leader→follower teleop; record demos via `lerobot-record` |
| 3 | `3_train_policy.sh` | Train a policy with `lerobot-train` (`torchrun` multi-GPU) |
| 4 | `4_eval_policy.sh` | Deploy a checkpoint and record eval episodes (model path is required `$1`) |

The record/teleop/eval scripts auto-invoke `1_setup.sh` if the CAN interface is
missing. Run a stage directly, e.g. `bash scripts/single/2_record_dataset.sh`.

`task.sh` wraps a stage script for **Slurm** (`srun bash <task_file>`); useful for
queued training on a cluster.

### config.env conventions

- **CAN interfaces** are identified by physical USB bus-info (`1-12:1.0`, etc.) in
  the `USB_PORTS` associative array and renamed to logical names (`can_leader`,
  `can_follower`; bimanual uses `can_l_*`/`can_r_*`). Get bus-info with
  `sudo ethtool -i <iface>`.
- **Cameras** are Intel RealSense, keyed by **serial number** in the `CAMERAS`
  array. The key becomes the dataset feature name (e.g. `observation.images.top_cam`).
  Empty the `CAMERAS` array to disable cameras. See `docs/cam_bind.md` for binding
  RealSense devices to stable `/dev` symlinks via udev rules.
- `POLICY`, `ROBOT`, `REPO_USER`, and `LOCAL_DATASET_DIR`/`LOCAL_MODEL_DIR` drive
  generated dataset/model names. The full policy list is enumerated in the comment
  block at the bottom of `config.env` (act, diffusion, pi0, smolvla, wall_x, …).

> Note: several scripts contain hardcoded `/home/junxi/...` paths and dataset names
> (e.g. `DATASET_NAME="pig_rgy"` hardcoded in `2_record_dataset.sh`/`3_train_policy.sh`
> overriding config values). Treat these as per-run edits, not stable config — check
> before reusing on another machine.

## HuggingFace Hub

Datasets and models push to the Hub under `$REPO_USER` (`jolch`). Toggle with
`DATASET_PUSH_TO_HUB` / `MODEL_PUSH_TO_HUB` in the scripts. Common ops (`hf upload`,
`hf upload-large-folder`, `lerobot-dataset-viz`) and exact invocations are in the
README and `docs/huggingface.md`.

## Gotchas

- Training uses `--dataset.video_backend=pyav` because ffmpeg is unavailable in the
  target environment.
- `--wandb.enable=true` requires `wandb login` beforehand.
- `wall_x` policy needs `flash_attention_2` and `bfloat16` (see `3_train_policy.sh`).
- `datasets/`, `dataset/`, `outputs/`, `wandb/` are gitignored — generated artifacts.
</content>
</invoke>
