#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
#                         Micipsa System Setup
#
#  Supports: Ubuntu 24.04, NVIDIA Jetson (JetPack)
#  Usage: sudo ./robot_setup.sh
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
            --branch|-b)
                export REPO_REF="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: sudo ./robot_setup.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -b, --branch <ref>   Git branch, tag, or commit hash to clone (default: main)"
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

INSTALLED_STEPS=()
SKIPPED_STEPS=()

run_installer() {
    local installer="$1"
    local rc=0

    MICIPSA_STEP_NAME="${CURRENT_STEP}" bash "${INSTALLERS_SCRIPTS_DIR}/${installer}" || rc=$?

    case "${rc}" in
        "${EXIT_SUCCESS}")
            INSTALLED_STEPS+=("${CURRENT_STEP}")
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
#                           PHASE 1 | Repo Setup
# =============================================================================

# =============================================================================
#                     STEP 2 | Setup Configuration Preview
# =============================================================================
step_setup_config_preview() {
    next_step "Robot Setup Configuration Preview"

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Robot Setup Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "GENERAL"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "WORKSPACE SETUP"
    echo -e "  ${GREEN}${BOLD}Infra Repository Location: ${RESET} ${INFRA_ROOT}"
    echo -e "  ${GREEN}${BOLD}ROS2 Workspace Location: ${RESET} ${ROS2_WS}"
    echo -e "  ${GREEN}${BOLD}GIT Repository Clone Location: ${RESET} ${REPO_ROOT}"
    echo ""

    echo -e "  ${GREEN}${BOLD}GIT Repository URL: ${RESET} ${REPO_URL}"
    echo -e "  ${GREEN}${BOLD}GIT Repository Reference: ${RESET} ${REPO_REF}"
    echo ""

    section "INSTALLERS SCRIPTS"
    echo -e "  ${GREEN}${BOLD}Robot Setup Script Directory: ${RESET} ${SCRIPT_DIR}"
    echo -e "  ${GREEN}${BOLD}Robot Installers Script Directory: ${RESET} ${INSTALLERS_SCRIPTS_DIR}"
    echo ""

    section "DOCKER"
    echo -e "  ${GREEN}${BOLD}Docker Files Directory: ${RESET} ${DOCKER_DIR}"
    echo -e "  ${GREEN}${BOLD}Docker Foundation Image: ${RESET} ${FOUNDATION_DOCKERFILE}"
    echo -e "  ${GREEN}${BOLD}Docker Compose Base File: ${RESET} ${DOCKER_COMPOSE_FILE}"
    echo -e "  ${GREEN}${BOLD}Docker Compose Deploy File: ${RESET} ${DOCKER_COMPOSE_DEPLOY}"
    echo ""

    section "UDEV RULES"
    echo -e "  ${GREEN}${BOLD}Udev Rules Directory: ${RESET} ${UDEV_RULES_DIR}"
    echo -e "  ${GREEN}${BOLD}Udev Rules Install Directory: ${RESET} ${UDEV_RULES_DIR_INSTALL_LOCATION}"
    echo ""

    section "HELPERS SCRIPTS"
    echo -e "  ${GREEN}${BOLD}Helpers Scripts Directory: ${RESET} ${HELPERS_SCRIPTS_DIR}"
    echo -e "  ${GREEN}${BOLD}Helpers Scripts Install Directory: ${RESET} ${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}"
    echo ""

    section "COMPOSE LAUNCHER"
    echo -e "  ${GREEN}${BOLD}Compose Launcher Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_DIR}"
    echo -e "  ${GREEN}${BOLD}Compose Launcher Files Install Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
    echo -e "  ${GREEN}${BOLD}Compose Launcher Wrapper Install Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
    echo ""

    section "CONFIGS"
    echo -e "  ${GREEN}${BOLD}Config Items:${RESET}"
    local rel_path
    for rel_path in "${CONFIG_ITEMS[@]}"; do
        echo -e "    - ${rel_path}${RESET}"
    done
    echo -e "  ${GREEN}${BOLD}Configs Install Directory: ${RESET} ${CONFIG_DIR_INSTALL_LOCATION}"
    echo ""

    section "SYSTEMD SERVICES"
    echo -e "  ${GREEN}${BOLD}Systemd Services Directory: ${RESET} ${SYSTEMD_SERVICES_DIR}"
    echo -e "  ${GREEN}${BOLD}Systemd Services Install Directory: ${RESET} ${SYSTEMD_SERVICES_DIR_INSTALL_LOCATION}"
    echo ""

    section "NETWORK"
    echo -e "  ${GREEN}${BOLD}RMEM_MAX: ${RESET} ${RMEM_MAX}"
    echo -e "  ${GREEN}${BOLD}RMEM_DEFAULT: ${RESET} ${RMEM_DEFAULT}"
    echo -e "  ${GREEN}${BOLD}WMEM_MAX: ${RESET} ${WMEM_MAX}"
    echo -e "  ${GREEN}${BOLD}WMEM_DEFAULT: ${RESET} ${WMEM_DEFAULT}"
    echo ""
    echo -e "  ${GREEN}${BOLD}SYSCTL Config Directory: ${RESET} ${SYSCTL_CONF_DIR}"
    echo -e "  ${GREEN}${BOLD}SYSCTL Config File: ${RESET} ${SYSCTL_CONF_FILE}"
    echo -e "  ${GREEN}${BOLD}RC_LOCAL: ${RESET} ${RC_LOCAL}"
    echo ""
    
    section "UTILS"
    echo -e "  ${GREEN}${BOLD}Utils Directory: ${RESET} ${UTILS_DIR}"
    echo -e "  ${GREEN}${BOLD}Utils Install Directory: ${RESET} ${UTILS_DIR_INSTALL_LOCATION}"
    echo ""

    section "INSTALL PATHS"
    echo -e "  ${GREEN}${BOLD}Utils Install Directory: ${RESET} ${UTILS_DIR_INSTALL_LOCATION}"
    echo -e "  ${GREEN}${BOLD}BIN Install Directory: ${RESET} ${BIN_DIR_INSTALL_LOCATION}"
    echo -e "  ${GREEN}${BOLD}Udev Rules Install Directory: ${RESET} ${UDEV_RULES_DIR_INSTALL_LOCATION}"
    echo -e "  ${GREEN}${BOLD}Helpers Scripts Install Directory: ${RESET} ${HELPERS_SCRIPTS_DIR_INSTALL_LOCATION}"
    echo -e "  ${GREEN}${BOLD}Configs Install Directory: ${RESET} ${CONFIG_DIR_INSTALL_LOCATION}"
    echo -e "  ${GREEN}${BOLD}Compose Launcher Files Install Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_INSTALL_DIR}"
    echo -e "  ${GREEN}${BOLD}Compose Launcher Wrapper Install Directory: ${RESET} ${DOCKER_COMPOSE_LAUNCHER_WRAPPER_FILE}"
    echo -e "  ${GREEN}${BOLD}Systemd Services Install Directory: ${RESET} ${SYSTEMD_SERVICES_DIR_INSTALL_LOCATION}"
    echo ""

    prompt_key "Proceed with these values?"
    if [[ "${PROMPT_CHOICE}" != "y" ]]; then
        warn_box "ABORTED" "Robot setup: aborted by user, no changes made."
        exit "${EXIT_ABORTED}"
    fi
}

