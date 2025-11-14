#!/bin/bash

# Stage File Selection Module - Updated for AMD64 Handbook

STAGE_CONFIG_FILE="/tmp/gentoo-stage-config"

declare -gA STAGE_CONFIG
STAGE_CONFIG[mirror]="https://distfiles.gentoo.org"
STAGE_CONFIG[stage_type]="stage3-amd64-openrc"
STAGE_CONFIG[portage_sync]="rsync"
STAGE_CONFIG[verify_files]="true"

log_stage() {
    echo -e "${GREEN}[STAGE]${NC} $1"
}

show_stage_menu() {
    local choice
    choice=$(dialog --title "Stage File Selection (AMD64 Handbook)" \
        --menu "Select option:" 18 70 9 \
        1 "Stage File Type (Current: ${STAGE_CONFIG[stage_type]})" \
        2 "Mirror Selection (Current: ${STAGE_CONFIG[mirror]})" \
        3 "Set Date/Time (Critical for HTTPS downloads)" \
        4 "Download Stage File" \
        5 "Verify and Validate Download" \
        6 "Extract Stage File" \
        7 "Configure make.conf" \
        8 "Stage File Information" \
        9 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) select_stage_type ;;
        2) select_mirror ;;
        3) configure_datetime ;;
        4) download_stage_file ;;
        5) verify_stage_file ;;
        6) extract_stage_file ;;
        7) configure_make.conf ;;
        8) show_stage_info ;;
        9) return ;;
    esac
    
    show_stage_menu
}

select_stage_type() {
    local choice=$(dialog --title "Stage File Type (AMD64 Handbook)" \
        --menu "Choose stage tarball type:" 20 70 8 \
        1 "stage3-amd64-openrc (recommended default)" \
        2 "stage3-amd64-systemd" \
        3 "stage3-amd64-openrc-desktop (desktop optimized)" \
        4 "stage3-amd64-systemd-desktop" \
        5 "stage3-amd64-no-multilib (pure 64-bit)" \
        6 "stage3-amd64-musl (alternative libc)" \
        7 "stage3-amd64-hardened (security focused)" \
        8 "Custom URL" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) 
            STAGE_CONFIG[stage_type]="stage3-amd64-openrc"
            CONFIG[stage_tarball]="stage3-amd64-openrc"
            CONFIG[init_system]="openrc"
            ;;
        2) 
            STAGE_CONFIG[stage_type]="stage3-amd64-systemd"
            CONFIG[stage_tarball]="stage3-amd64-systemd"
            CONFIG[init_system]="systemd"
            ;;
        3) 
            STAGE_CONFIG[stage_type]="stage3-amd64-openrc-desktop"
            CONFIG[stage_tarball]="stage3-amd64-openrc-desktop"
            CONFIG[init_system]="openrc"
            ;;
        4) 
            STAGE_CONFIG[stage_type]="stage3-amd64-systemd-desktop"
            CONFIG[stage_tarball]="stage3-amd64-systemd-desktop"
            CONFIG[init_system]="systemd"
            ;;
        5) 
            STAGE_CONFIG[stage_type]="stage3-amd64-no-multilib"
            CONFIG[stage_tarball]="stage3-amd64-no-multilib"
            CONFIG[init_system]="openrc"
            ;;
        6) 
            STAGE_CONFIG[stage_type]="stage3-amd64-musl"
            CONFIG[stage_tarball]="stage3-amd64-musl"
            CONFIG[init_system]="openrc"
            ;;
        7) 
            STAGE_CONFIG[stage_type]="stage3-amd64-hardened"
            CONFIG[stage_tarball]="stage3-amd64-hardened"
            CONFIG[init_system]="openrc"
            ;;
        8)
            CONFIG[stage_url]=$(dialog --title "Custom Stage URL" \
                --inputbox "Enter custom stage tarball URL:" 8 70 "" \
                3>&1 1>&2 2>&3)
            ;;
    esac
}

select_mirror() {
    local choice=$(dialog --title "Mirror Selection" \
        --menu "Choose Gentoo mirror:" 18 60 6 \
        1 "https://distfiles.gentoo.org (official)" \
        2 "https://mirror.sjtu.edu.cn/gentoo" \
        3 "https://mirror.karneval.org/gentoo" \
        4 "https://gentoo.mirrors.ovh.net/gentoo-distfiles" \
        5 "https://ftp.snt.utwente.nl/pub/os/linux/gentoo" \
        6 "Custom mirror" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) STAGE_CONFIG[mirror]="https://distfiles.gentoo.org" ;;
        2) STAGE_CONFIG[mirror]="https://mirror.sjtu.edu.cn/gentoo" ;;
        3) STAGE_CONFIG[mirror]="https://mirror.karneval.org/gentoo" ;;
        4) STAGE_CONFIG[mirror]="https://gentoo.mirrors.ovh.net/gentoo-distfiles" ;;
        5) STAGE_CONFIG[mirror]="https://ftp.snt.utwente.nl/pub/os/linux/gentoo" ;;
        6) STAGE_CONFIG[mirror]=$(dialog --title "Custom Mirror" \
            --inputbox "Enter custom mirror URL:" 8 60 "https://distfiles.gentoo.org" \
            3>&1 1>&2 2>&3)
            ;;
    esac
}

