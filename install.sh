#!/usr/bin/env bash
################################################################################
# GENTOO LINUX ADVANCED INSTALLER v2.0
# Author: Mujahid Siyam
################################################################################

# Enable debug mode for troubleshooting (comment out after fixing)
set -x

# Use strict mode but with better error handling
set -eo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly MODULE_DIR="${SCRIPT_DIR}/modules"

# Function to safely source files with error checking
source_lib() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: Required library file not found: $file" >&2
    echo "Current directory: $(pwd)" >&2
    echo "Script directory: ${SCRIPT_DIR}" >&2
    ls -la "${LIB_DIR}/" 2>/dev/null || echo "lib/ directory not found"
    exit 1
  fi
  echo "Sourcing: $file"
  source "$file" || {
    echo "ERROR: Failed to source $file" >&2
    exit 1
  }
}

# Source all library files with validation
echo "Loading library files..."
for lib in "common.sh" "ui.sh" "disk.sh" "filesystem.sh" "config.sh" "network.sh" "stage3.sh" "chroot.sh" "bootloader.sh"; do
    source_lib "${LIB_DIR}/${lib}"
done

# Load default configuration
if [[ -f "${SCRIPT_DIR}/config/default.conf" ]]; then
    source "${SCRIPT_DIR}/config/default.conf"
fi

# Initialize configuration with default values
declare -A CONFIG
CONFIG[MOUNT_POINT]="${CONFIG[MOUNT_POINT]:-/mnt/gentoo}"
CONFIG[INSTALL_DISK]="${CONFIG[INSTALL_DISK]:-}"
CONFIG[INIT_SYSTEM]="${CONFIG[INIT_SYSTEM]:-}"
CONFIG[BOOT_MODE]="${CONFIG[BOOT_MODE]:-}"
CONFIG[FILESYSTEM]="${CONFIG[FILESYSTEM]:-}"
CONFIG[USE_ENCRYPTION]="${CONFIG[USE_ENCRYPTION]:-no}"
CONFIG[HOSTNAME]="${CONFIG[HOSTNAME]:-${DEFAULT_HOSTNAME:-gentoo}}"
CONFIG[USERNAME]="${CONFIG[USERNAME]:-${DEFAULT_USERNAME:-user}}"
CONFIG[TIMEZONE]="${CONFIG[TIMEZONE]:-${DEFAULT_TIMEZONE:-UTC}}"

system_configuration_menu() {
    log_header "SYSTEM CONFIGURATION"
    
    # Offer to load existing config
    if [[ -n "${CONFIG[INIT_SYSTEM]}" && -n "${CONFIG[BOOT_MODE]}" ]]; then
        show_config_summary
        if ! show_yesno "Use current configuration?"; then
            # Reset configuration if user wants to change it
            CONFIG[INIT_SYSTEM]=""
            CONFIG[BOOT_MODE]=""
        fi
    fi
    
    if [[ -z "${CONFIG[INIT_SYSTEM]}" ]]; then
        local init=$(show_menu "Init System" "1" "OpenRC" "2" "systemd")
        CONFIG[INIT_SYSTEM]=$([[ $init == "1" ]] && echo "openrc" || echo "systemd")
    fi

    if [[ -z "${CONFIG[BOOT_MODE]}" ]]; then
        local boot=$(show_menu "Boot Mode" "1" "EFI" "2" "BIOS")
        CONFIG[BOOT_MODE]=$([[ $boot == "1" ]] && echo "efi" || echo "bios")
    fi

    CONFIG[HOSTNAME]=$(show_input "Hostname:" "${CONFIG[HOSTNAME]}")
    CONFIG[USERNAME]=$(show_input "Username:" "${CONFIG[USERNAME]}")
    CONFIG[TIMEZONE]=$(show_input "Timezone:" "${CONFIG[TIMEZONE]}")

    # Save configuration
    save_config
    show_success "Configuration saved"
    return 0
}

