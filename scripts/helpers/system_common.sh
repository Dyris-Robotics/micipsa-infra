#!/usr/bin/env bash

# Prevent double-loading
[[ -n "${MICIPSA_COMMON_SH_LOADED:-}" ]] && return 0
readonly MICIPSA_COMMON_SH_LOADED=1


# Default script name fallback
: "${SCRIPT_NAME:=$(basename "${0:-shell}")}"

# =======
# IMPORTS
# =======
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_COMMON_DIR}/log_formatting.sh"

# =============================================================================
#  EXIT CODES
# =============================================================================
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_ABORTED=2   # user quit (q / Esc): stop everything
readonly EXIT_SKIPPED=3   # user declined (n): skip this part, continue with the next

# =============================================================================
#  Load Functions
# =============================================================================
robot_system_config_load(){
    info "Load Robot System Config File"
    CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CONF_FILE="${CURRENT_DIR}/../../config/robot_system.conf"
    if [[ ! -f "${CONF_FILE}" ]]; then
        error "Config file not found at ${CONF_FILE}"
        exit 1
    fi
    source "${CONF_FILE}"

    success "Robot System Config ${CONF_FILE} Loaded"
}

# =============================================================================
#  User Privilegies Functions
# =============================================================================
require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo ./YOUR_FILE.sh"
        exit 1
    fi
}

run_as_user() {
    sudo -u "${CURRENT_USER}" "$@"
}

# =============================================================================
#  Console Interactive Functions
# =============================================================================
# Asks a question and stores the normalized answer in PROMPT_CHOICE.
# The user types an answer and confirms it with Enter:
#   y / yes          + Enter -> "y"
#   n / no / (empty) + Enter -> "n"   (default)
#   q / quit         + Enter -> "q"
# Esc quits immediately, no Enter needed. Backspace edits the answer.
# Arrow keys and other escape sequences are ignored so they don't count as Esc.
PROMPT_CHOICE=""
prompt_key() {
    local prompt="$1"
    local key rest buffer

    while true; do
        echo -en "${ORANGE}${BOLD}${prompt} [y/N/q]:${RESET} "
        buffer=""

        # Read one key at a time so Esc can be caught without waiting for Enter
        while true; do
            # EOF (no TTY, closed stdin): treat as quit rather than looping forever
            if ! IFS= read -rsn1 key; then
                echo ""
                PROMPT_CHOICE="q"
                return 0
            fi

            case "$key" in
                "")  # Enter: submit the typed answer
                    echo ""
                    break
                    ;;
                $'\e')
                    # Bare Esc arrives alone; arrow/function keys arrive as Esc + more bytes
                    if IFS= read -rsn1 -t 0.05 rest; then
                        while IFS= read -rsn1 -t 0.01 rest; do :; done
                        continue
                    fi
                    echo ""
                    PROMPT_CHOICE="q"
                    return 0
                    ;;
                $'\x7f'|$'\b')  # Backspace
                    if [[ -n "$buffer" ]]; then
                        buffer="${buffer%?}"
                        echo -en "\b \b"
                    fi
                    ;;
                [[:print:]])
                    buffer+="$key"
                    echo -n "$key"
                    ;;
                *) ;;  # ignore other control characters
            esac
        done

        case "${buffer,,}" in
            y|yes)     PROMPT_CHOICE="y"; return 0 ;;
            n|no|"")   PROMPT_CHOICE="n"; return 0 ;;
            q|quit)    PROMPT_CHOICE="q"; return 0 ;;
            *) warn "Please answer y (install), n (skip) or q (quit)." ;;
        esac
    done
}

# Stops the current script (and, through its exit code, the whole setup).
quit_requested() {
    exit "${EXIT_ABORTED}"
}

# Yes/no question. q / Esc quits immediately.
#   returns 0 on yes, 1 on no
confirm() {
    prompt_key "$1"
    case "${PROMPT_CHOICE}" in
        y) return 0 ;;
        n) return 1 ;;
        q) quit_requested ;;
    esac
}

# Gate for a whole installer part.
#   y      -> continue
#   n      -> exit with EXIT_SKIPPED (the caller moves on to the next part)
#   q/Esc  -> exit with EXIT_ABORTED (the caller stops everything)
confirm_or_skip() {
    if confirm "$1"; then
        return 0
    fi
    exit "${EXIT_SKIPPED}"
}

# =============================================================================
#  Output Handling Functions
# =============================================================================
LAST_ERROR_CMD=""
LAST_ERROR_LINE=""
LAST_ERROR_FUNC=""

on_error() {
    local exit_code=$?
    LAST_ERROR_LINE="${1:-${LINENO}}"
    LAST_ERROR_CMD="${BASH_COMMAND}"
    LAST_ERROR_FUNC="${FUNCNAME[1]:-main}"
    # The details are reported once, inside the FAILURE box printed by on_exit
    exit "${exit_code}"
}

on_exit(){
    local exit_code=$?
    print_result "${exit_code}" "${SUCCESS_MESSAGE:-}"
    exit "${exit_code}"
}

setup_error_traps(){
    trap 'on_error ${LINENO}' ERR
    trap on_exit EXIT
}

# =============================================================================
#  Result Reporting
# =============================================================================
print_result(){
    local exit_code=$1
    local success_msg="$2"
    # Name shown in the box: the step label passed by robot_setup.sh,
    # or the script name when an installer is run on its own
    local part="${MICIPSA_STEP_NAME:-${SCRIPT_NAME}}"

    case "${exit_code}" in
        "${EXIT_SUCCESS}") success_box "SUCCESS" "${success_msg:-${part}: completed successfully.}" ;;
        "${EXIT_ABORTED}") warn_box "ABORTED" "${part}: quit requested by user." ;;
        "${EXIT_SKIPPED}") warn_box "SKIPPED" "${part}: skipped by user, no changes made." ;;
        *)
            local detail="${part}: command '${LAST_ERROR_CMD}' failed in ${LAST_ERROR_FUNC}() at line ${LAST_ERROR_LINE} (exit code ${exit_code})."
            error_box "FAILURE" "${detail}"
            ;;
    esac
}

# =============================================================================
#  Others
# =============================================================================
detect_platform() {
    case "$(uname -m)" in
        aarch64) echo "aarch64" ;;
        x86_64)  echo "x86_64" ;;
        *)       echo "unknown" ;;
    esac
}