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
  local init=$(show_menu "Init System" "1" "OpenRC" "2" "systemd")
  CONFIG[INIT_SYSTEM]=$([[ $init == "1" ]] && echo "openrc" || echo "systemd")

  local boot=$(show_menu "Boot Mode" "1" "EFI" "2" "BIOS")
  CONFIG[BOOT_MODE]=$([[ $boot == "1" ]] && echo "efi" || echo "bios")

  CONFIG[HOSTNAME]=$(show_input "Hostname:" "${CONFIG[HOSTNAME]}")
  CONFIG[USERNAME]=$(show_input "Username:" "${CONFIG[USERNAME]}")
  CONFIG[TIMEZONE]=$(show_input "Timezone:" "${CONFIG[TIMEZONE]}")

  show_success "Configuration saved"
}

disk_configuration_menu() {
  log_header "DISK CONFIGURATION"

  local fs=$(show_menu "Filesystem" "1" "ext4" "2" "btrfs" "3" "zfs")
  case $fs in
  1) CONFIG[FILESYSTEM]="ext4" ;;
  2) CONFIG[FILESYSTEM]="btrfs" ;;
  3) CONFIG[FILESYSTEM]="zfs" ;;
  esac

  show_yesno "Enable LUKS encryption?" && CONFIG[USE_ENCRYPTION]="yes" || CONFIG[USE_ENCRYPTION]="no"

  if ! select_target_disk; then
    return 1
  fi

  # Check if we're trying to use the root disk
  local root_disk=$(mount | grep ' / ' | cut -d' ' -f1 | sed 's/[0-9]*$//')
  if [[ "${CONFIG[INSTALL_DISK]}" == "$root_disk" ]]; then
    show_error "Cannot use the root disk for installation!"
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
}

install_base_system() {
  if [[ -z "${CONFIG[INSTALL_DISK]}" ]]; then
    show_error "Configure disk first!"
    return 1
  fi

  show_info "This will install the base Gentoo system. This may take some time."
  if ! show_yesno "Continue with installation?"; then
    return 1
  fi

  local steps=(
    "Formatting partitions:format_partitions"
    "Mounting filesystems:mount_filesystems" 
    "Downloading stage3:download_stage3"
    "Extracting stage3:extract_stage3"
    "Configuring make.conf:configure_makeconf"
    "Generating fstab:generate_fstab"
    "Preparing chroot:prepare_chroot"
  )
  
  for step in "${steps[@]}"; do
    local desc="${step%:*}"
    local func="${step#*:}"
    show_info "Step: $desc"
    if ! $func; then
      show_error "Failed at: $desc"
      log_error "Check the following:"
      log_error "  - Internet connection"
      log_error "  - Disk space availability"
      log_error "  - Disk permissions"
      log_error "  - Gentoo mirror availability"
      return 1
    fi
  done

  show_success "Base system installed!"
}

configure_system_menu() {
  if [[ ! -d "${CONFIG[MOUNT_POINT]}/root" ]]; then
    show_error "Install base system first!"
    return 1
  fi

  show_info "This will enter the chroot environment to configure your system."
  show_info "You will be prompted to set passwords and make configuration choices."
  if ! show_yesno "Continue with system configuration?"; then
    return 1
  fi
  
  generate_chroot_script || return 1
  enter_chroot || return 1
}

install_bootloader_menu() {
  if [[ ! -d "${CONFIG[MOUNT_POINT]}/root" ]]; then
    show_error "Install base system first!"
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
}

finalize_installation() {
  show_info "Finalizing installation..."
  if show_yesno "Unmount all filesystems and complete installation?"; then
    umount_all || show_error "Warning: Some unmounts failed"
    show_success "Installation complete! You can now reboot."
    
    if show_yesno "Reboot now?"; then
      reboot
    fi
  else
    show_error "Finalization cancelled"
    return 1
  fi
}

main_menu() {
  while true; do
    choice=$(show_menu "Gentoo Installer v2.0 - Main Menu" \
      "1" "System Configuration" \
      "2" "Disk Configuration" \
      "3" "Install Base System" \
      "4" "Configure System" \
      "5" "Install Bootloader" \
      "6" "Finalize & Reboot" \
      "7" "Exit")

    case $choice in
    1) system_configuration_menu || show_error "Configuration failed" ;;
    2) disk_configuration_menu || show_error "Disk configuration failed" ;;
    3) install_base_system || show_error "Base system installation failed" ;;
    4) configure_system_menu || show_error "System configuration failed" ;;
    5) install_bootloader_menu || show_error "Bootloader installation failed" ;;
    6) finalize_installation ;;
    7)
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

  main_menu
}

# Trap errors for better debugging
trap 'echo "Error on line $LINENO. Exit code: $?" >&2' ERR

main "$@"
