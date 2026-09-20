#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =======
# IMPORTS
# =======
source "${SCRIPT_DIR}/../helpers/log_formatting.sh"
source "${SCRIPT_DIR}/../helpers/system_common.sh"

# =============================================================================
#  Global State
# =============================================================================
INSTALLED_UNITS=()

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Systemd Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Systemd Services"
    echo -e "  ${GREEN}${BOLD}Systemd Files Directory: ${RESET} ${SYSTEMD_SERVICES_DIR}"
    echo -e "  ${GREEN}${BOLD}Systemd Files Install Directory: ${RESET} ${SYSTEMD_SERVICES_DIR_INSTALL_LOCATION}"
    echo ""
    warn "Running Micipsa services are stopped, which also brings the robot stack down."
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  SYSTEMD FUNCTIONS
# =============================================================================
is_systemd_installed(){
    local units=()
    local unit
    local dst

    banner "Checking Installed Systemd Units"

    if [[ ! -d "${SYSTEMD_SERVICES_DIR}" ]]; then
        error "Systemd source directory not found: ${SYSTEMD_SERVICES_DIR}"
        exit "${EXIT_FAILURE}"
    fi

    mapfile -t units < <(
        find "${SYSTEMD_SERVICES_DIR}" -maxdepth 1 -type f \( -name "*.service" -o -name "*.target" \) | sort
    )

    INSTALLED_UNITS=()
    for unit in "${units[@]}"; do
        dst="${SYSTEMD_SERVICES_DIR_INSTALL_LOCATION}/$(basename "${unit}")"
        if [[ -f "${dst}" ]]; then
            success "Installed: ${dst}"
            INSTALLED_UNITS+=("$(basename "${unit}")")
        else
            info "Not installed: ${dst}"
        fi
    done

    echo ""

    if [[ ${#INSTALLED_UNITS[@]} -eq 0 ]]; then
        info "No Micipsa systemd units installed, nothing to uninstall."
        return 1
    fi

    return 0
}

stop_and_disable_systemd(){
    local name

    banner "Stopping and Disabling Micipsa Targets/Services"

    for name in "${INSTALLED_UNITS[@]}"; do
        if systemctl is-active --quiet "${name}"; then
            info "Stopping ${name}"
            systemctl stop "${name}"
            success "Stopped ${name}"
        fi

        if systemctl is-enabled --quiet "${name}" 2>/dev/null; then
            info "Disabling ${name}"
            systemctl disable "${name}"
            success "Disabled ${name}"
        fi
    done
}

uninstall_systemd_files(){
    local name

    banner "Uninstalling Micipsa Systemd Units"
    for name in "${INSTALLED_UNITS[@]}"; do
        rm -f "${SYSTEMD_SERVICES_DIR_INSTALL_LOCATION}/${name}"
        success "Removed: ${SYSTEMD_SERVICES_DIR_INSTALL_LOCATION}/${name}"
    done

    info "Reloading systemd..."
    systemctl daemon-reload
    for name in "${INSTALLED_UNITS[@]}"; do
        systemctl reset-failed "${name}" 2>/dev/null || true
    done
    success "Systemd reloaded"
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
    require_root
    setup_error_traps

    robot_system_config_load
    show_context

    if ! is_systemd_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    stop_and_disable_systemd
    uninstall_systemd_files

    exit "${EXIT_SUCCESS}"
}

main "$@"
