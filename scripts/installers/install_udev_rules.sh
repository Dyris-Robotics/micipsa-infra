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
    echo -e "${BOLD}${CYAN}  Udev Rules Setup Configuration${RESET}"
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
is_udev_rules_available(){
    local rules=()
    local rule

    banner "Checking Available Udev Rules"

    if [[ ! -d "${UDEV_RULES_DIR}" ]]; then
        error "udev rules directory not found: ${UDEV_RULES_DIR}" >&2
        exit "${EXIT_FAILURE}"
    fi

    mapfile -t rules < <(
        find "${UDEV_RULES_DIR}" -maxdepth 1 -type f \( -name "*.rules" \) | sort
    )

    if [[ ${#rules[@]} -eq 0 ]]; then
        error "No udev rules found in ${UDEV_RULES_DIR}"
        exit "${EXIT_FAILURE}"
    fi

    for rule in "${rules[@]}"; do
        success "Found: ${rule}"
    done

    return 0
}

install_udev_rules(){
    banner "Installing Micipsa Udev Rules"
    for rule in "${UDEV_RULES_DIR}"/*.rules; do
        [[ -e "$rule" ]] || continue

        dst="${UDEV_RULES_DIR_INSTALL_LOCATION}/$(basename "$rule")"
        install -m 644 "$rule" "$dst"
        success "Installed: ${rule}"
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
    
    is_udev_rules_available
	install_udev_rules
    reload_udev_rules
	
    exit "${EXIT_SUCCESS}"
}

main "$@"