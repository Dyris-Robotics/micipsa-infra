from __future__ import annotations

import os
import subprocess
from pathlib import Path

from utils.console.console_utils import banner, command, field, item, ok, subsection, warn, error_box
from config_loader import load_bringup_config, load_devices_config, resolve_mode_flags
from env_builder import EnvGroups, compose_env_vars

# =========================================================================
#                       DOCKER COMPOSE FILES
# =========================================================================
BASE_COMPOSE_FILE_NAME = "docker-compose.yaml"
DEPLOY_COMPOSE_FILE_NAME = "docker-compose.deploy.yaml"
SIM_COMPOSE_FILE_NAME = "docker-compose.sim.yaml"

# =========================================================================
#                FILES CONTAINER INSTALL DIRECTORIES
# =========================================================================
BRINGUP_CONFIG_INSTALL_DIR = Path(
    "/ros2_ws/install/micipsa_bringup/share/micipsa_bringup/config"
)
MAPS_INSTALL_DIR = Path("/ros2_ws/install/micipsa_maps/share/micipsa_maps/maps")
DDS_INSTALL_DIR = Path("/etc/micipsa/infra/dds/")


# =========================================================================
#                             RUN FUNCTIONS
# =========================================================================
def run_docker_command(cmd: list[str], env: dict[str, str] | None = None) -> None:
    """
    Run a docker/docker-compose command, raising on failure.
    """
    try:
        result = subprocess.run(cmd, env=env)
    except FileNotFoundError:
        raise FileNotFoundError("'docker' not found on PATH")

    if result.returncode != 0:
        raise RuntimeError(f"docker compose exited with code {result.returncode}")

# =====================
# Docker Compose up Run
# =====================
def compose_up(
    mode: str,
    bringup_config_name: str,
    docker_compose_files_dir: Path,
    bringup_config_dir: Path,
    maps_dir: Path,
    dds_dir: Path,
    extra_args: list[str],
    dry_run: bool = False,
) -> None:
    
    # Load and validate the bringup config for the requested mode
    settings, bringup_config_path = load_bringup_config(str(bringup_config_dir), bringup_config_name, config_subdir="")
    settings, mode_warnings = resolve_mode_flags(settings, mode)

    # Load Devices Config
    devices_config_file = settings.get("devices_config_file")
    if not devices_config_file:
        raise KeyError(
            "devices_config_file is missing from the bringup config settings. "
            "Add 'devices_config_file' to the bringup config's 'settings' block."
        )
    devices_data = load_devices_config(
        str(bringup_config_dir), str(devices_config_file), "hardware"
    )

    # Build everything needed to launch: which files, which env vars, which command.
    compose_files = resolve_compose_files(docker_compose_files_dir, mode, "up")
    env_vars = compose_env_vars(
        bringup_config_dir, maps_dir, dds_dir, settings, devices_data,
        bringup_config_install_dir=BRINGUP_CONFIG_INSTALL_DIR,
        maps_install_dir=MAPS_INSTALL_DIR,
        dds_install_dir=DDS_INSTALL_DIR,
    )

    launch_command = construct_launch_command(env_vars, compose_files, extra_args)

    write_dotenv(env_vars.merged(), docker_compose_files_dir)
    
    # Print Summary
    print_launch_summary(
        mode=mode,
        config_path=bringup_config_path,
        compose_files=compose_files,
        env_vars=env_vars,
        extra_args=extra_args,
        cmd=launch_command,
        dry_run=dry_run,
        mode_warnings=mode_warnings,
    )

    # Execute Command
    if not dry_run:
        run_docker_command(launch_command, env={**os.environ, **env_vars.merged()})

    print(ok("docker compose up completed successfully"))

# =======================
# Docker Compose Down Run
# =======================
def compose_down(docker_compose_files_dir: Path, extra_args: list[str]) -> None:
    """Bring down the stack, including any sim/deploy overlays that were used."""
    compose_files = resolve_compose_files(docker_compose_files_dir, mode="", action="down")

    cmd = ["docker", "compose"]
    for compose_file in compose_files:
        cmd += ["-f", str(compose_file)]
    cmd += ["down", "--remove-orphans"] + extra_args

    print(banner("COMMAND"))
    print(item(command(cmd)))

    run_docker_command(cmd)

    print(ok("docker compose down completed successfully"))

# =========================================================================
#                             FILES RESOLUTION
# =========================================================================
def is_compose_file_available(path: Path, label: str, docker_compose_files_dir: Path) -> None:
    if not path.exists():
        error_text = (
            f"{label} compose file not found: {path}\n"
            f"Provided --docker-compose-files-dir: {docker_compose_files_dir}"
        )
        print(error_box("Missing File", error_text))
        raise FileNotFoundError()
    
