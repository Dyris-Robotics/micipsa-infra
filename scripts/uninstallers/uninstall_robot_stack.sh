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
# Git checkouts inside REPO_ROOT (the stack + repos imported by vcs) with local changes
DIRTY_REPOSITORIES=()

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {
    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Robot Software Stack Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "GENERAL"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "ROS2 WORKSPACE"
    echo -e "  ${GREEN}${BOLD}ROS2 Workspace Location: ${RESET} ${ROS2_WS} (removed only if left empty)"
    echo ""

    section "GIT"
    echo -e "  ${GREEN}${BOLD}GIT Repository Clone Location: ${RESET} ${REPO_ROOT}"
    echo -e "  ${GREEN}${BOLD}Imported Dependencies: ${RESET} everything vcs imported inside ${REPO_ROOT}"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  ROBOT STACK FUNCTIONS
# =============================================================================
is_robot_stack_installed() {
    banner "Checking Robot Software Stack"

    # Safety guard: only ever delete something inside the workspace's src/
    if [[ -z "${ROS2_WS}" || -z "${REPO_ROOT}" || "${REPO_ROOT}" != "${ROS2_WS}/src/"* ]]; then
        error "Refusing to remove '${REPO_ROOT}': must be inside ${ROS2_WS}/src"
        exit "${EXIT_FAILURE}"
    fi

    if [[ ! -e "${REPO_ROOT}" ]]; then
        info "Not found: ${REPO_ROOT}, nothing to uninstall."
        return 1
    fi

    success "Found: ${REPO_ROOT}"
    return 0
}

check_local_changes() {
    local git_dir
    local repo

    DIRTY_REPOSITORIES=()

    while IFS= read -r -d '' git_dir; do
        repo="$(dirname "${git_dir}")"
        if [[ -n "$(run_as_user git -C "${repo}" status --porcelain 2>/dev/null)" ]]; then
            DIRTY_REPOSITORIES+=("${repo}")
        fi
    done < <(find "${REPO_ROOT}" -name .git -prune -print0 2>/dev/null)

    if [[ ${#DIRTY_REPOSITORIES[@]} -eq 0 ]]; then
        success "No uncommitted changes found"
        return 0
    fi

    for repo in "${DIRTY_REPOSITORIES[@]}"; do
        warn "Uncommitted changes in: ${repo}"
    done
    echo ""
    confirm_or_skip "These local changes will be lost. Remove anyway?"
}

remove_repository() {
    banner "Removing Robot Software Stack"

    rm -rf "${REPO_ROOT}"
    success "Removed: ${REPO_ROOT}"
}

cleanup_ros2_workspace() {
    local dir

    for dir in "${ROS2_WS}/src" "${ROS2_WS}"; do
        if [[ -d "${dir}" && -z "$(ls -A "${dir}")" ]]; then
            rmdir "${dir}"
            success "Removed empty directory: ${dir}"
        elif [[ -d "${dir}" ]]; then
            info "Kept (not empty): ${dir}"
        fi
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

    if ! is_robot_stack_installed; then
        exit "${EXIT_SUCCESS}"
    fi
    check_local_changes
    remove_repository
    cleanup_ros2_workspace

    exit "${EXIT_SUCCESS}"
}

main "$@"
