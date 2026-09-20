from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

# =========================================================================
#                          ENV DATA STRUCTURE
# =========================================================================
@dataclass
class EnvGroups:
    """Environment variables grouped by origin for display and .env writing."""

    bringup: dict[str, str]
    devices: dict[str, str]
    compose: dict[str, str]

    def merged(self) -> dict[str, str]:
        return {**self.bringup, **self.devices, **self.compose}


# =========================================================================
#                           COMPOSE ENV VARIABLES
# =========================================================================
def compose_env_vars(
    bringup_config_dir: Path, maps_dir: Path, dds_dir: Path, settings: dict,
    devices_data: dict,
    bringup_config_install_dir: Path, maps_install_dir: Path, dds_install_dir: Path,
) -> EnvGroups:

    # Bringup Data
    bringup_env = {
        f"MICIPSA_{key.upper()}": normalize_value(value)
        for key, value in settings.items()
    }

    # Devices Data
    devices_env = build_devices_env_vars(devices_data)

    # Compose Data
    compose_env = {
        "BRINGUP_CONFIG_SRC": str(bringup_config_dir),
        "BRINGUP_CONFIG_INSTALL_DIR": str(bringup_config_install_dir),
        "MAPS_SOURCE_DIR": str(maps_dir),
        "MAPS_INSTALL_DIR": str(maps_install_dir),
        "DDS_SOURCE_DIR": str(dds_dir),
        "DDS_INSTALL_DIR": str(dds_install_dir),
    }

    return EnvGroups(bringup=bringup_env, devices=devices_env, compose=compose_env)

# =========================================================================
#                           HELPERS
# =========================================================================
def normalize_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def flatten_device_params(prefix: str, value: Any, env: dict[str, str]) -> None:
    """
    Recursively walk a device parameter and write one env var per scalar leaf.
    The prefix grows with each level of nesting, mirroring the YAML key path:

      scalar -> write  prefix = value
      dict   -> recurse with  prefix_KEY  for each key
      list   -> recurse with  prefix_0, prefix_1, ...  for each item

    Examples with prefix = MICIPSA_FRONT_CAMERA:
      port: /dev/stm          ->  MICIPSA_FRONT_CAMERA_PORT = /dev/stm
      ports:
        depth:
          - /dev/depth0       ->  MICIPSA_FRONT_CAMERA_PORTS_DEPTH_0 = /dev/depth0
          - /dev/depth1       ->  MICIPSA_FRONT_CAMERA_PORTS_DEPTH_1 = /dev/depth1
    """
    if isinstance(value, dict):
        for k, v in value.items():
            flatten_device_params(f"{prefix}_{k.upper()}", v, env)
    elif isinstance(value, list):
        for i, item in enumerate(value):
            flatten_device_params(f"{prefix}_{i}", item, env)
    else:
        env[prefix] = normalize_value(value)


def build_devices_env_vars(devices_data: dict) -> dict[str, str]:
    """
    Iterates over every device in the data and delegates param flattening to
    flatten_device_params. The category level (mcu, lidars, cameras, ...) is
    skipped, only the device name and its params contribute to the var name:

      devices.mcu.stm_board.port       ->  MICIPSA_STM_BOARD_PORT
      devices.lidars.base_lidar.port   ->  MICIPSA_BASE_LIDAR_PORT
      devices.cameras.front_camera.ports.depth[0]
                                       ->  MICIPSA_FRONT_CAMERA_PORTS_DEPTH_0
    """
    env: dict[str, str] = {}

    for category_devices in devices_data.get("devices", {}).values():
        if not isinstance(category_devices, dict):
            continue
        for device_name, params in category_devices.items():
            if not isinstance(params, dict):
                continue
            prefix = f"MICIPSA_{device_name.upper()}"
            for param_key, param_value in params.items():
                flatten_device_params(f"{prefix}_{param_key.upper()}", param_value, env)

    return env