#!/usr/bin/env bash
download_stage3() {
    local mp="${CONFIG[MOUNT_POINT]}"
    cd "$mp"
    local variant=$([[ "${CONFIG[INIT_SYSTEM]}" == "systemd" ]] && echo "systemd" || echo "openrc")
    
    # Try multiple mirrors
    local mirrors=(
        "https://distfiles.gentoo.org/releases/amd64/autobuilds"
        "https://mirror.leaseweb.com/gentoo/releases/amd64/autobuilds"
        "https://gentoo.osuosl.org/releases/amd64/autobuilds"
    )
    
    local download_url=""
    local latest=""
    
    for mirror in "${mirrors[@]}"; do
        log_info "Trying mirror: $mirror"
        
        local latest_url="${mirror}/latest-stage3-amd64-${variant}.txt"
        local latest_content=$(curl -s --connect-timeout 10 "$latest_url")
        
        if [[ -n "$latest_content" ]]; then
            latest=$(echo "$latest_content" | grep -v "^#" | grep -v "^$" | awk '{print $1}' | head -n1)
            if [[ -n "$latest" ]]; then
                download_url="${mirror}/${latest}"
                log_success "Found stage3: $latest"
                break
            fi
        fi
    done
    
    if [[ -z "$download_url" ]]; then
        log_error "Failed to find stage3 from any mirror"
        return 1
    fi
    
    log_info "Downloading: $download_url"
    
    # Try downloading with better error handling
    if command -v wget &>/dev/null; then
        if ! wget --timeout=30 --tries=3 --show-progress -O "stage3.tar.xz" "$download_url"; then
            log_error "Failed to download stage3 with wget"
            return 1
        fi
    elif command -v curl &>/dev/null; then
        if ! curl -L --connect-timeout 30 --retry 3 --progress-bar -o "stage3.tar.xz" "$download_url"; then
            log_error "Failed to download stage3 with curl"
            return 1
        fi
    else
        log_error "Neither wget nor curl available for download"
        return 1
    fi
    
    # Verify the file was downloaded
    if [[ ! -f "stage3.tar.xz" ]]; then
        log_error "Downloaded file not found"
        return 1
    fi
    
    # Check file size (should be at least 100MB)
    local file_size=$(stat -c%s "stage3.tar.xz" 2>/dev/null || stat -f%z "stage3.tar.xz" 2>/dev/null || echo "0")
    if [[ $file_size -lt 104857600 ]]; then
        log_error "Downloaded file seems too small (${file_size} bytes)"
        rm -f "stage3.tar.xz"
        return 1
    fi
    
    CONFIG[STAGE3_FILE]="$mp/stage3.tar.xz"
    log_success "Downloaded stage3 successfully ($((file_size/1024/1024)) MB)"
}

extract_stage3() {
    cd "${CONFIG[MOUNT_POINT]}"
    
    # Verify the stage3 file exists and is valid
    if [[ ! -f "${CONFIG[STAGE3_FILE]}" ]]; then
        log_error "Stage3 file not found: ${CONFIG[STAGE3_FILE]}"
        return 1
    fi
    
    log_info "Verifying stage3 archive..."
    if ! tar -tf "${CONFIG[STAGE3_FILE]}" &>/dev/null; then
        log_error "Stage3 archive appears to be corrupt or invalid"
        return 1
    fi
    
    log_info "Extracting stage3 (this may take a while)..."
    if ! tar xpf "${CONFIG[STAGE3_FILE]}" --xattrs-include='*.*' --numeric-owner; then
        log_error "Failed to extract stage3 archive"
        return 1
    fi
    
    # Clean up
    rm -f "${CONFIG[STAGE3_FILE]}"
    log_success "Stage3 extracted successfully"
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
