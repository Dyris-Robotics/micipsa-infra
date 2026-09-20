#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from utils.console.console_utils import error
from compose_manager import compose_up, compose_down

# =========================================================================
#                          DIRECTORIES PATHS
# =========================================================================
DOCKER_SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = DOCKER_SCRIPTS_DIR.parent.parent.parent
DEFAULT_DOCKER_COMPOSE_FILES_DIR = DOCKER_SCRIPTS_DIR.parent

# Bringup Configs
DEFAULT_BRINGUP_CONFIG_DIR = (
    REPO_ROOT / "micipsa_robot" / "micipsa_bringup" / "config"
).resolve()

# Maps
DEFAULT_MAPS_SOURCE_DIR = (
    REPO_ROOT / "micipsa_robot" / "micipsa_maps" / "maps"
).resolve()

# Network
DEFAULT_DDS_SOURCE_DIR = Path("/etc/micipsa/infra/dds/")

# =========================================================================
#                          DEFAULT FILES
# =========================================================================
DEFAULT_BRINGUP_CONFIG = "bringup_config.yaml"

# =========================================================================
#                           ARGS PARSER
# =========================================================================
def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="MICIPSA Docker Compose launcher",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "action",
        choices=["up", "down"],
    )
    parser.add_argument(
        "--mode",
        choices=["sim", "deploy"],
        default="sim",
        help="Compose mode to use (default: sim)",
    )
    parser.add_argument(
        "--bringup-config-name",
        type=str,
        default=DEFAULT_BRINGUP_CONFIG,
        metavar="FILENAME",
        help="Bringup config file name (default: bringup_config.yaml)",
    )
    parser.add_argument(
        "--docker-compose-files-dir",
        type=Path,
        default=DEFAULT_DOCKER_COMPOSE_FILES_DIR,
        metavar="DIR",
        help=f"Directory containing the docker-compose files (default: {DEFAULT_DOCKER_COMPOSE_FILES_DIR})",
    )
    parser.add_argument(
        "--bringup-config-dir",
        type=Path,
        default=DEFAULT_BRINGUP_CONFIG_DIR,
        metavar="DIR",
        help=f"Directory containing bringup config files (default: {DEFAULT_BRINGUP_CONFIG_DIR})",
    )
    parser.add_argument(
        "--maps-dir",
        type=Path,
        default=DEFAULT_MAPS_SOURCE_DIR,
        metavar="DIR",
        help=f"Directory containing maps files (default: {DEFAULT_MAPS_SOURCE_DIR})",
    )
    parser.add_argument(
        "--dds-dir",
        type=Path,
        default=DEFAULT_DDS_SOURCE_DIR,
        metavar="DIR",
        help=f"Directory containing DDS files (default: {DEFAULT_DDS_SOURCE_DIR})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print resolved command and exit",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Re-raise the full traceback on failure instead of a one-line error",
    )

    return parser

# =========================================================================
#                           MAIN
# =========================================================================
def main() -> int:
    parser = build_arg_parser()
    args, extra_args = parser.parse_known_args()
 
    try:
        if args.action == "up":
            compose_up(
                mode=args.mode,
                bringup_config_name=args.bringup_config_name,
                docker_compose_files_dir=args.docker_compose_files_dir.resolve(),
                bringup_config_dir=args.bringup_config_dir.resolve(),
                maps_dir=args.maps_dir.resolve(),
                dds_dir=args.dds_dir.resolve(),
                extra_args=extra_args,
                dry_run=args.dry_run,
            )
        else:
            compose_down(
                docker_compose_files_dir=args.docker_compose_files_dir.resolve(),
                extra_args=extra_args,
            )
        return 0
    except KeyboardInterrupt:
        print(error("Interrupted by user"))
        return 130
    except Exception as exc:
        if args.debug:
            raise
        print(error(str(exc)))
        return 1

if __name__ == "__main__":
    sys.exit(main())