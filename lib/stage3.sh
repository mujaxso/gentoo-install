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
    local stage3_filename=""
    
    for mirror in "${mirrors[@]}"; do
        log_info "Trying mirror: $mirror"
        
        local latest_url="${mirror}/latest-stage3-amd64-${variant}.txt"
        log_info "Fetching latest stage3 info from: $latest_url"
        
        # Get the latest stage3 information file
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
            log_info "Successfully fetched latest stage3 info"
            # Debug: show first few lines of content
            log_info "First few lines of response:"
            echo "$latest_content" | head -n 3 | while read line; do
                log_info "  $line"
            done
        
            # Parse the latest stage3 filename from the content
            # The format is: timestamp stage3-filename size hash
            # We want the first field (filename)
            stage3_filename=$(echo "$latest_content" | grep -v "^#" | grep "stage3-amd64-${variant}" | awk '{print $1}' | head -n1)
        
            if [[ -n "$stage3_filename" ]]; then
                download_url="${mirror}/${stage3_filename}"
                log_success "Found latest stage3: $stage3_filename"
                break
            else
                log_error "Could not parse stage3 filename from mirror response"
                log_error "Looking for pattern: stage3-amd64-${variant}"
                log_error "Available stage3 files in response:"
                echo "$latest_content" | grep "stage3-amd64" | head -n 5 | while read line; do
                    log_error "  $line"
                done
            fi
        else
            log_info "No response from mirror: $mirror"
        fi
    done
    
    if [[ -z "$download_url" ]]; then
        show_error "Failed to find stage3 from any mirror"
        log_error "Please check:"
        log_error "  - Internet connection"
        log_error "  - Gentoo mirror availability"
        log_error "  - The variant '${variant}' exists"
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
    local mp="${CONFIG[MOUNT_POINT]}"
    cd "$mp"
    
    # Verify the stage3 file exists and is valid
    if [[ ! -f "${CONFIG[STAGE3_FILE]}" ]]; then
        log_error "Stage3 file not found: ${CONFIG[STAGE3_FILE]}"
        return 1
    fi
    
    # Check available disk space
    local available_space=$(df "$mp" | awk 'NR==2 {print $4}')
    local stage3_size=$(stat -c%s "${CONFIG[STAGE3_FILE]}" 2>/dev/null || echo "0")
    local required_space=$((stage3_size * 3))  # Need about 3x the archive size for extraction
    
    log_info "Available space: $((available_space / 1024)) MB"
    log_info "Stage3 size: $((stage3_size / 1024 / 1024)) MB"
    log_info "Required space: $((required_space / 1024 / 1024)) MB (approx)"
    
    if [[ $available_space -lt $required_space ]]; then
        show_error "Not enough disk space for extraction!"
        log_error "Available: $((available_space / 1024)) MB"
        log_error "Required: ~$((required_space / 1024 / 1024)) MB"
        log_error "Please ensure your root partition has at least 10GB free space"
        return 1
    fi
    
    # Verify we're in the correct directory and it's mounted properly
    log_info "Current directory: $(pwd)"
    log_info "Mount point: $mp"
    log_info "Mount status:"
    df -h "$mp" || log_error "Cannot check mount status"
    
    log_info "Verifying stage3 archive..."
    if ! tar -tf "${CONFIG[STAGE3_FILE]}" &>/dev/null; then
        log_error "Stage3 archive appears to be corrupt or invalid"
        return 1
    fi
    
    # Verify we're extracting to the correct mounted filesystem
    local mount_info=$(mount | grep " $mp ")
    if [[ -z "$mount_info" ]]; then
        log_error "Mount point $mp is not mounted! Cannot extract stage3."
        log_error "Current mounts:"
        mount | grep "$mp" || log_error "No mounts found for $mp"
        return 1
    fi
    
    log_info "Extracting stage3 to: $mp (mounted on: $(echo "$mount_info" | awk '{print $1}'))"
    log_info "Extracting stage3 (this may take a while)..."
    
    # Extract with better error handling
    if ! tar xpf "${CONFIG[STAGE3_FILE]}" --xattrs-include='*.*' --numeric-owner; then
        log_error "Failed to extract stage3 archive"
        
        # Check disk space again after failure
        local final_space=$(df "$mp" | awk 'NR==2 {print $4}')
        log_error "Remaining space after failure: $((final_space / 1024)) MB"
        
        # Check what's using space
        log_error "Largest directories in $mp:"
        du -sh "$mp"/* 2>/dev/null | sort -hr | head -n 10 || log_error "Cannot check directory sizes"
        
        return 1
    fi
    
    # Clean up
    rm -f "${CONFIG[STAGE3_FILE]}"
    log_success "Stage3 extracted successfully"
    
    # Verify extraction by checking some key directories
    if [[ ! -d "$mp/etc" ]] || [[ ! -d "$mp/usr" ]]; then
        log_error "Extraction may be incomplete - key directories missing"
        return 1
    fi
}

# Fallback function for manual stage3 URL
download_stage3_manual() {
    local mp="${CONFIG[MOUNT_POINT]}"
    cd "$mp"
    
    show_info "Automatic stage3 download failed."
    show_info "You can manually provide a stage3 URL."
    
    # Show example URLs based on the selected init system
    local variant=$([[ "${CONFIG[INIT_SYSTEM]}" == "systemd" ]] && echo "systemd" || echo "openrc")
    local example_url="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-${variant}.txt"
    
    show_info "Example: Visit $example_url to find the latest URL"
    show_info "Format should be: https://distfiles.gentoo.org/releases/amd64/autobuilds/YYYYMMDDTHHMMSSZ/stage3-amd64-${variant}-YYYYMMDDTHHMMSSZ.tar.xz"
    
    local manual_url
    manual_url=$(show_input "Enter stage3 URL:" "")
    
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
