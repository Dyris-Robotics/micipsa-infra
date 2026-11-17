#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =======
# IMPORTS
# =======
source "${SCRIPT_DIR}/../helpers/log_formatting.sh"
source "${SCRIPT_DIR}/../helpers/system_common.sh"

# Host packages needed to run the simulation stack (dev machines only, not the robot)
#   x11-xserver-utils : xhost, used by compose_launcher to grant the sim container X11 access
SIM_APT_PACKAGES=(
    x11-xserver-utils
)

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Simulation Dependencies Setup Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Simulation"
    echo -e "  ${GREEN}${BOLD}Packages: ${RESET} ${SIM_APT_PACKAGES[*]}"
    echo -e "  ${GREEN}${BOLD}Install Record: ${RESET} ${SIM_DEPS_RECORD_FILE}"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  SIMULATION FUNCTIONS
# =============================================================================
install_simulation_packages() {
    local pkg
    local to_install=()

    banner "Installing Simulation Host Packages"

    for pkg in "${SIM_APT_PACKAGES[@]}"; do
        if dpkg -s "${pkg}" &>/dev/null; then
            success "${pkg} already installed"
        else
            to_install+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        return 0
    fi

    info "Installing: ${to_install[*]}"
    apt-get update
    apt-get install -y --no-install-recommends "${to_install[@]}"

    # Record only what we installed, so the uninstaller never removes pre-existing packages
    mkdir -p "$(dirname "${SIM_DEPS_RECORD_FILE}")"
    printf '%s\n' "${to_install[@]}" >> "${SIM_DEPS_RECORD_FILE}"
    sort -u -o "${SIM_DEPS_RECORD_FILE}" "${SIM_DEPS_RECORD_FILE}"

    for pkg in "${to_install[@]}"; do
        success "Installed: ${pkg}"
    done
    return 0
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
    require_root
    setup_error_traps

    robot_system_config_load
    show_context

    install_simulation_packages

    exit "${EXIT_SUCCESS}"
}

main "$@"