# =============================================================================
#                               STEP 3 | Repo Clone
# =============================================================================
step_robot_stack_install() {
    next_step "Installing Robot Software Stack"
    run_installer "install_robot_stack.sh"
}

# =============================================================================
#                           PHASE 2: ROBOT SETUP
# =============================================================================

# =============================================================================
#                           STEP 4 | Docker Images Install
# =============================================================================
step_docker_images_install() {
    next_step "Installing Docker Images"
    run_installer "install_docker_images.sh"
}

# =============================================================================
#                   STEP 5 | Udev Rules Installation
# =============================================================================
step_udev_rules_install() {
    next_step "Installing Udev Rules"
    run_installer "install_udev_rules.sh"
}

# =============================================================================
#                   STEP 6 | Helpers Scripts Installation
# =============================================================================
step_helpers_scripts_install() {
    next_step "Installing Helpers Scripts Files"
    run_installer "install_helpers_scripts.sh"
}

# =============================================================================
#                   STEP 7 | Docker Compose Launcher Installation
# =============================================================================
step_docker_compose_runner_script_install() {
    next_step "Installing Docker Compose Launcher"
    run_installer "install_docker_compose_launcher.sh"
}

# =============================================================================
#                   STEP 8 | Config Files Installation
# =============================================================================
step_config_files_install() {
    next_step "Installing Config Files"
    run_installer "install_configs.sh"
}

# =============================================================================
#                   STEP 9 | Systemd Services Installation
# =============================================================================
step_systemd_services_install() {
    next_step "Installing Systemd Services"
    run_installer "install_systemd_units.sh"
}

# =============================================================================
#                   STEP 10 | Network Installation
# =============================================================================
step_network_install() {
    next_step "Installing Network"
    run_installer "install_network.sh"
}

# =============================================================================
#                   STEP 11 | Utils Files Installation
# =============================================================================
step_utils_files_install() {
    next_step "Installing Utils Files"
    run_installer "install_utils.sh"
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
                echo -e "${GREEN}${BOLD}║          Robot setup complete  ✔         ║${RESET}"
                echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
            else
                echo -e "${ORANGE}${BOLD}╔══════════════════════════════════════════╗${RESET}"
                echo -e "${ORANGE}${BOLD}║   Robot setup complete (parts skipped)   ║${RESET}"
                echo -e "${ORANGE}${BOLD}╚══════════════════════════════════════════╝${RESET}"
            fi
            ;;
        aborted)
            echo -e "${ORANGE}${BOLD}╔══════════════════════════════════════════╗${RESET}"
            echo -e "${ORANGE}${BOLD}║        Robot setup aborted by user       ║${RESET}"
            echo -e "${ORANGE}${BOLD}╚══════════════════════════════════════════╝${RESET}"
            ;;
        failed)
            echo -e "${RED}${BOLD}╔══════════════════════════════════════════╗${RESET}"
            echo -e "${RED}${BOLD}║            Robot setup failed  ✘         ║${RESET}"
            echo -e "${RED}${BOLD}╚══════════════════════════════════════════╝${RESET}"
            ;;
    esac
    echo ""

    if [[ ${#INSTALLED_STEPS[@]} -gt 0 ]]; then
        section "INSTALLED"
        for item in "${INSTALLED_STEPS[@]}"; do
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

    if [[ -n "${CURRENT_USER:-}" ]] && id -nG "${CURRENT_USER}" 2>/dev/null | grep -qw docker; then
        warn "Remember to log out and back in so '${CURRENT_USER}' can use Docker without sudo."
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

    # ===================
    # PHASE 1: REPO SETUP
    # ===================
    step_setup_config_preview
    step_robot_stack_install

    # ====================
    # PHASE 2: ROBOT SETUP
    # ====================
    step_docker_images_install
    step_udev_rules_install
    step_helpers_scripts_install
    step_docker_compose_runner_script_install
    step_config_files_install
    step_systemd_services_install
    step_network_install
    step_utils_files_install
    
    show_summary
}

main "$@"