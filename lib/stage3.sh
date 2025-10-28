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
        log_info "Fetching: $latest_url"
        
        # Use curl with verbose output for debugging
        local latest_content
        if command -v curl &>/dev/null; then
            latest_content=$(curl -f -L --connect-timeout 20 --max-time 30 "$latest_url" 2>/dev/null || echo "")
        elif command -v wget &>/dev/null; then
            latest_content=$(wget --timeout=30 -q -O - "$latest_url" 2>/dev/null || echo "")
        else
            log_error "Neither curl nor wget available"
            return 1
        fi
        
        if [[ -n "$latest_content" ]]; then
            # Better parsing - look for lines that start with stage3
            latest=$(echo "$latest_content" | grep -E "^[^#].*stage3.*${variant}.*\.tar\.xz" | awk '{print $1}' | head -n1)
            if [[ -n "$latest" ]]; then
                download_url="${mirror}/${latest}"
                log_success "Found stage3: $latest"
                break
            else
                log_info "Could not parse stage3 filename from mirror response"
                log_info "Response preview: $(echo "$latest_content" | head -n 5)"
            fi
        else
            log_info "No response from mirror: $mirror"
        fi
    done
    
    if [[ -z "$download_url" ]]; then
        show_error "Failed to find stage3 from any mirror"
        log_error "Please check:"
        log_error "  - Internet connection"
        log_error "  - Firewall settings"
        log_error "  - DNS resolution"
        log_error "  - Try accessing https://distfiles.gentoo.org/releases/amd64/autobuilds/ manually"
        return 1
    fi
    
    log_info "Downloading: $download_url"
    
    # Show download progress and handle errors better
    local download_success=0
    if command -v wget &>/dev/null; then
        if wget --timeout=60 --tries=3 --show-progress -O "stage3.tar.xz" "$download_url"; then
            download_success=1
        else
            log_error "Failed to download stage3 with wget (exit code: $?)"
        fi
    elif command -v curl &>/dev/null; then
        if curl -L --connect-timeout 60 --retry 3 --progress-bar -o "stage3.tar.xz" "$download_url"; then
            download_success=1
        else
            log_error "Failed to download stage3 with curl (exit code: $?)"
        fi
    else
        log_error "Neither wget nor curl available for download"
        return 1
    fi
    
    if [[ $download_success -eq 0 ]]; then
        show_error "Download failed. Please check your internet connection."
        return 1
    fi
    
    # Verify the file was downloaded
    if [[ ! -f "stage3.tar.xz" ]]; then
        log_error "Downloaded file not found"
        return 1
    fi
    
    # Check file size (should be at least 100MB)
    local file_size
    if command -v stat &>/dev/null; then
        file_size=$(stat -c%s "stage3.tar.xz" 2>/dev/null || echo "0")
    elif command -v ls &>/dev/null; then
        file_size=$(ls -l "stage3.tar.xz" 2>/dev/null | awk '{print $5}' || echo "0")
    else
        file_size="0"
    fi
    
    if [[ $file_size -lt 104857600 ]]; then
        log_error "Downloaded file seems too small (${file_size} bytes) - might be incomplete"
        log_error "Expected at least 100MB"
        rm -f "stage3.tar.xz"
        return 1
    fi
    
    CONFIG[STAGE3_FILE]="$mp/stage3.tar.xz"
    log_success "Downloaded stage3 successfully ($((file_size/1024/1024)) MB)"
    return 0
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

# Fallback function for manual stage3 URL
download_stage3_manual() {
    local mp="${CONFIG[MOUNT_POINT]}"
    cd "$mp"
    
    show_info "Automatic stage3 download failed."
    show_info "You can manually provide a stage3 URL."
    
    local manual_url
    manual_url=$(show_input "Enter stage3 URL:" "https://distfiles.gentoo.org/releases/amd64/autobuilds/")
    
    if [[ -z "$manual_url" ]]; then
        log_error "No URL provided"
        return 1
    fi
    
    log_info "Downloading from manual URL: $manual_url"
    
    local download_success=0
    if command -v wget &>/dev/null; then
        if wget --timeout=60 --tries=3 --show-progress -O "stage3.tar.xz" "$manual_url"; then
            download_success=1
        else
            log_error "Manual download failed with wget"
        fi
    elif command -v curl &>/dev/null; then
        if curl -L --connect-timeout 60 --retry 3 --progress-bar -o "stage3.tar.xz" "$manual_url"; then
            download_success=1
        else
            log_error "Manual download failed with curl"
        fi
    fi
    
    if [[ $download_success -eq 1 ]]; then
        # Verify file size
        local file_size
        if command -v stat &>/dev/null; then
            file_size=$(stat -c%s "stage3.tar.xz" 2>/dev/null || echo "0")
        else
            file_size="0"
        fi
        
        if [[ $file_size -gt 104857600 ]]; then
            CONFIG[STAGE3_FILE]="$mp/stage3.tar.xz"
            log_success "Manual download successful ($((file_size/1024/1024)) MB)"
            return 0
        else
            log_error "Downloaded file too small (${file_size} bytes)"
            rm -f "stage3.tar.xz"
            return 1
        fi
    else
        log_error "Manual download failed"
        return 1
    fi
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
