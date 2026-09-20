# =============================================================================
#                               BASE Stage
#
# Extends the shared ROS 2 runtime base image and prepares the workspace used
# to build the simulation stack. Package manifests are copied in to resolve
# and install system dependencies via rosdep. Gazebo is installed here so it
# is cached independently of the compiled workspace.
#
# No packages are built here, it only establishes the /ros2_ws workspace
# layout used during compilation.
# =============================================================================
FROM micipsa/base:foundation AS base

USER root

WORKDIR /ros2_ws
RUN mkdir -p src/micipsa/micipsa_robot/micipsa_bringup/launch

# ------------------
# Micipsa Build Deps
# ------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    python3-colcon-common-extensions \
    && rm -rf /var/lib/apt/lists/*

# ----------------------
# Micipsa Rosdep Install
# ----------------------
COPY --from=micipsa micipsa_robot/micipsa_bringup/package.xml   src/micipsa/micipsa_robot/micipsa_bringup/package.xml
COPY --from=micipsa micipsa_robot/micipsa_simulation/package.xml src/micipsa/micipsa_robot/micipsa_simulation/package.xml
COPY --from=micipsa micipsa_robot/micipsa_common/package.xml    src/micipsa/micipsa_robot/micipsa_common/package.xml

RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y && \
    apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-ros-gz \
    ros-${ROS_DISTRO}-ros2-control \
    ros-${ROS_DISTRO}-ros2-controllers \
    ros-${ROS_DISTRO}-joint-state-broadcaster \
    ros-${ROS_DISTRO}-diff-drive-controller \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
#                               BUILD Stage
#
# Builds the ROS 2 workspace required for the simulation subsystem.
# Source code is copied in and the following packages are compiled:
#
#   • micipsa_simulation   (Gazebo world, models and simulation launch files)
#   • micipsa_bringup      (simulation launch files)
#   • micipsa_common       (shared utilities used by launch scripts)
#
# The resulting workspace is installed into /ros2_ws/install and copied
# into the runtime image.
# =============================================================================
FROM base AS build

# --------------------------------
# Micipsa Bringup Simulation Files
# --------------------------------
COPY --from=micipsa micipsa_robot/micipsa_bringup/CMakeLists.txt         src/micipsa/micipsa_robot/micipsa_bringup/CMakeLists.txt
COPY --from=micipsa micipsa_robot/micipsa_bringup/launch/simulation      src/micipsa/micipsa_robot/micipsa_bringup/launch/simulation

# ensure config directory exists for CMake install rule
RUN mkdir -p src/micipsa/micipsa_robot/micipsa_bringup/config

# ------------------------------
# Micipsa ROS2 Required Packages
# ------------------------------
COPY --from=micipsa micipsa_robot/micipsa_simulation src/micipsa/micipsa_robot/micipsa_simulation
COPY --from=micipsa micipsa_robot/micipsa_common     src/micipsa/micipsa_robot/micipsa_common
COPY --from=micipsa micipsa_robot/micipsa_control src/micipsa/micipsa_robot/micipsa_control

# ----------------------------
# Micipsa Utils Required files
# ----------------------------
COPY --from=micipsa utils/__init__.py  src/micipsa/utils/__init__.py

COPY --from=micipsa utils/console/__init__.py  src/micipsa/utils/console/__init__.py
COPY --from=micipsa utils/console/console_utils.py  src/micipsa/utils/console/console_utils.py

COPY --from=micipsa utils/filesystem/__init__.py  src/micipsa/utils/filesystem/__init__.py
COPY --from=micipsa utils/filesystem/file_utils.py  src/micipsa/utils/filesystem/file_utils.py

COPY --from=micipsa utils/conversions/__init__.py  src/micipsa/utils/conversions/__init__.py
COPY --from=micipsa utils/conversions/data_conversion_utils.py  src/micipsa/utils/conversions/data_conversion_utils.py

# -------------------
# Build ROS2 packages
# -------------------
RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    colcon build \
    --install-base /ros2_ws/install

# =============================================================================
#                               DEV Stage
#
# Development container for iterating on the robot actuation stack locally.
# Extends the build stage so all compiled artifacts, build tools, and
# dependencies are available out of the box.
#
# Source code is NOT baked in, mount your local workspace at /ros2_ws
# so that changes are reflected without rebuilding the image:
#
# The image contains:
#   • All build and exec dependencies inherited from the base and build stages
# =============================================================================
FROM base AS dev

# ---------------
# Debugging Tools
# ---------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    gdb \
    vim \
    iputils-ping \
    iproute2 \
    net-tools \
    htop \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# -----------------
# Exec Deps Install
# -----------------
RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y \
    --dependency-types exec && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------
# Passwordless sudo to the dev user
# ---------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
    && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 docker/actuation/entrypoint.sh /entrypoint.sh
USER ${USERNAME}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

# =============================================================================
#                               DEPLOY Stage
#
# Produces the final runtime container responsible for running the simulation.
# Only compiled executables and install artifacts are retrieved from the build
# stage — no source code is included.
#
# The image contains:
#   • The compiled ROS 2 workspace from the build stage
#   • Gazebo and ros-gz, installed in the base stage and inherited here
# =============================================================================
FROM base AS deploy

USER root

# ----------------------
# ROS2 install artifacts
# ----------------------
COPY --from=build /ros2_ws/install /ros2_ws/install

# ----------------------------
# Micipsa Meshes Required files
# ----------------------------
COPY --from=micipsa micipsa_robot/micipsa_description/urdf/meshes /gz_models/micipsa_description/urdf/meshes
ENV GZ_SIM_RESOURCE_PATH=/gz_models

# ---------------
# Deleting Rosdep
# ---------------
RUN apt-get purge -y python3-rosdep python3-rosdep-modules \
    && rm -rf /var/lib/apt/lists/*


COPY --chmod=755 docker/simulation/entrypoint.sh /entrypoint.sh
USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]