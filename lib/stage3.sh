#!/usr/bin/env bash
download_stage3() {
    local mp="${CONFIG[MOUNT_POINT]}"
    cd "$mp"
    local variant=$([[ "${CONFIG[INIT_SYSTEM]}" == "systemd" ]] && echo "systemd" || echo "openrc")
    
    # Try multiple mirrors with better error handling
    local mirrors=(
        "https://distfiles.gentoo.org/releases/amd64/autobuilds"
        "https://mirror.leaseweb.com/gentoo/releases/amd64/autobuilds"
        "https://gentoo.osuosl.org/releases/amd64/autobuilds"
        "https://archive.mirror.ksu.edu/gentoo/releases/amd64/autobuilds"
    )
    
    local download_url=""
    local stage3_filename=""
    
    # First, try to get the latest stage3 info from mirrors
    for mirror in "${mirrors[@]}"; do
        log_info "Trying mirror: $mirror"
        
        local latest_url="${mirror}/latest-stage3-amd64-${variant}.txt"
        log_info "Fetching latest stage3 info from: $latest_url"
        
        # Try multiple methods to fetch the latest info
        local latest_content=""
        
        # Method 1: curl with verbose error reporting
        if command -v curl &>/dev/null; then
            log_info "Trying with curl..."
            latest_content=$(curl -f -L --connect-timeout 20 --max-time 30 -w "\n%{http_code}" "$latest_url" 2>/dev/null)
            local http_code=$(echo "$latest_content" | tail -n1)
            latest_content=$(echo "$latest_content" | sed '$d')  # Remove last line (HTTP code)
            
            case $http_code in
                200|201|202|203|204|205|206)
                    log_success "curl: HTTP $http_code - Success"
                    ;;
                404)
                    log_error "curl: HTTP $http_code - File not found. Check if variant '$variant' exists."
                    continue
                    ;;
                403)
                    log_error "curl: HTTP $http_code - Access forbidden. Check URL."
                    continue
                    ;;
                000)
                    log_error "curl: HTTP $http_code - Connection failed. Check network."
                    continue
                    ;;
                *)
                    log_error "curl: HTTP $http_code - Request failed."
                    continue
                    ;;
            esac
        fi
        
        # Method 2: wget as fallback
        if [[ -z "$latest_content" ]] && command -v wget &>/dev/null; then
            log_info "Trying with wget..."
            latest_content=$(wget --timeout=30 -q -O - --server-response "$latest_url" 2>&1)
            local http_code=$(echo "$latest_content" | grep "HTTP/" | tail -n1 | awk '{print $2}')
            latest_content=$(echo "$latest_content" | sed '/HTTP\//d')
            
            case $http_code in
                200|201|202|203|204|205|206)
                    log_success "wget: HTTP $http_code - Success"
                    ;;
                404)
                    log_error "wget: HTTP $http_code - File not found. Check if variant '$variant' exists."
                    continue
                    ;;
                403)
                    log_error "wget: HTTP $http_code - Access forbidden. Check URL."
                    continue
                    ;;
                *)
                    log_error "wget: HTTP $http_code - Request failed."
                    continue
                    ;;
            esac
        fi
        
        # If we got content, try to parse it
        if [[ -n "$latest_content" ]]; then
            log_info "Successfully fetched latest stage3 info"
            
            # Debug: show the entire content for troubleshooting
            log_info "Response content:"
            echo "$latest_content" | head -n 10
            
            # Parse the latest stage3 filename from the content
            # The format is: timestamp stage3-filename size hash
            # We want the SECOND field (filename), not the first
            stage3_filename=$(echo "$latest_content" | grep -v "^#" | grep "stage3-amd64-${variant}" | awk '{print $2}' | head -n1)
            
            # If second field is empty, try first field (fallback)
            if [[ -z "$stage3_filename" ]]; then
                stage3_filename=$(echo "$latest_content" | grep -v "^#" | grep "stage3-amd64-${variant}" | awk '{print $1}' | head -n1)
            fi
            
            if [[ -n "$stage3_filename" ]]; then
                download_url="${mirror}/${stage3_filename}"
                log_success "Found latest stage3: $stage3_filename"
                log_info "Download URL: $download_url"
                break
            else
                log_error "Could not parse stage3 filename from mirror response"
                log_error "Looking for pattern: stage3-amd64-${variant}"
                log_error "Available stage3 files in response:"
                echo "$latest_content" | grep "stage3-amd64" | head -n 5 | while read line; do
                    log_error "  Line: $line"
                    log_error "  Field 1: $(echo "$line" | awk '{print $1}')"
                    log_error "  Field 2: $(echo "$line" | awk '{print $2}')"
                done
            fi
        else
            log_info "No response from mirror: $mirror"
        fi
    done
    
    # If we couldn't find a download URL, show detailed error
    if [[ -z "$download_url" ]]; then
        show_error "Failed to find stage3 from any mirror"
        log_error "Please check:"
        log_error "  - Internet connection"
        log_error "  - The selected init system variant: '${variant}'"
        log_error "  - Available variants at: https://distfiles.gentoo.org/releases/amd64/autobuilds/"
        
        # Show what variants are actually available
        log_info "Checking available variants..."
        if command -v curl &>/dev/null; then
            local available_variants=$(curl -s -L https://distfiles.gentoo.org/releases/amd64/autobuilds/ | grep -o "latest-stage3-amd64-[a-z]*.txt" | sort -u)
            if [[ -n "$available_variants" ]]; then
                log_info "Available variants:"
                echo "$available_variants" | while read variant_file; do
                    log_info "  ${variant_file}"
                done
            else
                log_error "Could not determine available variants"
            fi
        fi
        
        return 1
    fi
    
    # Now download the stage3 archive
    log_info "Downloading stage3 archive: $download_url"
    
    # Try multiple download methods with better error handling
    local download_success=0
    local download_method=""
    
    # Method 1: wget with detailed error reporting
    if command -v wget &>/dev/null; then
        log_info "Trying download with wget..."
        if wget --timeout=60 --tries=3 --show-progress -O "stage3.tar.xz.tmp" "$download_url"; then
            download_success=1
            download_method="wget"
        else
            local exit_code=$?
            log_error "wget failed with exit code: $exit_code"
            case $exit_code in
                1) log_error "Generic error code" ;;
                2) log_error "Parse error" ;;
                3) log_error "File I/O error" ;;
                4) log_error "Network failure" ;;
                5) log_error "SSL verification failure" ;;
                6) log_error "Username/password authentication failure" ;;
                7) log_error "Protocol errors" ;;
                8) log_error "Server issued an error response (HTTP 4xx/5xx)" ;;
                *) log_error "Unknown error" ;;
            esac
            # Keep temporary file for inspection if needed
            [[ -f "stage3.tar.xz.tmp" ]] && log_info "Temporary file size: $(stat -c%s stage3.tar.xz.tmp 2>/dev/null || echo "unknown") bytes"
        fi
    fi
    
    # Method 2: curl as fallback
    if [[ $download_success -eq 0 ]] && command -v curl &>/dev/null; then
        log_info "Trying download with curl..."
        if curl -L --connect-timeout 60 --retry 3 --max-time 300 --progress-bar -o "stage3.tar.xz.tmp" "$download_url"; then
            download_success=1
            download_method="curl"
        else
            local exit_code=$?
            log_error "curl failed with exit code: $exit_code"
            # Keep temporary file for inspection
            [[ -f "stage3.tar.xz.tmp" ]] && log_info "Temporary file size: $(stat -c%s stage3.tar.xz.tmp 2>/dev/null || echo "unknown") bytes"
        fi
    fi
    
    # If both methods failed
    if [[ $download_success -eq 0 ]]; then
        log_error "All download methods failed"
        
        # Check if we have a partial download
        if [[ -f "stage3.tar.xz.tmp" ]]; then
            local partial_size=$(stat -c%s "stage3.tar.xz.tmp" 2>/dev/null || echo "0")
            log_error "Partial download available: ${partial_size} bytes"
            log_info "You can try to resume with:"
            log_info "  wget -c -O stage3.tar.xz $download_url"
            log_info "  or"
            log_info "  curl -L -C - -o stage3.tar.xz $download_url"
            
            # Offer to keep the partial file
            if show_yesno "Keep partial download for manual resume?"; then
                mv "stage3.tar.xz.tmp" "stage3.tar.xz"
                log_success "Partial download saved as stage3.tar.xz"
                return 1
            else
                rm -f "stage3.tar.xz.tmp"
            fi
        fi
        
        show_error "Download failed. Please check your internet connection and firewall settings."
        return 1
    fi
    
    # Rename the temporary file to final name
    mv "stage3.tar.xz.tmp" "stage3.tar.xz"
    
    # Verify the file was downloaded correctly
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
        show_error "Downloaded file is incomplete. Please try again."
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
    
    # Try to fetch and display the latest URLs automatically
    log_info "Attempting to fetch latest stage3 URLs for you..."
    if command -v curl &>/dev/null; then
        local latest_content=$(curl -s "$example_url" 2>/dev/null || echo "")
        if [[ -n "$latest_content" ]]; then
            show_info "Latest available stage3 files:"
            echo "$latest_content" | grep "stage3-amd64-${variant}" | head -n 3 | while read line; do
                local filename=$(echo "$line" | awk '{print $2}')
                if [[ -n "$filename" ]]; then
                    show_info "  https://distfiles.gentoo.org/releases/amd64/autobuilds/${filename}"
                fi
            done
        fi
    fi
    
    # Offer to browse with alternative methods if lynx is not available
    if command -v lynx &>/dev/null; then
        if show_yesno "Would you like to browse available stage3 files using lynx?"; then
            log_info "Opening lynx browser to browse stage3 files..."
            local base_url="https://distfiles.gentoo.org/releases/amd64/autobuilds/"
            if lynx "$base_url"; then
                log_info "Lynx browser closed. You can now enter the URL you found."
            else
                log_error "Lynx browser failed to start"
            fi
        fi
    else
        log_info "Note: Install 'lynx' to browse stage3 files directly in the terminal"
        # Offer alternative: show directory listing with curl
        if command -v curl &>/dev/null && show_yesno "Would you like to see the directory listing with curl instead?"; then
            log_info "Fetching directory listing..."
            local dir_listing=$(curl -s https://distfiles.gentoo.org/releases/amd64/autobuilds/ | grep -o 'href="[^"]*stage3-amd64[^"]*.tar.xz"' | head -n 10)
            if [[ -n "$dir_listing" ]]; then
                show_info "Available stage3 files:"
                echo "$dir_listing" | sed 's/href="/  /' | sed 's/"$//' | while read file; do
                    show_info "https://distfiles.gentoo.org/releases/amd64/autobuilds/$file"
                done
            else
                log_error "Could not fetch directory listing"
            fi
        fi
    fi
    
    show_info "Example: Visit $example_url to find the latest URL"
    show_info "Format should be: https://distfiles.gentoo.org/releases/amd64/autobuilds/YYYYMMDDTHHMMSSZ/stage3-amd64-${variant}-YYYYMMDDTHHMMSSZ.tar.xz"
    
    local manual_url
    manual_url=$(show_input "Enter stage3 URL:" "")
    
    if [[ -z "$manual_url" ]]; then
        log_error "No URL provided"
        return 1
    fi
    
    log_info "Downloading from manual URL: $manual_url"
    
    # Use temporary file for download to avoid corrupting existing file
    local download_success=0
    local download_method=""
    
    # Try wget first
    if command -v wget &>/dev/null; then
        log_info "Trying download with wget..."
        if wget --timeout=60 --tries=3 --show-progress -O "stage3.tar.xz.tmp" "$manual_url"; then
            download_success=1
            download_method="wget"
        else
            log_error "Manual download failed with wget (exit code: $?)"
            [[ -f "stage3.tar.xz.tmp" ]] && log_info "Partial download size: $(stat -c%s stage3.tar.xz.tmp 2>/dev/null || echo "unknown") bytes"
        fi
    fi
    
    # Try curl if wget failed or not available
    if [[ $download_success -eq 0 ]] && command -v curl &>/dev/null; then
        log_info "Trying download with curl..."
        if curl -L --connect-timeout 60 --retry 3 --progress-bar -o "stage3.tar.xz.tmp" "$manual_url"; then
            download_success=1
            download_method="curl"
        else
            log_error "Manual download failed with curl (exit code: $?)"
            [[ -f "stage3.tar.xz.tmp" ]] && log_info "Partial download size: $(stat -c%s stage3.tar.xz.tmp 2>/dev/null || echo "unknown") bytes"
        fi
    fi
    
    # If both methods failed
    if [[ $download_success -eq 0 ]]; then
        log_error "Manual download failed with all available methods"
        rm -f "stage3.tar.xz.tmp"
        return 1
    fi
    
    # Verify file size
    local file_size
    if command -v stat &>/dev/null; then
        file_size=$(stat -c%s "stage3.tar.xz.tmp" 2>/dev/null || echo "0")
    else
        file_size="0"
    fi
    
    if [[ $file_size -gt 104857600 ]]; then
        # Rename temporary file to final name
        mv "stage3.tar.xz.tmp" "stage3.tar.xz"
        CONFIG[STAGE3_FILE]="$mp/stage3.tar.xz"
        log_success "Manual download successful ($((file_size/1024/1024)) MB)"
        return 0
    else
        log_error "Downloaded file too small (${file_size} bytes)"
        rm -f "stage3.tar.xz.tmp"
        return 1
    fi
}

# Function to browse and select stage3 using lynx
browse_stage3_with_lynx() {
    local variant=$([[ "${CONFIG[INIT_SYSTEM]}" == "systemd" ]] && echo "systemd" || echo "openrc")
    local base_url="https://distfiles.gentoo.org/releases/amd64/autobuilds/"
    
    show_info "Opening lynx browser to browse stage3 files..."
    show_info "Navigate to find: stage3-amd64-${variant}-YYYYMMDDTHHMMSSZ.tar.xz"
    show_info "Press 'q' to quit lynx, then enter the URL below."
    
    if lynx "$base_url"; then
        local selected_url=$(show_input "Enter the full URL of the stage3 file you found:" "")
        if [[ -n "$selected_url" ]]; then
            echo "$selected_url"
            return 0
        else
            log_error "No URL provided"
            return 1
        fi
    else
        log_error "Failed to start lynx browser"
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
