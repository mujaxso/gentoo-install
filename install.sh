#!/usr/bin/env bash
################################################################################
# GENTOO LINUX ADVANCED INSTALLER v2.0
# Author: Mujahid Siyam
################################################################################

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly MODULE_DIR="${SCRIPT_DIR}/modules"

source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/disk.sh"
source "${LIB_DIR}/filesystem.sh"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/network.sh"
source "${LIB_DIR}/stage3.sh"
source "${LIB_DIR}/chroot.sh"
source "${LIB_DIR}/bootloader.sh"

declare -A CONFIG
CONFIG[MOUNT_POINT]="/mnt/gentoo"
CONFIG[INSTALL_DISK]=""
CONFIG[INIT_SYSTEM]=""
CONFIG[BOOT_MODE]=""
CONFIG[FILESYSTEM]=""
CONFIG[USE_ENCRYPTION]="no"
CONFIG[HOSTNAME]="gentoo"
CONFIG[USERNAME]="user"
CONFIG[TIMEZONE]="UTC"

system_configuration_menu() {
    log_header "SYSTEM CONFIGURATION"
    local init=$(show_menu "Init System" "1" "OpenRC" "2" "systemd")
    CONFIG[INIT_SYSTEM]=$([[ $init == "1" ]] && echo "openrc" || echo "systemd")
    local boot=$(show_menu "Boot Mode" "1" "EFI" "2" "BIOS")
    CONFIG[BOOT_MODE]=$([[ $boot == "1" ]] && echo "efi" || echo "bios")
    CONFIG[HOSTNAME]=$(show_input "Hostname:" "${CONFIG[HOSTNAME]}")
    CONFIG[USERNAME]=$(show_input "Username:" "${CONFIG[USERNAME]}")
    show_success "Configuration saved"
}

disk_configuration_menu() {
    log_header "DISK CONFIGURATION"
    local fs=$(show_menu "Filesystem" "1" "ext4" "2" "btrfs" "3" "zfs")
    case $fs in 1) CONFIG[FILESYSTEM]="ext4";; 2) CONFIG[FILESYSTEM]="btrfs";; 3) CONFIG[FILESYSTEM]="zfs";; esac
    show_yesno "Enable LUKS encryption?" && CONFIG[USE_ENCRYPTION]="yes"
    select_target_disk
    show_yesno "Partition ${CONFIG[INSTALL_DISK]}? ALL DATA WILL BE LOST!" && partition_disk
    [ "${CONFIG[USE_ENCRYPTION]}" = "yes" ] && source "${MODULE_DIR}/fs/luks.sh" && setup_luks_encryption
}

install_base_system() {
    [ -z "${CONFIG[INSTALL_DISK]}" ] && show_error "Configure disk first!" && return 1
    show_info "Installing base system..."
    format_partitions && mount_filesystems && download_stage3 && extract_stage3 && configure_makeconf && generate_fstab && prepare_chroot
    show_success "Base system installed!"
}

configure_system_menu() {
    [ ! -d "${CONFIG[MOUNT_POINT]}/root" ] && show_error "Install base system first!" && return 1
    generate_chroot_script && enter_chroot
}

install_bootloader_menu() {
    [ ! -d "${CONFIG[MOUNT_POINT]}/root" ] && show_error "Install base system first!" && return 1
    if [ "${CONFIG[BOOT_MODE]}" = "efi" ]; then
        source "${MODULE_DIR}/boot/efi.sh" && install_efi_bootloader
    else
        source "${MODULE_DIR}/boot/bios.sh" && install_bios_bootloader
    fi
}

finalize_installation() {
    umount_all
    show_success "Installation complete! You can now reboot."
    show_yesno "Reboot now?" && reboot
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
            1) system_configuration_menu;;
            2) disk_configuration_menu;;
            3) install_base_system;;
            4) configure_system_menu;;
            5) install_bootloader_menu;;
            6) finalize_installation;;
            7) show_yesno "Exit installer?" && exit 0;;
        esac
    done
}

main() {
    check_root
    check_dependencies
    show_banner
    check_internet || { show_error "No internet connection!"; exit 1; }
    show_info "Welcome to Gentoo Installer v2.0 by Mujahid Siyam"
    main_menu
}

main "$@"
