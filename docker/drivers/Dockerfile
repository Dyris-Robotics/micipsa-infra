# =============================================================================
#                               BASE Stage
#
# Prepares the common build environment for the drivers workspace.
#
# This stage:
#   • Starts from the shared ROS 2 base runtime image
#   • Creates the /ros2_ws workspace layout
#   • Installs system packages and ROS dependencies needed for compilation
#   • Resolves package dependencies with rosdep using package.xml files only
#
# No source code is compiled here. Keeping this stage limited to stable
# dependency setup improves Docker layer caching across source changes.
# =============================================================================

ARG YDLIDAR_REF=V1.2.7
ARG LIBREALSENSE_REF=v2.58.4

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
    git \
    python3-colcon-common-extensions \
    && rm -rf /var/lib/apt/lists/*

# --------------
# Realsense Deps
# --------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    v4l-utils \
    libssl-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    pkg-config \
    libgtk-3-dev \
    wget \
    cmake \
    build-essential \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    at \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------
# Realsense ROS2 Package Deps
# ---------------------------
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_camera/package.xml src/micipsa/third_party/ros/realsense2_camera/package.xml
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_camera_msgs/package.xml src/micipsa/third_party/ros/realsense2_camera_msgs/package.xml
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_description/package.xml src/micipsa/third_party/ros/realsense2_description/package.xml
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_rgbd_plugin/package.xml src/micipsa/third_party/ros/realsense2_rgbd_plugin/package.xml

# -------------------------
# Ydlidar ROS2 Package Deps
# -------------------------
COPY --from=micipsa third_party/ros/ydlidar_ros2_driver/package.xml src/micipsa/third_party/ros/ydlidar_ros2_driver/package.xml

# ----------------------
# Micipsa Rosdep Install
# ----------------------
COPY --from=micipsa micipsa_robot/micipsa_bringup/package.xml src/micipsa/micipsa_robot/micipsa_bringup/package.xml
COPY --from=micipsa micipsa_robot/micipsa_common/package.xml src/micipsa/micipsa_robot/micipsa_common/package.xml

# Realsense lib is built from source, so skipping rosdep install to not create conflict
RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y \
    --dependency-types build \
    --skip-keys "librealsense2" && \
    rm -rf /var/lib/apt/lists/*

# =============================================================================
#                               BUILD Stage
#
# Builds the complete drivers workspace and required third-party SDKs.
#
# This stage:
#   • Builds the Intel RealSense SDK
#   • Builds the YDLidar SDK
#   • Copies the ROS 2 driver packages and bringup resources
#   • Compiles the ROS 2 workspace with colcon
#
# The resulting install tree is generated under /ros2_ws/install and is later
# copied into the runtime image.
# =============================================================================

FROM base AS build

ARG YDLIDAR_REF
ARG LIBREALSENSE_REF

# -------------------
# Build RealSense SDK
# -------------------
RUN git clone --depth 1 --branch ${LIBREALSENSE_REF} https://github.com/realsenseai/librealsense /tmp/librealsense \
    && cd /tmp/librealsense \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && if [ "$(nproc)" -gt 2 ]; then make -j$(($(nproc)-2)); else make; fi \
    && make install \
    && rm -rf /tmp/librealsense

# -----------------
# Build YDLidar SDK
# -----------------
RUN git clone --depth 1 --branch ${YDLIDAR_REF} https://github.com/YDLIDAR/YDLidar-SDK.git /tmp/YDLidar-SDK \
    && cd /tmp/YDLidar-SDK \
    && mkdir build && cd build \
    && cmake .. \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/YDLidar-SDK

# -----------------------------
# Micipsa Bringup Drivers Files
# -----------------------------
COPY --from=micipsa micipsa_robot/micipsa_bringup/CMakeLists.txt src/micipsa/micipsa_robot/micipsa_bringup/CMakeLists.txt
COPY --from=micipsa micipsa_robot/micipsa_bringup/launch/drivers src/micipsa/micipsa_robot/micipsa_bringup/launch/drivers
COPY --from=micipsa micipsa_robot/micipsa_bringup/config/drivers src/micipsa/micipsa_robot/micipsa_bringup/config/drivers

# -----------------------------
# Micipsa Bringup Hardware Files
# ------------------------------
COPY --from=micipsa micipsa_robot/micipsa_bringup/config/hardware src/micipsa/micipsa_robot/micipsa_bringup/config/hardware

# -------------------------
# Copy ROS2 driver packages
# -------------------------
COPY --from=micipsa third_party/ros/ydlidar_ros2_driver src/micipsa/third_party/ros/ydlidar_ros2_driver
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_camera src/micipsa/third_party/ros/realsense2_camera
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_camera_msgs src/micipsa/third_party/ros/realsense2_camera_msgs
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_description src/micipsa/third_party/ros/realsense2_description
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_rgbd_plugin src/micipsa/third_party/ros/realsense2_rgbd_plugin

# ------------------------------
# Micipsa ROS2 Required Packages
# ------------------------------
COPY --from=micipsa micipsa_robot/micipsa_common src/micipsa/micipsa_robot/micipsa_common

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
# Build ROS2 Packages
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
FROM build AS dev

# ---------------
# Clean workspace
# ---------------
RUN rm -rf /ros2_ws/src /ros2_ws/build /ros2_ws/install /ros2_ws/log

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
    apt-get install -y ros-${ROS_DISTRO}-image-transport && \
    apt-get install -y ros-${ROS_DISTRO}-compressed-image-transport && \
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
# Produces the final runtime image used to launch the robot drivers.
#
# This stage contains only the runtime artifacts required on the robot:
#   • The installed ROS 2 workspace from the build stage
#   • Runtime libraries from the third-party hardware SDKs
#   • Minimal OS and ROS packages required for device access and execution
# =============================================================================
FROM micipsa/base:foundation AS deploy

USER root

# ------------------------------
# ROS2 drivers install artifacts
# ------------------------------
COPY --from=build /ros2_ws/install /ros2_ws/install

# -----------------------------------------------------
# Copy installed SDK runtime libraries from build stage
# -----------------------------------------------------
COPY --from=build /usr/local/lib/ /usr/local/lib/

# ----------------------------------------------------------
# Update dynamic linker cache so the new libraries are found
# ----------------------------------------------------------
RUN ldconfig

# -------------------------------
# ROS2 Packages Needed At Runtime
# -------------------------------
# ---------------------------
# Realsense ROS2 Package Deps
# ---------------------------
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_camera/package.xml /tmp/deps/third_party/ros/realsense2_camera/package.xml
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_camera_msgs/package.xml /tmp/deps/third_party/ros/realsense2_camera_msgs/package.xml
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_description/package.xml /tmp/deps/third_party/ros/realsense2_description/package.xml
COPY --from=micipsa third_party/ros/realsense-ros/realsense2_rgbd_plugin/package.xml /tmp/deps/third_party/ros/realsense2_rgbd_plugin/package.xml

# --------------------------
# Micipsa ROS2 Package Deps
# --------------------------
COPY --from=micipsa micipsa_robot/micipsa_bringup/package.xml /tmp/deps/micipsa_bringup/package.xml
COPY --from=micipsa micipsa_robot/micipsa_common/package.xml /tmp/deps/micipsa_common/package.xml
COPY --from=micipsa third_party/ros/ydlidar_ros2_driver/package.xml /tmp/deps/third_party/ros/ydlidar_ros2_driver/package.xml

RUN apt-get update && \
    apt-get install -y ros-${ROS_DISTRO}-image-transport && \
    apt-get install -y ros-${ROS_DISTRO}-compressed-image-transport && \
    rosdep install --from-paths /tmp/deps --ignore-src -r -y \
    --dependency-types exec \
    --skip-keys "rviz-common rviz-rendering rviz-default-plugins rviz2 librealsense2" && \
    rm -rf /var/lib/apt/lists/* /tmp/deps

# ---------------
# Deleting Rosdep
# ---------------
RUN apt-get purge -y python3-rosdep python3-rosdep-modules \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 docker/drivers/entrypoint.sh /entrypoint.sh
USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]