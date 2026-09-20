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
    echo -e "${BOLD}${CYAN}  Utils Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Utils"
    echo -e "  ${GREEN}${BOLD}Utils Files Install Directory: ${RESET} ${UTILS_DIR_INSTALL_LOCATION}/utils"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  UTILS FUNCTIONS
# =============================================================================
is_utils_installed() {
    local dst_dir="${UTILS_DIR_INSTALL_LOCATION}/utils"
    local count

    banner "Checking Installed Utils"

    if [[ -z "${UTILS_DIR_INSTALL_LOCATION}" || "${UTILS_DIR_INSTALL_LOCATION}" == "/" ]]; then
        error "Invalid UTILS_DIR_INSTALL_LOCATION: '${UTILS_DIR_INSTALL_LOCATION}'. Define it in config/robot_system.conf"
        exit "${EXIT_FAILURE}"
    fi

    if [[ ! -d "${dst_dir}" ]]; then
        info "Not installed: ${dst_dir}, nothing to uninstall."
        return 1
    fi

    count="$(find "${dst_dir}" -type f | wc -l)"
    success "Found ${count} file(s) in ${dst_dir}"
    return 0
}

uninstall_utils_files() {
    local dst_dir="${UTILS_DIR_INSTALL_LOCATION}/utils"

    banner "Uninstalling Utils Files"

    rm -rf "${dst_dir}"
    success "Removed: ${dst_dir}"

    if [[ -d "${UTILS_DIR_INSTALL_LOCATION}" && -z "$(ls -A "${UTILS_DIR_INSTALL_LOCATION}")" ]]; then
        rmdir "${UTILS_DIR_INSTALL_LOCATION}"
        success "Removed empty directory: ${UTILS_DIR_INSTALL_LOCATION}"
    fi

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

    if ! is_utils_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    uninstall_utils_files

    exit "${EXIT_SUCCESS}"
}

main "$@"
