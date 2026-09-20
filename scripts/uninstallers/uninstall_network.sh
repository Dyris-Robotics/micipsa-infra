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
# Marker written by install_network.sh, used to recognise our rc.local
RC_LOCAL_MARKER="# --- Micipsa: ROS 2 / CycloneDDS network buffer tuning ---"
SYSCTL_INSTALLED=0
RC_LOCAL_INSTALLED=0

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Network Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo -e "  ${GREEN}${BOLD}Platform: ${RESET} ${PLATFORM}"
    echo ""

    section "Network"
    echo -e "  ${GREEN}${BOLD}SYSCTL Config File: ${RESET} ${SYSCTL_CONF_FILE}"
    if [[ "${PLATFORM}" == "aarch64" ]]; then
        echo -e "  ${GREEN}${BOLD}RC_LOCAL: ${RESET} ${RC_LOCAL} (only if written by Micipsa)"
    fi
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  NETWORK FUNCTIONS
# =============================================================================
is_network_config_installed() {
    banner "Checking Installed Network Configuration"

    if [[ -f "${SYSCTL_CONF_FILE}" ]]; then
        success "Installed: ${SYSCTL_CONF_FILE}"
        SYSCTL_INSTALLED=1
    else
        info "Not installed: ${SYSCTL_CONF_FILE}"
    fi

    if [[ "${PLATFORM}" == "aarch64" ]]; then
        if [[ -f "${RC_LOCAL}" ]] && grep -qF "${RC_LOCAL_MARKER}" "${RC_LOCAL}"; then
            success "Installed: ${RC_LOCAL}"
            RC_LOCAL_INSTALLED=1
        elif [[ -f "${RC_LOCAL}" ]]; then
            info "Kept: ${RC_LOCAL} was not written by Micipsa"
        else
            info "Not installed: ${RC_LOCAL}"
        fi
    fi

    if [[ ${SYSCTL_INSTALLED} -eq 0 && ${RC_LOCAL_INSTALLED} -eq 0 ]]; then
        info "No Micipsa network configuration installed, nothing to uninstall."
        return 1
    fi

    return 0
}

remove_sysctl_conf() {
    info "Removing sysctl config: ${SYSCTL_CONF_FILE}"
    rm -f "${SYSCTL_CONF_FILE}"
    success "Removed: ${SYSCTL_CONF_FILE}"

    info "Reloading the remaining sysctl configuration..."
    sysctl --system >/dev/null
    success "Sysctl configuration reloaded"

    warn "Current buffer sizes stay active until the next reboot."
}

remove_rc_local() {
    info "Removing rc.local: ${RC_LOCAL}"
    rm -f "${RC_LOCAL}"
    success "Removed: ${RC_LOCAL}"
}

uninstall_network_config() {
    banner "Uninstalling Network Configuration"

    if [[ ${SYSCTL_INSTALLED} -eq 1 ]]; then
        remove_sysctl_conf
    fi

    if [[ ${RC_LOCAL_INSTALLED} -eq 1 ]]; then
        remove_rc_local
    fi
}


# =============================================================================
#  MAIN
# =============================================================================
main() {
    require_root
    setup_error_traps

    PLATFORM="$(detect_platform)"

    robot_system_config_load
    show_context

    if ! is_network_config_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    uninstall_network_config

    exit "${EXIT_SUCCESS}"
}

main "$@"
