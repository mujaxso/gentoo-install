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
source_lib "${LIB_DIR}/common.sh"
source_lib "${LIB_DIR}/ui.sh"
source_lib "${LIB_DIR}/disk.sh"
source_lib "${LIB_DIR}/filesystem.sh"
source_lib "${LIB_DIR}/config.sh"
source_lib "${LIB_DIR}/network.sh"
source_lib "${LIB_DIR}/stage3.sh"
source_lib "${LIB_DIR}/chroot.sh"
source_lib "${LIB_DIR}/bootloader.sh"

# Initialize configuration with default values
declare -A CONFIG
CONFIG[MOUNT_POINT]="${CONFIG[MOUNT_POINT]:-/mnt/gentoo}"
CONFIG[INSTALL_DISK]="${CONFIG[INSTALL_DISK]:-}"
CONFIG[INIT_SYSTEM]="${CONFIG[INIT_SYSTEM]:-}"
CONFIG[BOOT_MODE]="${CONFIG[BOOT_MODE]:-}"
CONFIG[FILESYSTEM]="${CONFIG[FILESYSTEM]:-}"
CONFIG[USE_ENCRYPTION]="${CONFIG[USE_ENCRYPTION]:-no}"
CONFIG[HOSTNAME]="${CONFIG[HOSTNAME]:-gentoo}"
CONFIG[USERNAME]="${CONFIG[USERNAME]:-user}"
CONFIG[TIMEZONE]="${CONFIG[TIMEZONE]:-UTC}"

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

  select_target_disk

  if show_yesno "Partition ${CONFIG[INSTALL_DISK]}? ALL DATA WILL BE LOST!"; then
    partition_disk || {
      show_error "Partition failed!"
      return 1
    }
  fi

  if [[ "${CONFIG[USE_ENCRYPTION]}" == "yes" ]]; then
    source_lib "${MODULE_DIR}/fs/luks.sh"
    setup_luks_encryption || {
      show_error "Encryption setup failed!"
      return 1
    }
  fi
}

install_base_system() {
  if [[ -z "${CONFIG[INSTALL_DISK]}" ]]; then
    show_error "Configure disk first!"
    return 1
  fi

  show_info "Installing base system..."

  format_partitions || return 1
  mount_filesystems || return 1
  download_stage3 || return 1
  extract_stage3 || return 1
  configure_makeconf || return 1
  generate_fstab || return 1
  prepare_chroot || return 1

  show_success "Base system installed!"
}

configure_system_menu() {
  if [[ ! -d "${CONFIG[MOUNT_POINT]}/root" ]]; then
    show_error "Install base system first!"
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
    source_lib "${MODULE_DIR}/boot/efi.sh"
    install_efi_bootloader || return 1
  else
    source_lib "${MODULE_DIR}/boot/bios.sh"
    install_bios_bootloader || return 1
  fi
}

finalize_installation() {
  umount_all || show_error "Warning: Some unmounts failed"

  show_success "Installation complete! You can now reboot."

  if show_yesno "Reboot now?"; then
    reboot
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
  check_dependencies || exit 1

  show_banner

  if ! check_internet; then
    show_error "No internet connection!"
    exit 1
  fi

  show_info "Welcome to Gentoo Installer v2.0 by Mujahid Siyam"

  main_menu
}

# Trap errors for better debugging
trap 'echo "Error on line $LINENO. Exit code: $?" >&2' ERR

main "$@"