configure_datetime() {
    local current_date=$(date)
    local choice=$(dialog --title "Date/Time Configuration" \
        --menu "Current system time: $current_date" 15 70 3 \
        1 "Use NTP to sync time (recommended)" \
        2 "Set time manually" \
        3 "Continue with current time" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            if command -v chronyd &> /dev/null; then
                chronyd -q
                success "Time synchronized via NTP"
            else
                emerge --ask --quiet net-misc/chrony
                chronyd -q
            fi
            ;;
        2)
            local manual_time=$(dialog --title "Manual Time Setup" \
                --inputbox "Enter time (MMDDhhmmYYYY format):\nExample: 010315302024 for Jan 3, 15:30, 2024" 10 50 "" \
                3>&1 1>&2 2>&3)
            if [[ -n "$manual_time" ]]; then
                date "$manual_time"
                success "Time set manually"
            fi
            ;;
        3)
            log_stage "Continuing with current system time"
            ;;
    esac
}

download_stage_file() {
    # Ensure we're in the right directory
    cd /mnt/gentoo || mkdir -p /mnt/gentoo && cd /mnt/gentoo
    
    local stage_url=""
    if [[ -n "${CONFIG[stage_url]}" ]]; then
        stage_url="${CONFIG[stage_url]}"
    else
        local arch="amd64"
        local stage_name="${STAGE_CONFIG[stage_type]}"
        stage_url="${STAGE_CONFIG[mirror]}/releases/${arch}/autobuilds/latest-${stage_name}/${stage_name}-*.tar.xz"
    fi
    
    log_stage "Downloading stage tarball from: $stage_url"
    
    # Create progress dialog
    (
        echo "20"; sleep 1
        echo "Setting up download environment..."; sleep 1
        echo "40"
        wget --progress=bar:force -nc "$stage_url"
        echo "100"; sleep 1
        echo "Download completed!"
    ) | dialog --title "Downloading Stage File" --gauge "Preparing..." 15 60 0
    
    if [[ $? -eq 0 ]]; then
        success "Stage file downloaded successfully"
        dialog --msgbox "Stage file downloaded successfully!\n\nNext: Verify and validate the download, then extract." 10 50
    else
        error "Failed to download stage file"
        dialog --msgbox "Download failed! Check your internet connection and mirror selection." 8 50
    fi
}

