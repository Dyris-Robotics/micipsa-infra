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
INSTALLED_CONFIG_ITEMS=()

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {
    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Configs Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Configs"
    echo -e "  ${GREEN}${BOLD}Stack Config Items:${RESET}"
    local rel_path
    for rel_path in "${STACK_CONFIG_ITEMS[@]}"; do
        echo -e "    ${GREEN}- ${CONFIG_DIR_INSTALL_LOCATION}/${rel_path}${RESET}"
    done
    echo -e "  ${GREEN}${BOLD}Infra Config Items:${RESET}"
    for rel_path in "${INFRA_CONFIG_ITEMS[@]}"; do
        echo -e "    ${GREEN}- ${INFRA_CONFIG_DIR_INSTALL_LOCATION}/${rel_path}${RESET}"
    done
    echo ""
    warn "Anything saved inside these folders since install is removed too."
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  CONFIGS FUNCTIONS
# =============================================================================
check_installed_config_item(){
    local dst="$1"

    if [[ -e "${dst}" ]]; then
        success "Installed: ${dst}"
        INSTALLED_CONFIG_ITEMS+=("${dst}")
    else
        info "Not installed: ${dst}"
    fi
}

is_configs_installed(){
    local rel_path

    INSTALLED_CONFIG_ITEMS=()

    banner "Checking Installed Config Files"

    if [[ -z "${CONFIG_DIR_INSTALL_LOCATION}" || "${CONFIG_DIR_INSTALL_LOCATION}" == "/" ]]; then
        error "Invalid CONFIG_DIR_INSTALL_LOCATION: '${CONFIG_DIR_INSTALL_LOCATION}'. Define it in config/robot_system.conf"
        exit "${EXIT_FAILURE}"
    fi

    # Same item lists install_configs.sh installs from
    for rel_path in "${STACK_CONFIG_ITEMS[@]}"; do
        check_installed_config_item "${CONFIG_DIR_INSTALL_LOCATION}/${rel_path}"
    done
    for rel_path in "${INFRA_CONFIG_ITEMS[@]}"; do
        check_installed_config_item "${INFRA_CONFIG_DIR_INSTALL_LOCATION}/${rel_path}"
    done

    echo ""

    if [[ ${#INSTALLED_CONFIG_ITEMS[@]} -eq 0 ]]; then
        info "No config files installed, nothing to uninstall."
        return 1
    fi

    return 0
}

remove_empty_parents(){
    local dir
    dir="$(dirname "$1")"

    while [[ "${dir}" == "${CONFIG_DIR_INSTALL_LOCATION}"/* && -d "${dir}" && -z "$(ls -A "${dir}")" ]]; do
        rmdir "${dir}"
        success "Removed empty directory: ${dir}"
        dir="$(dirname "${dir}")"
    done
}

uninstall_config_files(){
    local dst

    banner "Uninstalling Config Files"

    for dst in "${INSTALLED_CONFIG_ITEMS[@]}"; do
        rm -rf "${dst}"
        success "Removed: ${dst}"
        remove_empty_parents "${dst}"
    done

    if [[ -d "${CONFIG_DIR_INSTALL_LOCATION}" && -z "$(ls -A "${CONFIG_DIR_INSTALL_LOCATION}")" ]]; then
        rmdir "${CONFIG_DIR_INSTALL_LOCATION}"
        success "Removed empty directory: ${CONFIG_DIR_INSTALL_LOCATION}"
    elif [[ -d "${CONFIG_DIR_INSTALL_LOCATION}" ]]; then
        info "Kept (contains other files): ${CONFIG_DIR_INSTALL_LOCATION}"
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

    if ! is_configs_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    uninstall_config_files

    exit "${EXIT_SUCCESS}"
}

main "$@"
