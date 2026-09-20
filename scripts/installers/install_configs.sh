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
# "<source>|<destination>" pairs
AVAILABLE_CONFIG_ITEMS=()
MISSING_CONFIG_ITEMS=()

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {
    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Configs Setup Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Configs"
    echo -e "  ${GREEN}${BOLD}Stack Config Items (${REPO_ROOT}):${RESET}"
    local rel_path
    for rel_path in "${STACK_CONFIG_ITEMS[@]}"; do
        echo -e "    ${GREEN}- ${rel_path} -> ${CONFIG_DIR_INSTALL_LOCATION}/${rel_path}${RESET}"
    done
    echo -e "  ${GREEN}${BOLD}Infra Config Items (${INFRA_ROOT}):${RESET}"
    for rel_path in "${INFRA_CONFIG_ITEMS[@]}"; do
        echo -e "    ${GREEN}- ${rel_path} -> ${INFRA_CONFIG_DIR_INSTALL_LOCATION}/${rel_path}${RESET}"
    done
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  CONFIGS FUNCTIONS
# =============================================================================
check_config_item(){
    local src="$1"
    local dst="$2"

    if [[ -e "$src" ]]; then
        success "Exists: ${src}"
        AVAILABLE_CONFIG_ITEMS+=("${src}|${dst}")
    else
        warn "Not found: ${src}"
        MISSING_CONFIG_ITEMS+=("${src}")
    fi
}

is_configs_available(){
    local rel_path

    AVAILABLE_CONFIG_ITEMS=()
    MISSING_CONFIG_ITEMS=()

    banner "Checking Available Config Files"
    for rel_path in "${STACK_CONFIG_ITEMS[@]}"; do
        check_config_item "${REPO_ROOT}/${rel_path}" "${CONFIG_DIR_INSTALL_LOCATION}/${rel_path}"
    done
    for rel_path in "${INFRA_CONFIG_ITEMS[@]}"; do
        check_config_item "${INFRA_ROOT}/${rel_path}" "${INFRA_CONFIG_DIR_INSTALL_LOCATION}/${rel_path}"
    done

    echo ""

    if [[ ${#AVAILABLE_CONFIG_ITEMS[@]} -eq 0 ]]; then
        error "No config files are available to install."
        return 1
    fi

    return 0
}

install_config_files(){
    local item
    local src
    local dst
    local needs_confirm=1

    banner "Installing Config Files"
    if [[ -z "${CONFIG_DIR_INSTALL_LOCATION}" || "${CONFIG_DIR_INSTALL_LOCATION}" == "/" ]]; then
        error "Invalid CONFIG_DIR_INSTALL_LOCATION: '${CONFIG_DIR_INSTALL_LOCATION}'. Define it in config/robot_system.conf"
        exit "${EXIT_FAILURE}"
    fi

    if [[ ! -d "${CONFIG_DIR_INSTALL_LOCATION}" ]]; then
        mkdir -p "${CONFIG_DIR_INSTALL_LOCATION}"
        info "Created install directory: ${CONFIG_DIR_INSTALL_LOCATION}"
    else
        if [[ -n "$(ls -A "${CONFIG_DIR_INSTALL_LOCATION}")" ]]; then
            needs_confirm=0
        fi
    fi

    if [[ ${needs_confirm} -eq 0 ]]; then
        echo ""
        confirm_or_skip "Folder ${CONFIG_DIR_INSTALL_LOCATION} already contains files. Override them?"
    fi

    for item in "${AVAILABLE_CONFIG_ITEMS[@]}"; do
        src="${item%%|*}"
        dst="${item#*|}"

        mkdir -p "$(dirname "$dst")"

        if [[ -e "$dst" ]]; then
            rm -rf "$dst"
        fi

        cp -a "$src" "$dst"
        success "Installed : ${dst}"
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

    is_configs_available
	install_config_files

	exit "${EXIT_SUCCESS}"
}

main "$@"