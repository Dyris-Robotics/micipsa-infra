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
    echo -e "${BOLD}${CYAN}  Docker Setup Configuration${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo ""
    section "General"
    echo -e "  ${GREEN}${BOLD}Current User: ${RESET} ${CURRENT_USER}"
    echo -e "  ${GREEN}${BOLD}Robot Name: ${RESET} ${ROBOT_NAME}"
    echo -e "  ${GREEN}${BOLD}Platform: ${RESET} ${PLATFORM}"
    echo -e "  ${GREEN}${BOLD}Infra Repository Location: ${RESET} ${INFRA_ROOT}"
    echo ""

    section "Docker"
    echo -e "  ${GREEN}${BOLD}Docker Files Directory: ${RESET} ${DOCKER_DIR}"
    echo -e "  ${GREEN}${BOLD}Docker Foundation Dockerfile: ${RESET} ${FOUNDATION_DOCKERFILE}"
    echo -e "  ${GREEN}${BOLD}Docker Compose Base File: ${RESET} ${DOCKER_COMPOSE_FILE}"
    echo -e "  ${GREEN}${BOLD}Docker Compose Deploy File: ${RESET} ${DOCKER_COMPOSE_DEPLOY}"
    echo ""

    section "Robot Software Stack"
    echo -e "  ${GREEN}${BOLD}Software Stack Repository: ${RESET} ${REPO_ROOT}"
    echo ""


    confirm_or_skip "Proceed with these values?"

    return 0
}

# =============================================================================
#  DOCKER FUNCTIONS
# =============================================================================

add_docker_group(){
    groupadd docker 2>/dev/null || true

    # Add Current user to docker group if not already in it
    if [[ -n "${CURRENT_USER:-}" ]] && ! id -nG "${CURRENT_USER}" | grep -qw docker; then
        usermod -aG docker "${CURRENT_USER}"
        warn "Added '${CURRENT_USER}' to the docker group, re-login required to take effect"
    fi
}

enable_docker_services(){
    systemctl enable docker.service
    systemctl enable containerd.service
}

install_docker(){
    if command -v docker &>/dev/null; then
        success "Docker already installed: $(docker --version)"
    else
        info "Docker not found, installing via apt repository…"
        export DEBIAN_FRONTEND=noninteractive

        # Remove conflicting packages
        info "Removing any conflicting Docker-related packages…"
        apt remove -y $(dpkg --get-selections \
            docker.io docker-compose docker-compose-v2 \
            docker-doc podman-docker containerd runc \
            2>/dev/null | cut -f1) 2>/dev/null || true

        apt update
        apt install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

        apt update
        apt install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin

        systemctl start docker

        success "Docker installed: $(docker --version)"
    fi

    # Post-installation
    add_docker_group
    enable_docker_services
    success "Docker and containerd enabled on boot"
}

is_docker_compose_files_available(){
    if [[ ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        error "Docker compose file not found at ${DOCKER_COMPOSE_FILE}"
        exit "${EXIT_FAILURE}"
    fi

    if [[ ! -f "${DOCKER_COMPOSE_DEPLOY}" ]]; then
        error "Docker deploy overlay file not found at ${DOCKER_COMPOSE_DEPLOY}"
        exit "${EXIT_FAILURE}"
    fi
    
    return 0
}

docker_os_base_image_selection(){
    if [[ "${PLATFORM}" == "aarch64" ]]; then
        DOCKER_OS_BASE_IMAGE="${DOCKER_OS_BASE_IMAGE_ARM}"
        info "aarch64 detected, using ARM base image: ${DOCKER_OS_BASE_IMAGE}"

    elif [[ "${PLATFORM}" == "x86_64" ]]; then
        DOCKER_OS_BASE_IMAGE="${DOCKER_OS_BASE_IMAGE_X86}"
        info "x86_64 detected, using base image: ${DOCKER_OS_BASE_IMAGE}"

    else
        error "Unsupported platform: ${PLATFORM}"
        exit "${EXIT_FAILURE}"
    fi
}

docker_build_foundation_image(){
    # All service Dockerfiles do "FROM micipsa/base:foundation" so this must exist first.
    if [[ ! -f "${FOUNDATION_DOCKERFILE}" ]]; then
        error "Foundation Dockerfile not found at ${FOUNDATION_DOCKERFILE}"
        exit "${EXIT_FAILURE}"
    fi

    info "Building Foundation image micipsa/base:foundation"
    docker build \
        --build-arg BASE_IMAGE="${DOCKER_OS_BASE_IMAGE}" \
        -t micipsa/base:foundation \
        -f "${FOUNDATION_DOCKERFILE}" \
        "${INFRA_ROOT}"
    success "Foundation Docker image built"
}

docker_build_child_images(){
    # Must run from docker/ so compose file-relative paths resolve correctly.
    info "Building service images (base + deploy overlay)…"

    # Tell compose where the micipsa repo lives
    export MICIPSA_REPO_ROOT="${REPO_ROOT}"

    # Extract profiles names
    local profiles
    profiles=$(
        cd "${DOCKER_DIR}" && docker compose \
            -f "${DOCKER_COMPOSE_FILE}" \
            -f "${DOCKER_COMPOSE_DEPLOY}" \
            config --profiles 2>/dev/null | sed 's/^/--profile /' | tr '\n' ' '
    )

    # Build all child images
    (cd "${DOCKER_DIR}" && docker compose \
        -f "${DOCKER_COMPOSE_FILE}" \
        -f "${DOCKER_COMPOSE_DEPLOY}" \
        ${profiles} \
        build)

    success "Docker images built"
}

docker_images_build() {
    is_docker_compose_files_available
    docker_os_base_image_selection
    docker_build_foundation_image
    docker_build_child_images
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

	install_docker
	docker_images_build	

    exit "${EXIT_SUCCESS}"
}

main "$@"