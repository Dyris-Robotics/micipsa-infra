# =============================================================================
#                               BASE Stage
#
# Minimal shared ROS 2 runtime image.
# Subsystem runtime images inherit from this.
# =============================================================================

ARG ROS_DISTRO=jazzy
ARG BASE_IMAGE=ubuntu:24.04

FROM ${BASE_IMAGE} AS base

ARG ROS_DISTRO
ENV ROS_DISTRO=${ROS_DISTRO}

ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=micipsa
ENV USER_UID=1000
ENV USER_GID=${USER_UID}
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ------------
# ROS2 Install
# ------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    software-properties-common \
    curl \
    ca-certificates \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && add-apt-repository universe \
    && export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F'"' '{print $4}') \
    && curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" \
    && dpkg -i /tmp/ros2-apt-source.deb \
    && rm -f /tmp/ros2-apt-source.deb \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-ros-base \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    python3-rosdep \
    && rosdep init \
    && rosdep update \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user with UID/GID 1000.
# The default 'ubuntu' user in Ubuntu 24.04 base images already occupies UID/GID 1000,
# so we remove it first. The || true prevents failure if it doesn't exist in future images.
RUN (userdel -r ubuntu || true) \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd -s /bin/bash --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
    && mkdir /home/${USERNAME}/.config \
    && chown ${USER_UID}:${USER_GID} /home/${USERNAME}/.config

COPY --chmod=755 docker/base/entrypoint.sh /entrypoint.sh
USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]