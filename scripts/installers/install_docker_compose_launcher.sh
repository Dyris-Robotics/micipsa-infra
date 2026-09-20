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
    echo -e "${BOLD}${CYAN}  Docker Compose Launcher Setup Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Docker Compose Launcher"
    echo -e "  ${GREEN}${BOLD}Docker Compose Launcher Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_DIR}"
    echo -e "  ${GREEN}${BOLD}Install Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
    echo -e "  ${GREEN}${BOLD}Install Entrypoint: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_INSTALL_FILE}"
    echo -e "  ${GREEN}${BOLD}Wrapper on PATH: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
	echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  Docker Compose Launcher FUNCTIONS
# =============================================================================
install_deps(){
	banner "Installing Python dependencies"
	if pip3 install --help | grep -q break-system-packages; then
		pip3 install --break-system-packages pyyaml
	else
		pip3 install pyyaml
	fi
	success "Python pyyaml dependencies installed"
	return 0
}

is_docker_compose_launcher_available(){
    banner "Checking Docker Compose Launcher Script"

    if [[ -f "${DOCKER_COMPOSE_LAUNCHER_DIR}/compose_launcher.py" ]]; then
        success "Found: ${DOCKER_COMPOSE_LAUNCHER_DIR}/compose_launcher.py"
        return 0
    else
        error "Docker Compose Launcher Script not found: ${DOCKER_COMPOSE_LAUNCHER_DIR}/compose_launcher.py"
        exit "${EXIT_FAILURE}"
    fi
}

install_docker_compose_launcher(){
    banner "Installing Docker Compose Launcher"

    if [[ -z "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}" || "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}" == "/" ]]; then
        error "Invalid DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR: '${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}'. Define it in configs/robot_system.conf"
        exit "${EXIT_FAILURE}"
    fi

    local launcher_modules=(
        "compose_launcher.py"
        "compose_manager.py"
        "config_loader.py"
        "env_builder.py"
    )

    mkdir -p "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"

    for module in "${launcher_modules[@]}"; do
        install -m 644 "${DOCKER_COMPOSE_LAUNCHER_DIR}/${module}" "${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}/"
        success "Installed ${module} -> ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}/${module}"
    done

    cat > "${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}" <<EOF
#!/usr/bin/env bash
exec python3 "${DOCKER_COMPOSE_LAUNCHER_INSTALL_FILE}" "\$@"
EOF
    chmod 755 "${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
    success "Installed wrapper: ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
}

check_if_runnable(){
	banner "Check If Docker Compose Launcher is Runnable"
	if command -v compose_launcher &>/dev/null; then
		success "compose_launcher is available on PATH"
	else
		error "compose_launcher not found on PATH. Check that ${MICIPSA_BIN_DIR} is in PATH"
	fi
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
	require_root
	setup_error_traps

    robot_system_config_load
    show_context

    install_deps
	is_docker_compose_launcher_available
	install_docker_compose_launcher
	check_if_runnable
	
	exit "${EXIT_SUCCESS}"
}

main "$@"