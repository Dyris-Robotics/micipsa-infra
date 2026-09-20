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
    echo -e "${BOLD}${CYAN}  Systemd Setup Configuration${RESET}"
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

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  SYSTEMD FUNCTIONS
# =============================================================================
is_systemd_available(){
    local units=()
    local unit

    banner "Checking Available Systemd Files"

    if [[ ! -d "${SYSTEMD_SERVICES_DIR}" ]]; then
        error "Systemd source directory not found: ${SYSTEMD_SERVICES_DIR}"
        exit "${EXIT_FAILURE}"
    fi

    mapfile -t units < <(
        find "${SYSTEMD_SERVICES_DIR}" -maxdepth 1 -type f \( -name "*.service" -o -name "*.target" \) | sort
    )

    if [[ ${#units[@]} -eq 0 ]]; then
        error "No .service or .target files found in ${SYSTEMD_SERVICES_DIR}"
        exit "${EXIT_FAILURE}"
    fi

    for unit in "${units[@]}"; do
        success "Found: ${unit}"
    done

    echo ""
    return 0
}

install_systemd_files(){
    banner "Installing Micipsa Systemd Units"
    for unit in "$SYSTEMD_SERVICES_DIR"/*.{service,target}; do
        sudo install -m 644 "$unit" "$SYSTEMD_SERVICES_DIR_INSTALL_LOCATION/$(basename "$unit")"
        success "Installed : ${unit} -> ${SYSTEMD_SERVICES_DIR_INSTALL_LOCATION}/$(basename "$unit")"
    done
}

enable_systemd(){
    banner "Enabling Micipsa Targets/Services"
    info "Reloading systemd..."
    systemctl daemon-reload

    for unit in "$SYSTEMD_SERVICES_DIR"/*.service; do
        local name
        name="$(basename "$unit")"
        info "Enabling ${name}"
        systemctl enable "$name"
    done
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
	require_root
    setup_error_traps

    robot_system_config_load
    show_context

	is_systemd_available
	install_systemd_files
    enable_systemd

	exit "${EXIT_SUCCESS}"
}

main "$@"