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
INSTALLED_RULES=()

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {
    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Udev Rules Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "GENERAL"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Udev Rules"
    echo -e "  ${GREEN}${BOLD}Udev Rules Directory: ${RESET} ${UDEV_RULES_DIR}"
    echo -e "  ${GREEN}${BOLD}Udev Rules Install Directory: ${RESET} ${UDEV_RULES_DIR_INSTALL_LOCATION}"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  UDEV RULES FUNCTIONS
# =============================================================================
is_udev_rules_installed(){
    local rules=()
    local rule
    local dst

    banner "Checking Installed Udev Rules"

    if [[ ! -d "${UDEV_RULES_DIR}" ]]; then
        error "udev rules directory not found: ${UDEV_RULES_DIR}"
        exit "${EXIT_FAILURE}"
    fi

    mapfile -t rules < <(
        find "${UDEV_RULES_DIR}" -maxdepth 1 -type f \( -name "*.rules" \) | sort
    )

    INSTALLED_RULES=()
    for rule in "${rules[@]}"; do
        dst="${UDEV_RULES_DIR_INSTALL_LOCATION}/$(basename "${rule}")"
        if [[ -f "${dst}" ]]; then
            success "Installed: ${dst}"
            INSTALLED_RULES+=("${dst}")
        else
            info "Not installed: ${dst}"
        fi
    done

    if [[ ${#INSTALLED_RULES[@]} -eq 0 ]]; then
        info "No Micipsa udev rules installed, nothing to uninstall."
        return 1
    fi

    return 0
}

uninstall_udev_rules(){
    local dst

    banner "Uninstalling Micipsa Udev Rules"
    for dst in "${INSTALLED_RULES[@]}"; do
        rm -f "${dst}"
        success "Removed: ${dst}"
    done
}

reload_udev_rules(){
    banner "Reloading Udev Rules"
    udevadm control --reload-rules
    info "Triggering udev..."
    udevadm trigger
}


# =============================================================================
#  MAIN
# =============================================================================
main() {
    require_root
    setup_error_traps

    robot_system_config_load
    show_context

    if ! is_udev_rules_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    uninstall_udev_rules
    reload_udev_rules

    exit "${EXIT_SUCCESS}"
}

main "$@"
