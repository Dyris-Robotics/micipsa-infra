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
# Every image built by install_docker_images.sh is named micipsa/*
MICIPSA_IMAGES_FILTER="micipsa/*"
MICIPSA_IMAGES=()

# =============================================================================
#  PREVIEW FUNCTIONS
# =============================================================================
show_context() {

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  Docker Uninstall Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo -e "  ${GREEN}${BOLD}Platform: ${RESET} ${PLATFORM}"
    echo ""

    section "Docker"
    echo -e "  ${GREEN}${BOLD}Containers Removed: ${RESET} every container running a ${MICIPSA_IMAGES_FILTER} image"
    echo -e "  ${GREEN}${BOLD}Images Removed: ${RESET} ${MICIPSA_IMAGES_FILTER} (foundation + service images)"
    echo -e "  ${GREEN}${BOLD}Docker Engine: ${RESET} asked separately, kept if you answer n"
    echo ""

    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  DOCKER IMAGES FUNCTIONS
# =============================================================================
is_docker_available(){
    banner "Checking Docker"

    if ! command -v docker &>/dev/null; then
        info "Docker not installed, no images or containers to remove."
        return 1
    fi

    success "Docker found: $(docker --version)"
    return 0
}

is_docker_images_available(){
    banner "Checking Micipsa Docker Images"

    mapfile -t MICIPSA_IMAGES < <(
        docker images --format '{{.Repository}}:{{.Tag}}' --filter "reference=${MICIPSA_IMAGES_FILTER}" | sort -u
    )

    if [[ ${#MICIPSA_IMAGES[@]} -eq 0 ]]; then
        info "No ${MICIPSA_IMAGES_FILTER} images found."
        return 1
    fi

    local image
    for image in "${MICIPSA_IMAGES[@]}"; do
        success "Found: ${image}"
    done
    return 0
}

docker_containers_removal(){
    banner "Removing Micipsa Containers"

    local image
    local containers=()
    local found=0

    for image in "${MICIPSA_IMAGES[@]}"; do
        mapfile -t containers < <(docker ps -aq --filter "ancestor=${image}")
        if [[ ${#containers[@]} -gt 0 ]]; then
            docker rm -f "${containers[@]}" >/dev/null
            success "Removed ${#containers[@]} container(s) using ${image}"
            found=1
        fi
    done

    if [[ ${found} -eq 0 ]]; then
        info "No containers using ${MICIPSA_IMAGES_FILTER} images"
    fi
}

docker_images_removal(){
    banner "Removing Micipsa Docker Images"

    local image
    for image in "${MICIPSA_IMAGES[@]}"; do
        [[ "${image}" == micipsa/base:* ]] && continue
        docker rmi "${image}" >/dev/null
        success "Removed: ${image}"
    done
    for image in "${MICIPSA_IMAGES[@]}"; do
        [[ "${image}" == micipsa/base:* ]] || continue
        docker rmi "${image}" >/dev/null
        success "Removed: ${image}"
    done

    info "Removing dangling build layers..."
    docker image prune -f >/dev/null
    success "Dangling layers removed"
}

# =============================================================================
#  DOCKER ENGINE FUNCTIONS
# =============================================================================
remove_docker_group(){
    if [[ -n "${CURRENT_USER:-}" ]] && id -nG "${CURRENT_USER}" 2>/dev/null | grep -qw docker; then
        gpasswd -d "${CURRENT_USER}" docker >/dev/null
        success "Removed '${CURRENT_USER}' from the docker group"
    fi

    if getent group docker >/dev/null 2>&1; then
        groupdel docker
        success "Removed docker group"
    fi
}

uninstall_docker_engine(){
    banner "Docker Engine"

    warn "Removing the Docker Engine affects every Docker project on this machine."
    if ! confirm "Also uninstall the Docker Engine?"; then
        info "Docker Engine kept"
        return 0
    fi

    export DEBIAN_FRONTEND=noninteractive

    systemctl disable --now docker.service docker.socket containerd.service 2>/dev/null || true

    apt purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras
    apt autoremove -y

    rm -f /etc/apt/sources.list.d/docker.sources
    rm -f /etc/apt/keyrings/docker.asc
    apt update
    success "Docker Engine uninstalled"

    remove_docker_group

    warn "Docker data was left in /var/lib/docker and /var/lib/containerd, remove them manually if no longer needed."
}

docker_uninstall(){
    if ! is_docker_available; then
        return 0
    fi

    if is_docker_images_available; then
        docker_containers_removal
        docker_images_removal
    fi

    uninstall_docker_engine
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
    require_root
    setup_error_traps

    PLATFORM="$(detect_platform)"
    robot_system_config_load
    show_context

    docker_uninstall

    exit "${EXIT_SUCCESS}"
}

main "$@"