disk_configuration_menu() {
    # Check if system configuration is done
    if [[ -z "${CONFIG[INIT_SYSTEM]}" || -z "${CONFIG[BOOT_MODE]}" ]]; then
        show_error "Please complete system configuration first!"
        return 1
    fi

    log_header "DISK CONFIGURATION"
    
    # Show current disk configuration if available
    if [[ -n "${CONFIG[FILESYSTEM]}" && -n "${CONFIG[INSTALL_DISK]}" ]]; then
        local disk_summary="Current Disk Configuration:\n\n"
        disk_summary+="  Filesystem: ${CONFIG[FILESYSTEM]}\n"
        disk_summary+="  Install Disk: ${CONFIG[INSTALL_DISK]}\n"
        disk_summary+="  Encryption: ${CONFIG[USE_ENCRYPTION]}\n\n"
        disk_summary+="Do you want to use this configuration?"
        
        if show_yesno "$disk_summary"; then
            # Check if the disk still exists
            if [[ -b "${CONFIG[INSTALL_DISK]}" ]]; then
                log_success "Using existing disk configuration"
                return 0
            else
                show_error "Previously configured disk ${CONFIG[INSTALL_DISK]} not found!"
                CONFIG[INSTALL_DISK]=""
            fi
        else
            # Reset disk configuration
            CONFIG[FILESYSTEM]=""
            CONFIG[INSTALL_DISK]=""
            CONFIG[USE_ENCRYPTION]="no"
        fi
    fi

    if [[ -z "${CONFIG[FILESYSTEM]}" ]]; then
        local fs=$(show_menu "Filesystem" "1" "ext4" "2" "btrfs" "3" "zfs")
        case $fs in
        1) CONFIG[FILESYSTEM]="ext4" ;;
        2) CONFIG[FILESYSTEM]="btrfs" ;;
        3) CONFIG[FILESYSTEM]="zfs" ;;
        esac
    fi

    if [[ -z "${CONFIG[USE_ENCRYPTION]}" ]]; then
        show_yesno "Enable LUKS encryption?" && CONFIG[USE_ENCRYPTION]="yes" || CONFIG[USE_ENCRYPTION]="no"
    fi

    if [[ -z "${CONFIG[INSTALL_DISK]}" ]]; then
        if ! select_target_disk; then
            return 1
        fi
    fi

    # Check if we're trying to use the root disk
    local root_disk=$(mount | grep ' / ' | cut -d' ' -f1 | sed 's/[0-9]*$//')
    if [[ "${CONFIG[INSTALL_DISK]}" == "$root_disk" ]]; then
        show_error "Cannot use the root disk for installation!"
        CONFIG[INSTALL_DISK]=""
        return 1
    fi

    if show_yesno "Partition ${CONFIG[INSTALL_DISK]}? ALL DATA WILL BE LOST!"; then
        partition_disk || {
            show_error "Partition failed!"
            return 1
        }
    fi

    if [[ "${CONFIG[USE_ENCRYPTION]}" == "yes" ]]; then
        if [[ -f "${MODULE_DIR}/fs/luks.sh" ]]; then
            source "${MODULE_DIR}/fs/luks.sh"
            setup_luks_encryption || {
                show_error "Encryption setup failed!"
                return 1
            }
        else
            show_error "LUKS module not found!"
            return 1
        fi
    fi
    
    # Save configuration
    save_config
    return 0
}

