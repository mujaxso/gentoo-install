#!/bin/bash

# Gentoo Linux Installer with TUI
# Supports systemd/OpenRC, EFI/BIOS, ext4/zfs/btrfs, LUKS, mdraid

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="/tmp/gentoo-install-config"

# Default configuration
declare -gA CONFIG
CONFIG[init_system]="openrc"
CONFIG[boot_mode]="efi"
CONFIG[root_fs]="ext4"
CONFIG[encrypt_root]="false"
CONFIG[use_raid]="false"
CONFIG[hostname]="gentoo"
CONFIG[timezone]="UTC"
CONFIG[keymap]="us"

# Logging
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log "Configuration loaded from $CONFIG_FILE"
    fi
}

# Save configuration
save_config() {
    for key in "${!CONFIG[@]}"; do
        echo "CONFIG[$key]=\"${CONFIG[$key]}\"" >> "$CONFIG_FILE"
    done
}

# Main menu
show_main_menu() {
    local choice
    while true; do
        choice=$(dialog --clear --title "Gentoo Linux Installer" \
            --menu "Select installation step:" 20 60 10 \
            1 "System Information" \
            2 "Disk Configuration" \
            3 "Filesystem Setup" \
            4 "Encryption (LUKS)" \
            5 "Gentoo Installation" \
            6 "System Configuration" \
            7 "Review & Execute" \
            8 "Exit" \
            3>&1 1>&2 2>&3)

        case $choice in
            1) show_system_info_menu ;;
            2) source "$MODULES_DIR/disk.sh" ;;
            3) source "$MODULES_DIR/filesystem.sh" ;;
            4) source "$MODULES_DIR/encryption.sh" ;;
            5) source "$MODULES_DIR/install.sh" ;;
            6) source "$MODULES_DIR/config.sh" ;;
            7) show_review_menu ;;
            8) confirm_exit ;;
            *) break ;;
        esac
    done
}

# System information menu
show_system_info_menu() {
    local choice
    choice=$(dialog --title "System Information" \
        --menu "Select option:" 15 60 6 \
        1 "Select Init System (Current: ${CONFIG[init_system]})" \
        2 "Select Boot Mode (Current: ${CONFIG[boot_mode]})" \
        3 "Set Hostname (Current: ${CONFIG[hostname]})" \
        4 "Set Timezone (Current: ${CONFIG[timezone]})" \
        5 "Set Keymap (Current: ${CONFIG[keymap]})" \
        6 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            CONFIG[init_system]=$(dialog --title "Init System" \
                --menu "Choose init system:" 10 40 2 \
                1 "OpenRC" \
                2 "systemd" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
        2)
            CONFIG[boot_mode]=$(dialog --title "Boot Mode" \
                --menu "Choose boot mode:" 10 40 2 \
                1 "EFI" \
                2 "BIOS/Legacy" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
        3)
            CONFIG[hostname]=$(dialog --title "Hostname" \
                --inputbox "Enter hostname:" 8 40 "${CONFIG[hostname]}" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
        4)
            CONFIG[timezone]=$(dialog --title "Timezone" \
                --inputbox "Enter timezone (e.g., UTC, America/New_York):" 8 40 "${CONFIG[timezone]}" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
        5)
            CONFIG[keymap]=$(dialog --title "Keymap" \
                --inputbox "Enter keymap (e.g., us, uk, de):" 8 40 "${CONFIG[keymap]}" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
    esac
}

# Review menu
show_review_menu() {
    local summary="Installation Summary:\n\n"
    summary+="Init System: ${CONFIG[init_system]}\n"
    summary+="Boot Mode: ${CONFIG[boot_mode]}\n"
    summary+="Root Filesystem: ${CONFIG[root_fs]}\n"
    summary+="Encryption: ${CONFIG[encrypt_root]}\n"
    summary+="RAID: ${CONFIG[use_raid]}\n"
    summary+="Hostname: ${CONFIG[hostname]}\n"
    summary+="Timezone: ${CONFIG[timezone]}\n"
    summary+="Keymap: ${CONFIG[keymap]}\n"

    dialog --title "Review Configuration" \
        --yesno "$summary\n\nProceed with installation?" 20 70
}

# Confirm exit
confirm_exit() {
    dialog --title "Exit" \
        --yesno "Are you sure you want to exit?" 7 30
    [[ $? -eq 0 ]] && exit 0
}

# Check dependencies
check_dependencies() {
    local deps=("parted" "mkfs.ext4" "mkfs.btrfs" "zfs" "cryptsetup" "mdadm")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            warn "Missing dependency: $dep"
        fi
    done
}

# Initialize
main() {
    # Check if dialog is available
    if ! command -v dialog &> /dev/null; then
        error "dialog is required but not installed. Please install: emerge dialog"
        exit 1
    fi

    # Check for root
    check_root
    
    # Load existing config
    load_config
    
    # Check dependencies
    check_dependencies
    
    # Welcome message
    dialog --title "Gentoo Linux Installer" \
        --msgbox "Welcome to the Gentoo Linux Installer!\n\nThis installer supports:\n- OpenRC and systemd\n- EFI and BIOS\n- ext4, zfs, btrfs filesystems\n- LUKS encryption\n- Software RAID (mdadm)\n\nPlease follow the prompts to configure your installation." 15 60

    # Create modules directory
    mkdir -p "$MODULES_DIR"
    
    # Show main menu
    show_main_menu
}

main "$@"
