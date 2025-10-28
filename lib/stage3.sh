#!/usr/bin/env bash
download_stage3() {
    local mp="${CONFIG[MOUNT_POINT]}"
    cd "$mp"
    local variant=$([[ "${CONFIG[INIT_SYSTEM]}" == "systemd" ]] && echo "systemd" || echo "openrc")
    local mirror="https://distfiles.gentoo.org/releases/amd64/autobuilds"
    
    log_info "Fetching latest stage3 URL for ${variant}..."
    local latest=$(curl -s "${mirror}/latest-stage3-amd64-${variant}.txt" | grep -v "^#" | awk '{print $1}' | head -n1)
    
    if [[ -z "$latest" ]]; then
        log_error "Failed to find latest stage3 URL"
        return 1
    fi
    
    log_info "Downloading: $latest"
    if ! wget -q --show-progress "${mirror}/${latest}"; then
        log_error "Failed to download stage3"
        return 1
    fi
    
    CONFIG[STAGE3_FILE]="$mp/$(basename "$latest")"
    log_success "Downloaded stage3 successfully"
}

extract_stage3() {
    cd "${CONFIG[MOUNT_POINT]}"
    tar xpf "${CONFIG[STAGE3_FILE]}" --xattrs-include='*.*' --numeric-owner
    rm "${CONFIG[STAGE3_FILE]}"
    log_success "Extracted"
}

configure_makeconf() {
    local mp="${CONFIG[MOUNT_POINT]}"
    local cores=$(get_cpu_cores)
    cat >> "${mp}/etc/portage/make.conf" << EOF

COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
MAKEOPTS="-j${cores}"
EMERGE_DEFAULT_OPTS="--jobs=${cores} --with-bdeps=y"
ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"
GRUB_PLATFORMS="$([[ "${CONFIG[BOOT_MODE]}" == "efi" ]] && echo "efi-64" || echo "pc")"
USE="dist-kernel"
EOF
    log_success "make.conf configured"
}