def resolve_compose_files(
    docker_compose_files_dir: Path, mode: str, action: str
) -> list[Path]:
    base_compose = docker_compose_files_dir / BASE_COMPOSE_FILE_NAME
    sim_compose = docker_compose_files_dir / SIM_COMPOSE_FILE_NAME
    deploy_compose = docker_compose_files_dir / DEPLOY_COMPOSE_FILE_NAME

    is_compose_file_available(base_compose, "Base", docker_compose_files_dir)
    compose_files = [base_compose]

    if action == "down":
        if deploy_compose.exists():
            compose_files.append(deploy_compose)
        if sim_compose.exists():
            compose_files.append(sim_compose)
        return compose_files

    if mode == "deploy":
        is_compose_file_available(deploy_compose, "Deploy", docker_compose_files_dir)
        compose_files.append(deploy_compose)

    elif mode == "sim":
        is_compose_file_available(sim_compose, "Sim", docker_compose_files_dir)
        compose_files.append(sim_compose)

    else:
        raise ValueError(f"Unsupported mode: {mode}, options: deploy | sim ")

    return compose_files

# =========================================================================
#                               HELPERS
# =========================================================================
def construct_launch_command(
    env_vars: EnvGroups, compose_files: list[Path], extra_args: list[str]
) -> list[str]:
    cmd = ["docker", "compose"]

    for compose_file in compose_files:
        cmd += ["-f", str(compose_file)]

    localization_mode = env_vars.bringup.get("MICIPSA_LOCALIZATION_MODE")
    if not localization_mode:
        raise KeyError(
            "MICIPSA_LOCALIZATION_MODE is missing from the bringup config settings. "
            "Add 'localization_mode' to the bringup config's 'settings' block."
        )
    profiles = [localization_mode]

    if env_vars.bringup.get("MICIPSA_ENABLE_PERCEPTION") == "true":
        profiles.append("perception")

    if env_vars.bringup.get("MICIPSA_ENABLE_BEHAVIOR") == "true":
        profiles.append("behavior")

    for profile in profiles:
        cmd += ["--profile", profile]

    cmd += ["up"] + extra_args

    return cmd

def write_dotenv(env_vars: dict[str, str], docker_compose_files_dir: Path) -> None:
    """Write env vars to .env so all docker compose invocations pick them up."""
    env_file = docker_compose_files_dir / ".env"
    with env_file.open("w", encoding="utf-8") as f:
        for key, value in env_vars.items():
            f.write(f"{key}={value}\n")
    
# =========================================================================
#                             PRINT FUNCTIONS
# =========================================================================
def print_launch_summary(
    mode: str,
    config_path: str,
    compose_files: list[Path],
    env_vars: EnvGroups,
    extra_args: list[str],
    cmd: list[str],
    dry_run: bool = False,
    mode_warnings: list[str] | None = None,
) -> None:
    print(banner("Micipsa Compose"))

    print(subsection("Micipsa Compose Launch Arguments"))
    print(field("Micipsa Bringup config", config_path))
    print(field("Mode", mode))
    print(field("Compose file(s)", ", ".join(str(p) for p in compose_files)))
    print(field("Extra args", " ".join(extra_args) if extra_args else "(none)"))

    if mode_warnings:
        print(banner("Mode Consistency"))
        for message in mode_warnings:
            print(warn(message))

    print(banner("Micipsa Bringup Config"))
    print(subsection("Micipsa Bringup Launch Arguments"))
    for key, value in env_vars.bringup.items():
        print(field(key, value, key_width=34))

    print(banner("Micipsa Devices"))
    print(subsection("Micipsa Devices Config"))
    if env_vars.devices:
        for key, value in env_vars.devices.items():
            print(field(key, value, key_width=34))
    else:
        print(item("(none)"))

    print(banner("Bringup Config Containers Install Dir"))
    print(field("Bringup Config Install Dir", env_vars.compose["BRINGUP_CONFIG_INSTALL_DIR"]))

    print(banner("Maps Files"))
    print(field("Maps Source Dir", env_vars.compose["MAPS_SOURCE_DIR"]))
    print(field("Maps Containers Install Dir", env_vars.compose["MAPS_INSTALL_DIR"]))

    print(banner("DDS Files"))
    print(field("DDS Source Dir", env_vars.compose["DDS_SOURCE_DIR"]))
    print(field("DDS Containers Install Dir", env_vars.compose["DDS_INSTALL_DIR"]))

    print(banner("Docker Compose Command"))
    print(ok(item(command(cmd))))
    if dry_run:
        print(warn("Dry-run enabled, command will not be executed"))