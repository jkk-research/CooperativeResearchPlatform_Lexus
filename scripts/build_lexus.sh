#!/usr/bin/env bash

script_dir=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
cd $script_dir
while [ ! -e "src/" ]; do
  cd ../
done
echo "Build location: "$(pwd)

build_args=$@

# locate the core repository, imported into src/ with lexus.repos
core_build_apl=$(find -L src -path '*/scripts/build_APL.sh' -print -quit)
core_scripts_dir=$(dirname "$core_build_apl")
if [ -z "$core_build_apl" ] || [ ! -f "$core_scripts_dir/build_SIL.sh" ]
then
printf "\n! Core repository not found: no scripts/build_APL.sh and scripts/build_SIL.sh under %s !\n" "$(pwd)/src"
printf "! Import it with: vcs import --recursive %s < %s !\n\n" "$(pwd)/src" "$(dirname "$script_dir")/lexus.repos"
exit 1
fi

# build core
trap 'exit' INT # trap ctrl-c
"$core_scripts_dir/build_APL.sh" $build_args && "$core_scripts_dir/build_SIL.sh" $build_args
if [ $? == 0 ]
then printf "\n! Core build success !\n\n"
else
printf "\n! Core build failed !\n\n"
exit 1
fi
trap - INT

# build lexus packages
packages=(
  map_loader
  duro_gps_driver
  duro_gps_wrapper
  kvaser_interface
  lanelet_handler
  lexus_bringup
  actuator_control
  mpc_camera_driver
  novatel_oem7_msgs
  novatel_oem7_driver
  novatel_gps_wrapper
  pacmod_extender
  kalman_pos
  ekf_wrapper
  ouster_sensor_msgs
  ouster_ros
  scenario_generator
  rd6_msgs
  rd6_driver
  radar_pointcloud_preprocessor
  lexus_launcher
)

packages_string=${packages[*]}

packages_paths=$(colcon list --packages-select $packages_string -p)

rosdep install --from-paths $packages_paths --ignore-src -r -y

colcon build --packages-select $packages_string $build_args
