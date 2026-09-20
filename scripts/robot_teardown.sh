#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
#                         Micipsa System Teardown
#
#  Supports: Ubuntu 24.04, NVIDIA Jetson (JetPack)
#  Usage: sudo ./robot_teardown.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =======
# IMPORTS
# =======
source "${SCRIPT_DIR}/helpers/log_formatting.sh"
source "${SCRIPT_DIR}/helpers/system_common.sh"

# ===================
#  ARGUMENTS
# ===================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo "Usage: sudo ./robot_teardown.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -h, --help           Show this help message"
                exit 0
                ;;
            *)
                error "Unknown argument: $1"
                echo "Use --help for usage."
                exit 1
                ;;
        esac
    done
}

# ===================
#  ERROR TRAP
# ===================
CURRENT_STEP="(initialisation)"
trap 'rc=$?
error "Script failed in step: ${CURRENT_STEP}"
error "  → Line ${LINENO}, exit code ${rc}"
error "  → Command: ${BASH_COMMAND}"
exit ${rc}' ERR

# ==============
#  STEP TRACKING
# ==============
TOTAL_STEPS=$(grep -c '^step_' "$0")
step=0
next_step() {
    step=$((step + 1))
    CURRENT_STEP="$*"
    banner "[${step}/${TOTAL_STEPS}] ${CURRENT_STEP}"
}

UNINSTALLED_STEPS=()
SKIPPED_STEPS=()


run_uninstaller() {
    local uninstaller="$1"
    local rc=0

    MICIPSA_STEP_NAME="${CURRENT_STEP}" bash "${UNINSTALLERS_SCRIPTS_DIR}/${uninstaller}" || rc=$?

    case "${rc}" in
        "${EXIT_SUCCESS}")
            UNINSTALLED_STEPS+=("${CURRENT_STEP}")
            ;;
        "${EXIT_SKIPPED}")
            SKIPPED_STEPS+=("${CURRENT_STEP}")
            ;;
        "${EXIT_ABORTED}")
            show_summary "aborted"
            exit "${EXIT_ABORTED}"
            ;;
        *)
            show_summary "failed"
            exit "${rc}"
            ;;
    esac
}


# =============================================================================
#                     PHASE 0 | Robot System Config Load
# =============================================================================

# ======================================
# STEP 1 | Load Robot System Config File
# ======================================
step_robot_system_config_load(){
    next_step "Load Robot System Configuration File"
    robot_system_config_load
}

# =============================================================================
#                     STEP 2 | Teardown Configuration Preview
# =============================================================================
step_teardown_config_preview() {
    next_step "Robot Teardown Configuration Preview"

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Robot Teardown Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "GENERAL"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "SYSTEMD SERVICES"
    echo -e "  ${GREEN}${BOLD}Systemd Services Install Directory: ${RESET} ${SYSTEMD_SERVICES_DIR_INSTALL_LOCATION}"
    echo ""

    section "UTILS"
    echo -e "  ${GREEN}${BOLD}Utils Install Directory: ${RESET} ${UTILS_DIR_INSTALL_LOCATION}/utils"
    echo ""

    section "NETWORK"
    echo -e "  ${GREEN}${BOLD}SYSCTL Config File: ${RESET} ${SYSCTL_CONF_FILE}"
    echo -e "  ${GREEN}${BOLD}RC_LOCAL: ${RESET} ${RC_LOCAL}"
    echo ""

    section "CONFIGS"
    echo -e "  ${GREEN}${BOLD}Configs Install Directory: ${RESET} ${CONFIG_DIR_INSTALL_LOCATION}"
    echo ""

    section "COMPOSE LAUNCHER"
    echo -e "  ${GREEN}${BOLD}Compose Launcher Files Install Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
    echo -e "  ${GREEN}${BOLD}Compose Launcher Wrapper Install Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
    echo ""

    section "HELPERS SCRIPTS"
    echo -e "  ${GREEN}${BOLD}Helpers Scripts Install Directory: ${RESET} ${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}"
    echo ""

    section "UDEV RULES"
    echo -e "  ${GREEN}${BOLD}Udev Rules Install Directory: ${RESET} ${UDEV_RULES_DIR_INSTALL_LOCATION}"
    echo ""

    section "DOCKER"
    echo -e "  ${GREEN}${BOLD}Docker Images: ${RESET} micipsa/* images and their containers"
    echo -e "  ${GREEN}${BOLD}Docker Engine: ${RESET} asked separately"
    echo ""

    section "ROBOT SOFTWARE STACK"
    echo -e "  ${GREEN}${BOLD}GIT Repository Clone Location: ${RESET} ${REPO_ROOT}"
    echo -e "  ${GREEN}${BOLD}ROS2 Workspace Location: ${RESET} ${ROS2_WS}"
    echo ""

    prompt_key "Proceed with these values?"
    if [[ "${PROMPT_CHOICE}" != "y" ]]; then
        warn_box "ABORTED" "Robot teardown: aborted by user, no changes made."
        exit "${EXIT_ABORTED}"
    fi
}

# =============================================================================
#                           PHASE 1 | Stop The Robot
# =============================================================================

