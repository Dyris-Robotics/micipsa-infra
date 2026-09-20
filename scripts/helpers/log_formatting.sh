#!/usr/bin/env bash

# =============================================================================
#                             Include Guard
# =============================================================================
if [[ -n "${LOG_FORMATTING_LOADED:-}" ]]; then
    return 0
fi
LOG_FORMATTING_LOADED=1

# =============================================================================
#                             Log Colors
# =============================================================================
RED='\x1b[38;5;160m'; GREEN='\x1b[38;5;76m'; ORANGE='\x1b[38;5;208m'
CYAN='\x1b[38;5;81m'; PURPLE='\x1b[38;5;5m'; BOLD='\033[1m'; RESET='\033[0m'

# =============================================================================
#                             Log Functions
# =============================================================================
info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}${CYAN}  $*${RESET}"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}${GREEN}    $*${RESET}"; }
warn()    { echo -e "${ORANGE}${BOLD}[WARN]${RESET}${ORANGE}  $*${RESET}"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET}${RED} $*${RESET}" >&2; }

banner() {
    local text="$*"
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)
    local border_width=$(( term_width - 2 ))
    local border
    border=$(printf '═%.0s' $(seq 1 "${border_width}"))

    local text_len=${#text}
    local pad=$(( (term_width - text_len) / 2 ))
    local padding
    padding=$(printf ' %.0s' $(seq 1 "${pad}"))

    echo ""
    echo -e "${BOLD}${PURPLE}═${border}═${RESET}"
    echo -e "${BOLD}${PURPLE}${padding}${text}${RESET}"
    echo -e "${BOLD}${PURPLE}═${border}═${RESET}"
    echo ""
}

success_box() {
    local title="${1:-SUCCESS}"
    local message="$2"
    local width
    width=$(tput cols 2>/dev/null || echo "$COLUMNS")
    width=${width:-80}
    (( width > 100 )) && width=100

    local inner=$((width - 2))
    local line=""
    line=$(printf '═%.0s' $(seq 1 "$inner"))

    local top="╔${line}╗"
    local mid="╠${line}╣"
    local bot="╚${line}╝"

    echo >&2
    echo -e "${GREEN}${BOLD}${top}${RESET}" >&2

    local title_len=${#title}
    local pad_left=$(( (inner - title_len) / 2 ))
    local pad_right=$(( inner - title_len - pad_left ))
    printf "${GREEN}${BOLD}║%*s%s%*s║${RESET}\n" "$pad_left" "" "$title" "$pad_right" "" >&2

    echo -e "${GREEN}${BOLD}${mid}${RESET}" >&2

    local content_width=$((inner - 2))
    while IFS= read -r wline; do
        printf "${GREEN}${BOLD}║${RESET} ${GREEN}%-*s${RESET} ${GREEN}${BOLD}║${RESET}\n" "$content_width" "$wline" >&2
    done <<< "$(fold -s -w "$content_width" <<< "$message")"

    echo -e "${GREEN}${BOLD}${bot}${RESET}" >&2
    echo >&2
}

warn_box() {
    local title="${1:-WARN}"
    local message="$2"
    local width
    width=$(tput cols 2>/dev/null || echo "$COLUMNS")
    width=${width:-80}
    (( width > 100 )) && width=100

    local inner=$((width - 2))
    local line=""
    line=$(printf '═%.0s' $(seq 1 "$inner"))

    local top="╔${line}╗"
    local mid="╠${line}╣"
    local bot="╚${line}╝"

    echo >&2
    echo -e "${ORANGE}${BOLD}${top}${RESET}" >&2

    local title_len=${#title}
    local pad_left=$(( (inner - title_len) / 2 ))
    local pad_right=$(( inner - title_len - pad_left ))
    printf "${ORANGE}${BOLD}║%*s%s%*s║${RESET}\n" "$pad_left" "" "$title" "$pad_right" "" >&2

    echo -e "${ORANGE}${BOLD}${mid}${RESET}" >&2

    local content_width=$((inner - 2))
    while IFS= read -r wline; do
        printf "${ORANGE}${BOLD}║${RESET} ${ORANGE}%-*s${RESET} ${ORANGE}${BOLD}║${RESET}\n" "$content_width" "$wline" >&2
    done <<< "$(fold -s -w "$content_width" <<< "$message")"

    echo -e "${ORANGE}${BOLD}${bot}${RESET}" >&2
    echo >&2
}

error_box() {
    local title="${1:-ERROR}"
    local message="$2"
    local width
    width=$(tput cols 2>/dev/null || echo "$COLUMNS")
    width=${width:-80}
    (( width > 100 )) && width=100

    local inner=$((width - 2))
    local line=""
    line=$(printf '═%.0s' $(seq 1 "$inner"))

    local top="╔${line}╗"
    local mid="╠${line}╣"
    local bot="╚${line}╝"

    echo >&2
    echo -e "${RED}${BOLD}${top}${RESET}" >&2

    local title_len=${#title}
    local pad_left=$(( (inner - title_len) / 2 ))
    local pad_right=$(( inner - title_len - pad_left ))
    printf "${RED}${BOLD}║%*s%s%*s║${RESET}\n" "$pad_left" "" "$title" "$pad_right" "" >&2

    echo -e "${RED}${BOLD}${mid}${RESET}" >&2

    local content_width=$((inner - 2))
    while IFS= read -r wline; do
        printf "${RED}${BOLD}║${RESET} ${RED}%-*s${RESET} ${RED}${BOLD}║${RESET}\n" "$content_width" "$wline" >&2
    done <<< "$(fold -s -w "$content_width" <<< "$message")"

    echo -e "${RED}${BOLD}${bot}${RESET}" >&2
    echo >&2
}

section() {
    echo -e "  ${PURPLE}${BOLD}▸ ${1}${RESET}"
}



separator() { echo -e "${CYAN}──────────────────────────────────────────────────────────${RESET}"; }
