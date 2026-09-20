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
    echo -e "${BOLD}${CYAN}  Robot Software Stack Install Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "GENERAL"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""
    
    section "ROS2 WORKSPACE"
    echo -e "  ${GREEN}${BOLD}ROS2 Workspace Location: ${RESET} ${ROS2_WS}"
    echo ""


    section "GIT"
    echo -e "  ${GREEN}${BOLD}GIT Repository Clone Location: ${RESET} ${REPO_ROOT}"
    echo -e "  ${GREEN}${BOLD}GIT Repository URL: ${RESET} ${REPO_URL}"
    echo -e "  ${GREEN}${BOLD}GIT Repository Reference: ${RESET} ${REPO_REF}"
    echo ""

    section "DEPENDENCIES"
    local repos_file
    for repos_file in "${REPOS_FILES[@]}"; do
        echo -e "  ${GREEN}${BOLD}Repos File: ${RESET} ${repos_file}"
    done
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# ======================
# Ros2 Workspace
# ======================
prepare_ros2_workspace() {
    mkdir -p "${ROS2_WS}/src"
    chown -R "${CURRENT_USER}:${CURRENT_USER}" "${ROS2_WS}"
}

# ======================
# Robot Repository Clone
# ======================
checkout_ref() {
    info "Checking out '${REPO_REF}'"
    run_as_user git -C "${REPO_ROOT}" checkout "${REPO_REF}"
    success "Checked out $(run_as_user git -C "${REPO_ROOT}" rev-parse --short HEAD)"
}

remove_existing_repository() {
    if [[ ! -e "${REPO_ROOT}" ]]; then
        return 0
    fi

    # Safety guard: only ever delete something inside the workspace's src/
    if [[ -z "${ROS2_WS}" || -z "${REPO_ROOT}" || "${REPO_ROOT}" != "${ROS2_WS}/src/"* ]]; then
        error "Refusing to remove '${REPO_ROOT}': must be inside ${ROS2_WS}/src"
        exit "${EXIT_FAILURE}"
    fi

    warn "Repository already present at ${REPO_ROOT}"
    confirm_or_skip "Remove it and clone a fresh copy?"

    rm -rf "${REPO_ROOT}"
    success "Removed ${REPO_ROOT}"
}

clone_repository() {
    info "Cloning ${REPO_URL} → ${REPO_ROOT}"
    # Clone first, then checkout: 'git clone --branch' does not accept commit hashes
    run_as_user git clone "${REPO_URL}" "${REPO_ROOT}"
    checkout_ref
    success "Repository cloned"
}


# ==========================
# Stack Dependencies Import
# ==========================
install_vcstool() {
    if command -v vcs &>/dev/null; then
        success "vcstool already installed"
        return 0
    fi

    info "Installing vcstool"
    apt-get update
    # python3-vcstool comes from the ROS apt repository, vcstool from Ubuntu universe
    if apt-cache show python3-vcstool &>/dev/null; then
        apt-get install -y python3-vcstool
    else
        apt-get install -y vcstool
    fi
    success "vcstool installed"
}

install_stack_repos_dependencies() {
    local repos_file

    info "Importing Stack Repos Dependencies"

    # Check every file first, so nothing is imported if one is missing
    for repos_file in "${REPOS_FILES[@]}"; do
        if [[ ! -f "${repos_file}" ]]; then
            error "Dependencies file not found: ${repos_file}"
            exit "${EXIT_FAILURE}"
        fi
    done

    for repos_file in "${REPOS_FILES[@]}"; do
        info "Importing ${repos_file}"
        run_as_user bash -c "cd '${REPO_ROOT}' && vcs import --input '${repos_file}' ."
        success "Imported ${repos_file}"
    done

    success "Repos Dependencies imported"
}


# =============================================================================
#  MAIN
# =============================================================================
main() {
	require_root
    setup_error_traps

    robot_system_config_load
    show_context
    
    remove_existing_repository
    prepare_ros2_workspace
    clone_repository
    install_vcstool
    install_stack_repos_dependencies
	
    exit "${EXIT_SUCCESS}"
}

main "$@"