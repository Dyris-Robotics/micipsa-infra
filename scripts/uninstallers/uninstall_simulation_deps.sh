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
    echo -e "${BOLD}${CYAN}  Simulation Dependencies Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Simulation"
    echo -e "  ${GREEN}${BOLD}Install Record: ${RESET} ${SIM_DEPS_RECORD_FILE}"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  SIMULATION FUNCTIONS
# =============================================================================
is_simulation_deps_installed() {
    banner "Checking Installed Simulation Packages"

    if [[ ! -s "${SIM_DEPS_RECORD_FILE}" ]]; then
        info "No packages recorded in ${SIM_DEPS_RECORD_FILE}, nothing to uninstall."
        return 1
    fi

    success "Recorded package(s): $(tr '\n' ' ' < "${SIM_DEPS_RECORD_FILE}")"
    return 0
}

uninstall_simulation_packages() {
    local pkgs=()

    banner "Uninstalling Simulation Host Packages"

    mapfile -t pkgs < "${SIM_DEPS_RECORD_FILE}"
    apt-get remove -y "${pkgs[@]}"
    rm -f "${SIM_DEPS_RECORD_FILE}"

    success "Removed: ${pkgs[*]}"
    success "Removed record: ${SIM_DEPS_RECORD_FILE}"
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

    if ! is_simulation_deps_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    uninstall_simulation_packages

    exit "${EXIT_SUCCESS}"
}

main "$@"