install_base_system() {
    # Check if disk configuration is done
    if [[ -z "${CONFIG[INSTALL_DISK]}" || -z "${CONFIG[FILESYSTEM]}" ]]; then
        show_error "Please complete disk configuration first!"
        return 1
    fi

    show_info "This will install the base Gentoo system. This may take some time."
    if ! show_yesno "Continue with installation?"; then
        return 1
    fi

    # Format and mount first
    if ! format_partitions; then
        show_error "Failed to format partitions"
        return 1
    fi
    
    if ! mount_filesystems; then
        show_error "Failed to mount filesystems"
        return 1
    fi
    
    # Verify mount point is ready for installation
    local mp="${CONFIG[MOUNT_POINT]}"
    if ! mountpoint -q "$mp"; then
        show_error "Mount point $mp is not mounted! Cannot proceed with installation."
        log_error "Please check disk configuration and try again."
        return 1
    fi
    
    # Check available space on mount point
    local available_mb=$(df -m "$mp" | awk 'NR==2 {print $4}')
    if [[ $available_mb -lt 5000 ]]; then
        show_error "Insufficient space on target filesystem!"
        log_error "Only ${available_mb}MB available, need at least 5000MB"
        return 1
    fi
    
    log_success "Mount point verified: $mp (${available_mb}MB available)"
    
    # Try automatic download first, then fallback to manual
    if ! download_stage3; then
        show_error "Automatic stage3 download failed"
        local manual_choice=$(show_menu "Manual Download Options" \
            "1" "Enter URL manually" \
            "2" "Browse with lynx (if available)" \
            "3" "Cancel and exit")
        
        case $manual_choice in
        1)
            if ! download_stage3_manual; then
                show_error "Manual download failed"
                return 1
            fi
            ;;
        2)
            if command -v lynx &>/dev/null; then
                local selected_url=$(browse_stage3_with_lynx)
                if [[ -n "$selected_url" ]]; then
                    log_info "Downloading from selected URL: $selected_url"
                    # Use the same download logic as manual download
                    if command -v wget &>/dev/null; then
                        if ! wget --timeout=60 --tries=3 --show-progress -O "stage3.tar.xz" "$selected_url"; then
                            show_error "Download failed with wget"
                            return 1
                        fi
                    elif command -v curl &>/dev/null; then
                        if ! curl -L --connect-timeout 60 --retry 3 --progress-bar -o "stage3.tar.xz" "$selected_url"; then
                            show_error "Download failed with curl"
                            return 1
                        fi
                    else
                        show_error "Neither wget nor curl available for download"
                        return 1
                    fi
                    
                    # Verify download
                    if [[ -f "stage3.tar.xz" ]]; then
                        local file_size=$(stat -c%s "stage3.tar.xz" 2>/dev/null || echo "0")
                        if [[ $file_size -gt 104857600 ]]; then
                            CONFIG[STAGE3_FILE]="$mp/stage3.tar.xz"
                            log_success "Manual download successful ($((file_size/1024/1024)) MB)"
                        else
                            log_error "Downloaded file too small"
                            rm -f "stage3.tar.xz"
                            return 1
                        fi
                    else
                        log_error "Downloaded file not found"
                        return 1
                    fi
                else
                    return 1
                fi
            else
                show_error "Lynx is not available. Please install it or use manual URL entry."
                return 1
            fi
            ;;
        3|*)
            show_error "Stage3 download cancelled"
            return 1
            ;;
        esac
    fi
    
    # Continue with remaining steps
    local remaining_steps=(
        "Extracting stage3:extract_stage3"
        "Configuring make.conf:configure_makeconf"
        "Generating fstab:generate_fstab"
        "Preparing chroot:prepare_chroot"
    )
    
    for step in "${remaining_steps[@]}"; do
        local desc="${step%:*}"
        local func="${step#*:}"
        show_info "Step: $desc"
        if ! $func; then
            show_error "Failed at: $desc"
            return 1
        fi
    done

    show_success "Base system installed!"
    return 0
}

configure_system_menu() {
    # Check if base system is installed
    if [[ ! -d "${CONFIG[MOUNT_POINT]}/root" ]]; then
        show_error "Please install base system first!"
        return 1
    fi

    show_info "This will enter the chroot environment to configure your system."
    show_info "You will be prompted to set passwords and make configuration choices."
    if ! show_yesno "Continue with system configuration?"; then
        return 1
    fi
    
    generate_chroot_script || return 1
    enter_chroot || return 1
    
    return 0
}

install_bootloader_menu() {
    # Check if system configuration is done in chroot
    if [[ ! -d "${CONFIG[MOUNT_POINT]}/root" ]]; then
        show_error "Please complete system configuration in chroot first!"
        return 1
    fi

    if [[ "${CONFIG[BOOT_MODE]}" == "efi" ]]; then
        if [[ -f "${MODULE_DIR}/boot/efi.sh" ]]; then
            source "${MODULE_DIR}/boot/efi.sh"
            install_efi_bootloader || return 1
        else
            show_error "EFI bootloader module not found!"
            return 1
        fi
    else
        if [[ -f "${MODULE_DIR}/boot/bios.sh" ]]; then
            source "${MODULE_DIR}/boot/bios.sh"
            install_bios_bootloader || return 1
        else
            show_error "BIOS bootloader module not found!"
            return 1
        fi
    fi
    
    return 0
}

