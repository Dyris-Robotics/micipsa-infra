#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =======
# IMPORTS
# =======
source "${SCRIPT_DIR}/../helpers/log_formatting.sh"
source "${SCRIPT_DIR}/../helpers/system_common.sh"

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Docker Compose Launcher Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Docker Compose Launcher"
    echo -e "  ${GREEN}${BOLD}Install Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
    echo -e "  ${GREEN}${BOLD}Wrapper on PATH: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
    echo -e "  ${GREEN}${BOLD}Python pyyaml: ${RESET} kept (shared system Python package)"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  Docker Compose Launcher FUNCTIONS
# =============================================================================
is_docker_compose_launcher_installed(){
    local found=0

    banner "Checking Installed Docker Compose Launcher"

    if [[ -z "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}" || "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}" == "/" ]]; then
        error "Invalid DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR: '${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}'. Define it in config/robot_system.conf"
        exit "${EXIT_FAILURE}"
    fi

    if [[ -d "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}" ]]; then
        success "Installed: ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
        found=1
    else
        info "Not installed: ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
    fi

    if [[ -f "${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}" ]]; then
        success "Installed: ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
        found=1
    else
        info "Not installed: ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
    fi

    if [[ ${found} -eq 0 ]]; then
        info "Docker Compose Launcher not installed, nothing to uninstall."
        return 1
    fi

    return 0
}

uninstall_docker_compose_launcher(){
    banner "Uninstalling Docker Compose Launcher"

    # Same module list install_docker_compose_launcher.sh installs
    local launcher_modules=(
        "compose_launcher.py"
        "compose_manager.py"
        "config_loader.py"
        "env_builder.py"
    )
    local module

    if [[ -f "${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}" ]]; then
        rm -f "${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
        success "Removed wrapper: ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
    fi

    if [[ -d "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}" ]]; then
        for module in "${launcher_modules[@]}"; do
            if [[ -f "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}/${module}" ]]; then
                rm -f "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}/${module}"
                success "Removed: ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}/${module}"
            fi
        done

        # Bytecode Python generated when the launcher ran
        rm -rf "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}/__pycache__"

        if [[ -z "$(ls -A "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}")" ]]; then
            rmdir "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
            success "Removed: ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
        else
            warn "Kept (contains other files): ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
        fi
    fi

    if [[ -d "${UTILS_DIR_INSTALL_LOCATION}" && -z "$(ls -A "${UTILS_DIR_INSTALL_LOCATION}")" ]]; then
        rmdir "${UTILS_DIR_INSTALL_LOCATION}"
        success "Removed empty directory: ${UTILS_DIR_INSTALL_LOCATION}"
    fi
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
    require_root
    setup_error_traps

    robot_system_config_load
    show_context

    if ! is_docker_compose_launcher_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    uninstall_docker_compose_launcher

    exit "${EXIT_SUCCESS}"
}

main "$@"
