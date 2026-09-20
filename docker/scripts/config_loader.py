from __future__ import annotations

from utils.filesystem.file_utils import get_yaml_config_data, get_file_path

# =========================================================================
#                       BRINGUP CONFIG LOADER
# =========================================================================
def load_bringup_config(
    bringup_config_dir: str, config_name: str, config_subdir: str
) -> tuple[dict, str]:
    bringup_config = get_yaml_config_data(
        bringup_config_dir, config_name, config_subdir
    )
    bringup_config_path = get_file_path(bringup_config_dir, config_name, config_subdir)

    settings = bringup_config.get("settings") or {}
    if not isinstance(settings, dict):
        raise ValueError(f"'settings' must be a mapping, got {type(settings).__name__}")

    return settings, bringup_config_path

# =========================================================================
#                  HARDWARE DEVICES CONFIG LOADER
# =========================================================================
def load_devices_config(
    bringup_config_dir: str, config_name: str, config_subdir: str
) -> dict:
    return get_yaml_config_data(bringup_config_dir, config_name, config_subdir)

# =========================================================================
#                      MODE FLAGS RESOLVER
# =========================================================================
def resolve_mode_flags(settings: dict, mode: str) -> tuple[dict, list[str]]:
    """
    Override deploy_mode/use_sim_time for this compose-launcher run based on
    --mode. This does NOT touch the on-disk YAML.
    """
    if mode not in ("sim", "deploy"):
        raise ValueError(f"Unsupported mode: {mode}, options: deploy | sim")

    resolved = dict(settings)
    derived_deploy_mode = mode == "deploy"
    derived_use_sim_time = mode == "sim"

    yaml_deploy_mode = settings.get("deploy_mode")
    yaml_use_sim_time = settings.get("use_sim_time")

    warnings: list[str] = []

    if yaml_deploy_mode is not None and bool(yaml_deploy_mode) != derived_deploy_mode:
        warnings.append(
            f"YAML has deploy_mode={yaml_deploy_mode}, but compose launcher --mode={mode} implies that "
            f"deploy_mode={derived_deploy_mode}. Using deploy_mode={derived_deploy_mode}"
        )
    if yaml_use_sim_time is not None and bool(yaml_use_sim_time) != derived_use_sim_time:
        warnings.append(
            f"YAML has use_sim_time={yaml_use_sim_time}, but compose launcher --mode={mode} implies that "
            f"use_sim_time={derived_use_sim_time}. Using use_sim_time={derived_use_sim_time}"
        )

    resolved["deploy_mode"] = derived_deploy_mode
    resolved["use_sim_time"] = derived_use_sim_time
    return resolved, warnings