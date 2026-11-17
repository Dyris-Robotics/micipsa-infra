#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from utils.console.console_utils import error
from compose_manager import compose_up, compose_down

# =========================================================================
#                          DIRECTORIES PATHS
# =========================================================================
DOCKER_SCRIPTS_DIR = Path(__file__).resolve().parent
DEFAULT_DOCKER_COMPOSE_FILES_DIR = DOCKER_SCRIPTS_DIR.parent

# Network
DEFAULT_DDS_SOURCE_DIR = Path("/etc/micipsa/infra/dds/")

# Paths inside the main micipsa repo (resolved at runtime from --repo-root / $MICIPSA_REPO_ROOT)
BRINGUP_CONFIG_SUBDIR = Path("micipsa_robot") / "micipsa_bringup" / "config"
MAPS_SUBDIR = Path("micipsa_robot") / "micipsa_maps" / "maps"


# =========================================================================
#                          DEFAULT FILES
# =========================================================================
DEFAULT_BRINGUP_CONFIG = "bringup_config.yaml"

# =========================================================================
#                          MICIPSA REPO
# =========================================================================
def find_repo_root(cli_value: Path | None) -> Path | None:
    """Main micipsa repo location: --repo-root, else $MICIPSA_REPO_ROOT, else None."""
    if cli_value is not None:
        return cli_value.resolve()
    env_value = os.environ.get("MICIPSA_REPO_ROOT")
    return Path(env_value).resolve() if env_value else None
    
def resolve_repo_paths(args: argparse.Namespace) -> None:
    """
    Resolve args.repo_root (optional) and fill --bringup-config-dir / --maps-dir
    from it when not given. The repo root is only *required* if one of them is
    missing, so callers that pass both (e.g. the systemd unit) don't need it.
    """
    args.repo_root = find_repo_root(args.repo_root)

    if args.bringup_config_dir is not None and args.maps_dir is not None:
        return

    if args.repo_root is None:
        raise RuntimeError(
            "Main micipsa repo location unknown: pass --repo-root or "
            "export MICIPSA_REPO_ROOT=/path/to/micipsa"
        )
    if args.bringup_config_dir is None:
        args.bringup_config_dir = args.repo_root / BRINGUP_CONFIG_SUBDIR
    if args.maps_dir is None:
        args.maps_dir = args.repo_root / MAPS_SUBDIR


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
        "--repo-root",
        type=Path,
        default=None,
        metavar="DIR",
        help="Main micipsa repo location (default: $MICIPSA_REPO_ROOT)",
    )
    parser.add_argument(
        "--bringup-config-dir",
        type=Path,
        default=None,
        metavar="DIR",
        help=f"Directory containing bringup config files (default: <repo-root>/{BRINGUP_CONFIG_SUBDIR})",
    )
    parser.add_argument(
        "--maps-dir",
        type=Path,
        default=None,
        metavar="DIR",
        help=f"Directory containing maps files (default: <repo-root>/{MAPS_SUBDIR})",
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
            resolve_repo_paths(args)
            compose_up(
                mode=args.mode,
                repo_root=args.repo_root,
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