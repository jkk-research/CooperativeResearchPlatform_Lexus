# CRP Lexus RX450h

Vehicle integration of the [Cooperative Research Platform](https://github.com/jkk-research/CooperativeResearchPlatform) (CRP) for the Lexus RX450h research vehicle (`lexus3`). The vehicle-independent core (planning and control started by `apl_launcher`, sensor abstraction and fusion started by `sil_launcher`, `crp_msgs`) lives in [jkk-research/CooperativeResearchPlatform](https://github.com/jkk-research/CooperativeResearchPlatform). This repository adds the Lexus drivers, wrappers, launch files and recording scripts; both are built in one colcon workspace.

## Prerequisites

- Ubuntu 22.04, ROS 2 Humble, colcon, rosdep (`sudo rosdep init && rosdep update`) and vcstool (`sudo apt install python3-vcstool`).
- SSH access to GitHub: most submodules use `git@github.com:` URLs and some of the jkk-research ones are private.
- Not installed by rosdep:
  - PACMod3, from the AutonomouStuff apt repository:
    ```bash
    sudo sh -c 'echo "deb [trusted=yes] https://s3.amazonaws.com/autonomoustuff-repo/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/autonomoustuff-public.list'
    sudo apt update && sudo apt install ros-humble-pacmod3
    ```
  - Kvaser CANlib and linuxcan for `kvaser_interface`, from the AutonomouStuff PPA:
    ```bash
    sudo apt-add-repository ppa:astuff/kvaser-linux
    sudo apt update && sudo apt install kvaser-canlib-dev kvaser-drivers-dkms
    ```
  - Only for `lexus_centerpoint.launch.py`: the `lidar_centerpoint_detector` ROS package (it provides `docker_run.launch.py`), Docker, and pull access to `ghcr.io/jkk-research/lidar_centerpoint_detector` (`docker login ghcr.io`).

The other dependencies declared by the packages, including the Autoware message packages and `autoware_lanelet2_extension`, are installed from the ROS apt repository by rosdep, which the build scripts run.

## Workspace

Both repositories sit side by side in one colcon `src/`; `lexus.repos` pins the matching core commit (`b493491`).

```bash
mkdir -p ~/crp_ws/src && cd ~/crp_ws/src
git clone --recursive https://github.com/jkk-research/CooperativeResearchPlatform_Lexus.git
vcs import --recursive < CooperativeResearchPlatform_Lexus/lexus.repos
```

```
crp_ws/src/
├── CooperativeResearchPlatform/        # core, imported with lexus.repos
└── CooperativeResearchPlatform_Lexus/  # this repository
```

## Build

```bash
source /opt/ros/humble/setup.bash
~/crp_ws/src/CooperativeResearchPlatform_Lexus/scripts/build_lexus.sh   # extra arguments go to colcon build, e.g. --symlink-install
```

`build_lexus.sh` finds the workspace root, runs the core's `scripts/build_APL.sh` and `scripts/build_SIL.sh` with the same arguments, then installs the dependencies of the Lexus packages with rosdep and builds them with `colcon build --packages-select`.

## Launch

```bash
source ~/crp_ws/install/setup.bash
ros2 launch lexus_launcher lexus.launch.py
ros2 launch lexus_launcher lexus_centerpoint.launch.py   # lexus.launch.py + centerpoint radar curve detector (Docker)
```

`lexus.launch.py` includes the core's `apl_launcher/apl.launch.py` and `sil_launcher/sil.launch.py` and starts the vehicle side: static TFs, the center lidar and the vehicle CAN and status from `lexus_bringup`, the NovAtel OEM7 driver with `novatel_gps_wrapper` (`select_gps:=nova`, the default), the five radars (`fc`, `fl`, `fr`, `rl`, `rr` on `can8`, `can6`, `can7`, `can4`, `can5`) with doppler compensation and aggregation, the radar point cloud merger and `pacmod_extender`. Vehicle parameters come from `config/vehicle/lexusParams.yaml`, radar settings from `config/radar/`.

`lexus_centerpoint.launch.py` reads `/sensing/radar/fc/aggregated_points` by default; choose the model with `centerpoint/model:=v3_distnms|v4_hungarian|v3_curvy`.

## Layout

| Package path | Purpose |
|---|---|
| `launch/lexus_launcher` | The launch files above, Lexus vehicle parameters and radar configs |
| `crp_VIL/pacmod_extender` | Extra PACMod3 CAN decoding; publishes `/sensing/vehicle/{twist,accel,tire_angle,steering_wheel_rate,blinker}` for the core sensor abstraction |
| `crp_CIL/novatel_gps_wrapper` | Converts the NovAtel OEM7 output to `/sensing/gnss/*` and `/odometry/kinematic_state/odometry` |
| `crp_CIL/radar_pointcloud_preprocessor` | Radar point cloud doppler compensation, aggregation and merging |
| `crp_VIL/actuator_control` | Turns `/control/command/control_cmd` into PACMod3 accelerator, brake and steering commands (PID speed control); not launched |
| `crp_VIL/ekf_wrapper` | Starts `kalman_pos` and republishes its pose as `/sensing/ekf/estimated_pose`; not launched |
| `crp_VIL/lanelet_handler` | Loads a Lanelet2 `.osm` map, publishes it and its visualization; not launched |
| `external/map_loader` | Lanelet2 map visualization trimmed from Autoware's `map_loader`, used by `lanelet_handler`; not launched |
| `crp_VIL/scenario_generator` | Publishes a straight test path as `/scenario`; not launched |
| `crp_CIL/duro_gps_wrapper` | Starts `duro_gps_driver` and republishes its pose as `/sensing/gnss/pose_with_covariance`; not launched |

| Submodule | Upstream | Purpose |
|---|---|---|
| `crp_VIL/lexus_bringup` | jkk-research/lexus_bringup | Lexus launch files used by `lexus.launch.py`: `tf_static.launch.py`, `drivers/lidar_os_center.launch.py`, `drivers/can_and_status.launch.py` |
| `crp_VIL/kvaser_interface` | astuff/kvaser_interface | Kvaser CAN interface |
| `crp_VIL/novatel_oem7_driver` | jkk-research/novatel_oem7_driver | NovAtel OEM7 GNSS/INS driver |
| `crp_VIL/ouster_ros` | jkk-research/ouster-ros | Ouster lidar driver |
| `crp_VIL/radar_driver` | jkk-research/radar_driver | Radar driver (`rd6_driver`) |
| `crp_VIL/duro_gps_driver` | szenergy/duro_gps_driver | Duro GNSS driver; not launched |
| `crp_VIL/mpc_camera_driver` | jkk-research/mpc_cam_driver | MPC camera driver; not launched |
| `crp_CIL/kalman_pos` | jkk-research/kalman_pos | EKF localization used by `ekf_wrapper`; not launched |

`scripts/` holds `build_lexus.sh` and the recording and radar scripts below.

## Recording

Paths are relative to this repository:

```bash
source scripts/setup_recording.sh      # once: asks for the bag folder, exports crp_bag_folder and saves it in ~/.bashrc
scripts/record_all.sh <name>           # all topics except the CAN topics listed in config/can_topics.txt
scripts/record_core.sh <name>          # only the topics in config/core_topics.txt
scripts/record_cai.sh <name>           # only the /cai/* topics in config/cai_topics.txt
scripts/record_lightweight.sh <name>   # like record_all.sh, also excluding config/camera_topics.txt and config/lidar_topics.txt (both empty for now)
scripts/config_radar.sh                # calls the sendConfig service of all five radars
```

Bags are recorded with `ros2 bag record` as MCAP (Zstd compression, `config/mcap_writer_options.yaml`) to `$crp_bag_folder/<date>_crp/<name>_<timestamp>`. `record_all.sh` also takes `-t <topics...>` (record only these), `-x <topics...>` (exclude more) and `-p <path>` (write to `<path>_<timestamp>` instead).

## Notes

- **PDP is removed.** `lexus.launch.py` no longer includes `pdp_wrapper`, and `actuator_control` no longer subscribes to `/PdpPersonalizedParamsActive`; its acceleration and deceleration limits follow the `/ui/behavior` modes only.
- **Built but not launched.** `build_lexus.sh` builds `duro_gps_driver` and `duro_gps_wrapper`, `mpc_camera_driver`, `kalman_pos` and `ekf_wrapper`, `actuator_control`, `lanelet_handler` and `map_loader`, and `scenario_generator`, but `lexus.launch.py` does not start them. They are kept as-is apart from the PDP removal in `actuator_control`, the unused `tier4_map_msgs` dependency dropped from `map_loader`, the `autoware_internal_planning_msgs` port of `scenario_generator` and a few missing dependency declarations; `lexus.launch.py` still defines the `ekf_*` and `map_*` arguments and an `actuator_control` include but does not add them to its `LaunchDescription`.
- **`map_hash_generator`**, installed by `map_loader`, imports `tier4_external_api_msgs` at runtime. That package is not a declared dependency; provide it yourself before using the script.
- **The core sensor abstraction has fixed inputs.** `prcp_sensor_abstraction`, started by `sil.launch.py`, reads twist and accel from `/sensing/vehicle/twist` and `/sensing/vehicle/accel` (published by `pacmod_extender`), the tire angle from `/sensing/vehicle/tire_angle` and the pose from `/sensing/gnss/pose_with_covariance`, and builds a 75 m local path. The `lexus.launch.py` arguments `kinematic_state_source`, `twist_topic`, `accel_topic`, `localization_source`, `vehicle_tire_angle_topic` and `local_path_length` no longer configure it: `accel_topic`, `localization_source`, `vehicle_tire_angle_topic` and `local_path_length` are unused, and `twist_topic` (by default `/sensing/<kinematic_state_source>/twist`, i.e. `/sensing/gnss/twist`) only feeds the radar doppler compensation and aggregation.