# =============================================================================
#                   STEP 3 | Systemd Services Uninstallation
# =============================================================================
step_systemd_services_uninstall() {
    next_step "Uninstalling Systemd Services"
    run_uninstaller "uninstall_systemd_units.sh"
}

# =============================================================================
#                   PHASE 2 | Robot Teardown (reverse of setup)
# =============================================================================

# =============================================================================
#                   STEP 4 | Utils Files Uninstallation
# =============================================================================
step_utils_files_uninstall() {
    next_step "Uninstalling Utils Files"
    run_uninstaller "uninstall_utils.sh"
}

# =============================================================================
#                   STEP 5 | Network Uninstallation
# =============================================================================
step_network_uninstall() {
    next_step "Uninstalling Network"
    run_uninstaller "uninstall_network.sh"
}

# =============================================================================
#                   STEP 6 | Config Files Uninstallation
# =============================================================================
step_config_files_uninstall() {
    next_step "Uninstalling Config Files"
    run_uninstaller "uninstall_configs.sh"
}

# =============================================================================
#                   STEP 7 | Docker Compose Launcher Uninstallation
# =============================================================================
step_docker_compose_launcher_uninstall() {
    next_step "Uninstalling Docker Compose Launcher"
    run_uninstaller "uninstall_docker_compose_launcher.sh"
}

# =============================================================================
#                   STEP 8 | Helpers Scripts Uninstallation
# =============================================================================
step_helpers_scripts_uninstall() {
    next_step "Uninstalling Helpers Scripts Files"
    run_uninstaller "uninstall_helpers_scripts.sh"
}

# =============================================================================
#                   STEP 9 | Udev Rules Uninstallation
# =============================================================================
step_udev_rules_uninstall() {
    next_step "Uninstalling Udev Rules"
    run_uninstaller "uninstall_udev_rules.sh"
}

# =============================================================================
#                   STEP 10 | Docker Uninstallation
# =============================================================================
step_docker_uninstall() {
    next_step "Uninstalling Docker Images"
    run_uninstaller "uninstall_docker.sh"
}

# =============================================================================
#                   STEP 11 | Robot Software Stack Uninstallation
# =============================================================================
step_robot_stack_uninstall() {
    next_step "Uninstalling Robot Software Stack"
    run_uninstaller "uninstall_robot_stack.sh"
}

# =============================================================================
#                                   SUMMARY
# =============================================================================
show_summary() {
    local status="${1:-complete}"
    local item

    echo ""
    echo ""
    separator
    case "${status}" in
        complete)
            if [[ ${#SKIPPED_STEPS[@]} -eq 0 ]]; then
                echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
                echo -e "${GREEN}${BOLD}║         Robot teardown complete  ✔       ║${RESET}"
                echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
            else
                echo -e "${ORANGE}${BOLD}╔══════════════════════════════════════════╗${RESET}"
                echo -e "${ORANGE}${BOLD}║  Robot teardown complete (parts skipped) ║${RESET}"
                echo -e "${ORANGE}${BOLD}╚══════════════════════════════════════════╝${RESET}"
            fi
            ;;
        aborted)
            echo -e "${ORANGE}${BOLD}╔══════════════════════════════════════════╗${RESET}"
            echo -e "${ORANGE}${BOLD}║       Robot teardown aborted by user     ║${RESET}"
            echo -e "${ORANGE}${BOLD}╚══════════════════════════════════════════╝${RESET}"
            ;;
        failed)
            echo -e "${RED}${BOLD}╔══════════════════════════════════════════╗${RESET}"
            echo -e "${RED}${BOLD}║           Robot teardown failed  ✘       ║${RESET}"
            echo -e "${RED}${BOLD}╚══════════════════════════════════════════╝${RESET}"
            ;;
    esac
    echo ""

    if [[ ${#UNINSTALLED_STEPS[@]} -gt 0 ]]; then
        section "UNINSTALLED"
        for item in "${UNINSTALLED_STEPS[@]}"; do
            echo -e "    ${GREEN}✔ ${item}${RESET}"
        done
    fi
    if [[ ${#SKIPPED_STEPS[@]} -gt 0 ]]; then
        section "SKIPPED"
        for item in "${SKIPPED_STEPS[@]}"; do
            echo -e "    ${ORANGE}– ${item}${RESET}"
        done
    fi
    if [[ "${status}" != "complete" ]]; then
        section "STOPPED AT"
        echo -e "    ${RED}✘ ${CURRENT_STEP}${RESET}"
    fi
    echo ""
}

# =============================================================================
#                                       MAIN
# =============================================================================
main() {
    parse_args "$@"
    require_root

    # =================================
    # PHASE 0: Robot System Config Load
    # =================================
    step_robot_system_config_load
    step_teardown_config_preview

    # =======================
    # PHASE 1: STOP THE ROBOT
    # =======================
    step_systemd_services_uninstall

    # =======================
    # PHASE 2: ROBOT TEARDOWN
    # =======================
    step_utils_files_uninstall
    step_network_uninstall
    step_config_files_uninstall
    step_docker_compose_launcher_uninstall
    step_helpers_scripts_uninstall
    step_udev_rules_uninstall
    step_docker_uninstall
    step_robot_stack_uninstall

    show_summary
}

main "$@"