finalize_installation() {
    # Check if bootloader is installed
    if [[ ! -f "${CONFIG[MOUNT_POINT]}/boot/grub/grub.cfg" ]]; then
        show_error "Please install bootloader first!"
        return 1
    fi

    show_info "Finalizing installation..."
    if show_yesno "Unmount all filesystems and complete installation?"; then
        umount_all || show_error "Warning: Some unmounts failed"
        show_success "Installation complete! You can now reboot."
        
        if show_yesno "Reboot now?"; then
            reboot
        fi
        return 0
    else
        show_error "Finalization cancelled"
        return 1
    fi
}

main_menu() {
    local current_step=1
    
    # Determine current step based on configuration
    if [[ -n "${CONFIG[INIT_SYSTEM]}" && -n "${CONFIG[BOOT_MODE]}" ]]; then
        current_step=2
    fi
    if [[ -n "${CONFIG[FILESYSTEM]}" && -n "${CONFIG[INSTALL_DISK]}" ]]; then
        current_step=3
    fi
    if [[ -d "${CONFIG[MOUNT_POINT]}/root" ]]; then
        current_step=4
    fi
    if [[ -f "${CONFIG[MOUNT_POINT]}/boot/grub/grub.cfg" ]]; then
        current_step=6
    fi
    
    while true; do
        # Build menu items with completion status
        local menu_items=()
        local step_names=(
            "System Configuration"
            "Disk Configuration" 
            "Install Base System"
            "Configure System"
            "Install Bootloader"
            "Finalize & Reboot"
            "Configuration Management"
            "Exit"
        )
        
        for i in {1..8}; do
            local status=""
            if [[ $i -lt $current_step ]]; then
                status=" ✓"
            elif [[ $i -eq $current_step ]]; then
                status=" →"
            else
                status=""
            fi
            menu_items+=("$i" "${step_names[$((i-1))]}${status}")
        done
        
        choice=$(show_menu "Gentoo Installer v2.0 - Main Menu (Step $current_step/6)" "${menu_items[@]}")
        
        case $choice in
        1) 
            if system_configuration_menu; then
                show_success "System configuration completed!"
                current_step=2
            else
                show_error "System configuration failed"
            fi
            ;;
        2) 
            if disk_configuration_menu; then
                show_success "Disk configuration completed!"
                current_step=3
            else
                show_error "Disk configuration failed"
            fi
            ;;
        3) 
            if install_base_system; then
                show_success "Base system installation completed!"
                current_step=4
            else
                show_error "Base system installation failed"
            fi
            ;;
        4) 
            if configure_system_menu; then
                show_success "System configuration completed!"
                current_step=5
            else
                show_error "System configuration failed"
            fi
            ;;
        5) 
            if install_bootloader_menu; then
                show_success "Bootloader installation completed!"
                current_step=6
            else
                show_error "Bootloader installation failed"
            fi
            ;;
        6) 
            if finalize_installation; then
                # Installation complete, exit
                exit 0
            else
                show_error "Finalization failed"
            fi
            ;;
        7)
            local config_choice=$(show_menu "Configuration Management" \
                "1" "Show Current Configuration" \
                "2" "Clear Saved Configuration" \
                "3" "Back to Main Menu")
            case $config_choice in
            1) show_config_summary ;;
            2) clear_config ;;
            3) ;;
            esac
            ;;
        8)
            if show_yesno "Exit installer?"; then
                exit 0
            fi
            ;;
        *) show_error "Invalid choice" ;;
        esac
    done
}

main() {
  check_root || exit 1
  
  # Load saved configuration (returns 1 when no config exists, which is normal)
  load_config || true
  
  # Check dependencies with automatic installation option
  if ! check_dependencies; then
    show_error "Dependency check failed. Exiting."
    exit 1
  fi
  
  check_optional_deps

  show_banner

  if ! check_internet; then
    show_error "Internet connection check failed!"
    exit 1
  fi

  show_info "Welcome to Gentoo Installer v2.0 by Mujahid Siyam"
  
  # Show loaded configuration if available
  if [[ -n "${CONFIG[INIT_SYSTEM]}" || -n "${CONFIG[INSTALL_DISK]}" ]]; then
      show_info "Loaded previous configuration. Use 'Configuration Management' to view or clear it."
  fi

  main_menu
}

# Trap errors for better debugging
trap 'echo "Error on line $LINENO. Exit code: $?" >&2' ERR

main "$@"
