# =============================================================================
#                               BASE Stage
#
# Extends the shared ROS 2 runtime base image and prepares the workspace used
# to build the robot actuation stack. Only package manifests are copied in
# order to resolve and install system dependencies via rosdep.
#
# No packages are built here, it only establishes the /ros2_ws workspace
# layout used during compilation.
# =============================================================================

FROM micipsa/base:foundation AS base

USER root

WORKDIR /ros2_ws
RUN mkdir -p src/micipsa/micipsa_robot/micipsa_bringup/launch src/micipsa/micipsa_robot/micipsa_bringup/config

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
COPY --from=micipsa micipsa_robot/micipsa_bringup/package.xml src/micipsa/micipsa_robot/micipsa_bringup/package.xml
COPY --from=micipsa micipsa_robot/micipsa_control/package.xml src/micipsa/micipsa_robot/micipsa_control/package.xml
COPY --from=micipsa micipsa_robot/micipsa_core/package.xml src/micipsa/micipsa_robot/micipsa_core/package.xml
COPY --from=micipsa micipsa_robot/micipsa_hardware/package.xml src/micipsa/micipsa_robot/micipsa_hardware/package.xml
COPY --from=micipsa micipsa_robot/micipsa_common/package.xml src/micipsa/micipsa_robot/micipsa_common/package.xml
COPY --from=micipsa third_party/ros/serial/package.xml  src/micipsa/third_party/ros/serial/package.xml 

RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y \
    --dependency-types build && \
    rm -rf /var/lib/apt/lists/*

# =============================================================================
#                               BUILD Stage
#
# Builds the ROS 2 workspace required for the robot actuation subsystem.
# Source code is copied in and the following packages are compiled:
#
#   • micipsa_control   (ros2_control controllers and configuration)
#   • micipsa_core      (core robot logic)
#   • micipsa_hardware  (hardware interface)
#   • micipsa_bringup   (actuation launch files)
#   • micipsa_common    (shared utilities used by launch scripts)
#   • serial            (serial communication library)
#
# The resulting workspace is installed into /ros2_ws/install and copied
# into the runtime image.
# =============================================================================

FROM base AS build

# -------------------------------
# Micipsa Bringup Actuation Files
# -------------------------------
COPY --from=micipsa micipsa_robot/micipsa_bringup/CMakeLists.txt src/micipsa/micipsa_robot/micipsa_bringup/CMakeLists.txt
COPY --from=micipsa micipsa_robot/micipsa_bringup/launch/actuation src/micipsa/micipsa_robot/micipsa_bringup/launch/actuation

# ------------------------------
# Micipsa ROS2 Required Packages
# ------------------------------
COPY --from=micipsa micipsa_robot/micipsa_control src/micipsa/micipsa_robot/micipsa_control
COPY --from=micipsa micipsa_robot/micipsa_core src/micipsa/micipsa_robot/micipsa_core
COPY --from=micipsa micipsa_robot/micipsa_hardware src/micipsa/micipsa_robot/micipsa_hardware
COPY --from=micipsa micipsa_robot/micipsa_common src/micipsa/micipsa_robot/micipsa_common
COPY --from=micipsa third_party/ros/serial src/micipsa/third_party/ros/serial

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
    ros-${ROS_DISTRO}-ros2controlcli \
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
# Produces the final runtime container responsible for running the robot
# actuation stack. Only compiled executables and install artifacts are
# retrieved from the build stage, no source code is included.
#
# The image contains:
#   • The compiled ROS 2 workspace from the build stage
#   • ros2_control runtime components and controllers
# =============================================================================
FROM micipsa/base:foundation AS deploy

USER root

# ----------------------
# ROS2 install artifacts
# ----------------------
COPY --from=build /ros2_ws/install /ros2_ws/install

# -------------------------------
# ROS2 Packages Needed At Runtime
# -------------------------------
COPY --from=micipsa micipsa_robot/micipsa_bringup/package.xml /tmp/deps/micipsa_bringup/package.xml
COPY --from=micipsa micipsa_robot/micipsa_control/package.xml /tmp/deps/micipsa_control/package.xml
COPY --from=micipsa micipsa_robot/micipsa_core/package.xml /tmp/deps/micipsa_core/package.xml
COPY --from=micipsa micipsa_robot/micipsa_hardware/package.xml /tmp/deps/micipsa_hardware/package.xml
COPY --from=micipsa micipsa_robot/micipsa_common/package.xml /tmp/deps/micipsa_common/package.xml
COPY --from=micipsa third_party/ros/serial/package.xml  /tmp/deps/third_party/ros/serial/package.xml

RUN apt-get update && \
    rosdep install --from-paths /tmp/deps --ignore-src -r -y \
    --dependency-types exec && \
    rm -rf /var/lib/apt/lists/* /tmp/deps

# ---------------
# Deleting Rosdep
# ---------------
RUN apt-get purge -y python3-rosdep python3-rosdep-modules \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 docker/actuation/entrypoint.sh /entrypoint.sh
USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]