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
show_context(){

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Helpers Scripts Setup Configuration${RESET}"
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
is_helpers_available(){
    local script

    banner "Checking Helper Scripts"

    if [[ ! -d "${HELPERS_SCRIPTS_DIR}" ]]; then
        error "Helpers directory not found: ${HELPERS_SCRIPTS_DIR}"
        exit "${EXIT_FAILURE}"
    fi

    mapfile -t SCRIPTS < <(
        find "${HELPERS_SCRIPTS_DIR}" -maxdepth 1 -type f -name "*.sh" | sort
    )

    if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
        error "No scripts found in ${HELPERS_SCRIPTS_DIR}"
        exit "${EXIT_FAILURE}"
    fi

    for script in "${SCRIPTS[@]}"; do
        success "Found: ${script}"
    done
}

install_helpers_files(){
	local script
	local name
	local dest
	
	banner "Installing Helper Scripts"
	if [[ -z "${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}" || "${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}" == "/" ]]; then
		error "Invalid HELPERS_SCRIPTS_DIR_INSTALL_LOCATION: '${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}'. Define it in config/robot_system.conf"
		exit "${EXIT_FAILURE}"
	fi

	mkdir -p "${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}"

	for script in "${SCRIPTS[@]}"; do
		name="$(basename "${script}")"
		dest="${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}/${name}"
		cp "${script}" "${dest}"
		chmod 755 "${dest}"
		success "Installed: ${dest}"
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

	is_helpers_available
	install_helpers_files

	exit "${EXIT_SUCCESS}"
}

main "$@"