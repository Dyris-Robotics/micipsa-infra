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
    echo -e "${BOLD}${CYAN}  Utils Setup Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo ""

    section "Utils"
    echo -e "  ${GREEN}${BOLD}Utils Files Directory: ${RESET} ${UTILS_DIR}"
    echo -e "  ${GREEN}${BOLD}Utils Files Install Directory: ${RESET} ${UTILS_DIR_INSTALL_LOCATION}"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  UTILS FUNCTIONS
# =============================================================================
probe_utils_files() {
  FOUND_UTILS_FILES=()

  if [[ ! -d "${UTILS_DIR}" ]]; then
    return 1
  fi

  while IFS= read -r -d '' file; do
    FOUND_UTILS_FILES+=("$file")
  done < <(find "${UTILS_DIR}" -path "${UTILS_DIR}/.git" -prune -o -type f -print0 | sort -z)

  return 0
}

is_utils_available() {
  banner "Checking Utils Source"

  if [[ ! -d "${UTILS_DIR}" ]]; then
    error "Utils source directory not found: ${UTILS_DIR}"
    return 1
  fi

  if [[ ${#FOUND_UTILS_FILES[@]} -eq 0 ]]; then
    error "No files found in: ${UTILS_DIR}"
    return 1
  fi

  success "Found ${#FOUND_UTILS_FILES[@]} file(s) in ${UTILS_DIR}"
  return 0
}

install_utils_files() {
    local needs_confirm=1
    local dst_dir="${UTILS_DIR_INSTALL_LOCATION}/utils"

    banner "Installing Utils Files"

    if [[ -z "${UTILS_DIR_INSTALL_LOCATION}" || "${UTILS_DIR_INSTALL_LOCATION}" == "/" ]]; then
        error "Invalid UTILS_DIR_INSTALL_LOCATION: '${UTILS_DIR_INSTALL_LOCATION}'. Define it in config/robot_system.conf"
        exit "${EXIT_FAILURE}"
    fi

    if [[ -d "${dst_dir}" && -n "$(ls -A "${dst_dir}")" ]]; then
        needs_confirm=0
    fi

    if [[ ${needs_confirm} -eq 0 ]]; then
        echo ""
        confirm_or_skip "Folder ${dst_dir} already exists and contains files. Override?"
        rm -rf "${dst_dir}"
    fi

    mkdir -p "${UTILS_DIR_INSTALL_LOCATION}"
    cp -a "${UTILS_DIR}" "${dst_dir}"
    # utils is a git clone (imported through micipsa.repos), keep only the sources
    rm -rf "${dst_dir}/.git"

    local file rel
    for file in "${FOUND_UTILS_FILES[@]}"; do
        rel="${file#${UTILS_DIR}/}"
        success "Installed: ${dst_dir}/${rel}"
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

  probe_utils_files
  is_utils_available
  install_utils_files

  exit "${EXIT_SUCCESS}"
}

main "$@"