verify_stage_file() {
    local stage_files=($(ls stage3-*.tar.xz 2>/dev/null || true))
    
    if [[ ${#stage_files[@]} -eq 0 ]]; then
        dialog --msgbox "No stage files found! Please download first." 8 40
        return
    fi
    
    if [[ ${#stage_files[@]} -gt 1 ]]; then
        dialog --msgbox "Multiple stage files found:\n${stage_files[*]}\n\nPlease remove extras or specify which to verify." 10 60
        return
    fi
    
    local stage_file="${stage_files[0]}"
    log_stage "Verifying stage file: $stage_file"
    
    # Download verification files
    local base_url="${STAGE_CONFIG[mirror]}/releases/amd64/autobuilds"
    local stage_dir=$(dirname "$stage_url")
    
    dialog --title "Verifying Stage File" \
        --yesno "Download verification files (.DIGESTS, .sha256, .asc)?\n\nThis ensures file integrity and authenticity." 10 50
    
    if [[ $? -eq 0 ]]; then
        wget -q "${stage_dir}/${stage_file}.DIGESTS" 2>/dev/null || true
        wget -q "${stage_dir}/${stage_file}.sha256" 2>/dev/null || true
        wget -q "${stage_dir}/${stage_file}.asc" 2>/dev/null || true
    fi
    
    # Verify checksums if files exist
    if [[ -f "${stage_file}.sha256" ]]; then
        if sha256sum --check "${stage_file}.sha256" 2>/dev/null; then
            success "SHA256 checksum verified"
        else
            warn "SHA256 verification failed"
        fi
    fi
    
    if [[ -f "${stage_file}.DIGESTS" ]]; then
        log_stage "DIGESTS file contents:"
        cat "${stage_file}.DIGESTS"
    fi
    
    dialog --msgbox "Stage file verification completed!\n\nFile: $stage_file\nSize: $(du -h "$stage_file" | cut -f1)" 10 50
}

extract_stage_file() {
    local stage_files=($(ls stage3-*.tar.xz 2>/dev/null || true))
    
    if [[ ${#stage_files[@]} -eq 0 ]]; then
        dialog --msgbox "No stage files found! Please download first." 8 40
        return
    fi
    
    local stage_file="${stage_files[0]}"
    
    dialog --title "Extract Stage File" \
        --yesno "Extract stage file: $stage_file?\n\nThis will set up the base Gentoo environment in /mnt/gentoo" 10 50
    
    if [[ $? -eq 0 ]]; then
        log_stage "Extracting stage file: $stage_file"
        
        # Create progress dialog
        (
            echo "20"; sleep 1
            echo "Preparing extraction..."; sleep 1
            echo "40"
            tar xpvf "$stage_file" --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
            echo "100"; sleep 1
            echo "Extraction completed!"
        ) | dialog --title "Extracting Stage File" --gauge "Preparing..." 15 60 0
        
        success "Stage file extracted successfully"
        dialog --msgbox "Stage file extracted successfully!\n\nNext: Configure Portage and system settings." 10 50
    fi
}

configure_make.conf() {
    local make_conf="/mnt/gentoo/etc/portage/make.conf"
    
    if [[ ! -f "$make_conf" ]]; then
        dialog --msgbox "Stage file not extracted yet! Please extract first." 8 40
        return
    fi
    
    # Get CPU count for MAKEOPTS
    local cpu_count=$(nproc)
    local makeopts="-j${cpu_count} -l$((cpu_count + 1))"
    
    # Create optimized make.conf
    cat > "$make_conf" << EOF
# Gentoo Linux Configuration - AMD64 Handbook
# Generated by Gentoo Installer

# Compiler flags optimized for current CPU
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"

# Make options for parallel compilation
MAKEOPTS="$makeopts"

# Portage settings
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"

# Gentoo mirror
GENTOO_MIRRORS="${STAGE_CONFIG[mirror]}"

# Enable parallel emerge
EMERGE_DEFAULT_OPTS="--jobs=${cpu_count} --load-average=${cpu_count}"

# Python targets
PYTHON_TARGETS="python3_11 python3_12"
PYTHON_SINGLE_TARGET="python3_11"

# Binary package host (if enabled)
EOF

    if [[ "${CONFIG[use_binary_host]}" == "true" ]]; then
        echo 'FEATURES="${FEATURES} getbinpkg binpkg-request-signature"' >> "$make_conf"
        echo 'BINHOST="https://distfiles.gentoo.org/releases/amd64/binpackages/x86-64/"' >> "$make_conf"
    fi
    
    # Add USE flags based on profile
    case "${CONFIG[profile]}" in
        *desktop*)
            echo 'USE="X pulseaudio dbus gtk qt5"' >> "$make_conf"
            ;;
        *gnome*)
            echo 'USE="X pulseaudio dbus gtk3 gnome-shell"' >> "$make_conf"
            ;;
        *kde*)
            echo 'USE="X pulseaudio dbus qt5 kde plasma"' >> "$make_conf"
            ;;
        *hardened*)
            echo 'USE="hardened -pcre2"' >> "$make_conf"
            ;;
    esac
    
    success "make.conf configured with optimized settings"
    dialog --msgbox "make.conf configured successfully!\n\nSettings applied:\n• Compiler: -march=native -O2 -pipe\n• MAKEOPTS: $makeopts\n• Mirror: ${STAGE_CONFIG[mirror]}\n• Profile: ${CONFIG[profile]}" 12 50
}

show_stage_info() {
    local info="Stage File Information (AMD64 Handbook):\n\n"
    info+="STAGE3 TYPES:\n"
    info+="• stage3-amd64-openrc: Default, OpenRC init\n"
    info+="• stage3-amd64-systemd: systemd init\n"
    info+="• stage3-amd64-*-desktop: Optimized for desktops\n"
    info+="• stage3-amd64-no-multilib: Pure 64-bit (advanced)\n"
    info+="• stage3-amd64-musl: musl libc (alternative)\n"
    info+="• stage3-amd64-hardened: Security hardened\n\n"
    info+="DOWNLOAD VERIFICATION:\n"
    info+="• .DIGESTS: Multiple hash algorithms\n"
    info+="• .sha256: SHA256 checksums\n"
    info+="• .asc: GPG signatures (optional)\n\n"
    info+="EXTRACTION OPTIONS:\n"
    info+="• --xattrs-include='*.*': Preserve extended attributes\n"
    info+="• --numeric-owner: Maintain original ownership\n"
    info+="• -C /mnt/gentoo: Extract to installation directory\n\n"
    info+="⚠️ IMPORTANT:\n"
    info+="• Stage files are updated frequently\n"
    info+="• System time must be accurate for HTTPS\n"
    info+="• Always verify downloads with checksums"
    
    dialog --title "Stage File Information" \
        --msgbox "$info" 25 70
}

# Initialize stage config
load_stage_config() {
    if [[ -f "$STAGE_CONFIG_FILE" ]]; then
        source "$STAGE_CONFIG_FILE"
    fi
}

save_stage_config() {
    > "$STAGE_CONFIG_FILE"
    for key in "${!STAGE_CONFIG[@]}"; do
        echo "STAGE_CONFIG[$key]=\"${STAGE_CONFIG[$key]}\"" >> "$STAGE_CONFIG_FILE"
    done
}

# Main execution
load_stage_config
show_stage_menu
