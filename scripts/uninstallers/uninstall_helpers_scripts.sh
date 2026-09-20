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
INSTALLED_SCRIPTS=()

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context(){

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Helpers Scripts Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "GENERAL"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Helpers Scripts"
    echo -e "  ${GREEN}${BOLD}Helpers Scripts Directory: ${RESET} ${HELPERS_SCRIPTS_DIR}"
    echo -e "  ${GREEN}${BOLD}Helpers Scripts Install Directory: ${RESET} ${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  HELPERS FUNCTIONS
# =============================================================================
is_helpers_installed(){
    local scripts=()
    local script
    local dest

    banner "Checking Installed Helper Scripts"

    if [[ -z "${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}" || "${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}" == "/" ]]; then
        error "Invalid HELPERS_SCRIPTS_DIR_INSTALL_LOCATION: '${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}'. Define it in config/robot_system.conf"
        exit "${EXIT_FAILURE}"
    fi

    if [[ ! -d "${HELPERS_SCRIPTS_DIR}" ]]; then
        error "Helpers directory not found: ${HELPERS_SCRIPTS_DIR}"
        exit "${EXIT_FAILURE}"
    fi

    mapfile -t scripts < <(
        find "${HELPERS_SCRIPTS_DIR}" -maxdepth 1 -type f -name "*.sh" | sort
    )

    INSTALLED_SCRIPTS=()
    for script in "${scripts[@]}"; do
        dest="${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}/$(basename "${script}")"
        if [[ -f "${dest}" ]]; then
            success "Installed: ${dest}"
            INSTALLED_SCRIPTS+=("${dest}")
        else
            info "Not installed: ${dest}"
        fi
    done

    if [[ ${#INSTALLED_SCRIPTS[@]} -eq 0 ]]; then
        info "No helper scripts installed, nothing to uninstall."
        return 1
    fi

    return 0
}

uninstall_helpers_files(){
    local dest

    banner "Uninstalling Helper Scripts"
    for dest in "${INSTALLED_SCRIPTS[@]}"; do
        rm -f "${dest}"
        success "Removed: ${dest}"
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

    if ! is_helpers_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    uninstall_helpers_files

    exit "${EXIT_SUCCESS}"
}

main "$@"
