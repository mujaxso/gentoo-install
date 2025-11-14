#!/bin/bash

# Gentoo Linux Installer with TUI - Updated for latest Gentoo Handbook
# Compatible with AMD64 Handbook: Full Installation methods

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="/tmp/gentoo-install-config"
LOG_FILE="/tmp/gentoo-install.log"

# Default configuration - Updated for latest Gentoo standards
declare -gA CONFIG
CONFIG[init_system]="openrc"
CONFIG[boot_mode]="efi"
CONFIG[root_fs]="xfs"  # Changed to XFS as recommended
CONFIG[encrypt_root]="false"
CONFIG[use_raid]="false"
CONFIG[hostname]="gentoo"
CONFIG[timezone]="UTC"
CONFIG[keymap]="us"
CONFIG[stage_tarball]="stage3-amd64-openrc"  # Updated naming convention
CONFIG[kernel_type]="distribution"  # Changed to distribution kernel
CONFIG[bootloader_type]="grub2"
CONFIG[locale]="en_US.UTF-8"
CONFIG[username]="gentoo"
CONFIG[profile]="default/linux/amd64/23.0/desktop"  # Added profile selection
CONFIG[use_binary_host]="false"  # Binary package host support

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Initialize log file
init_log() {
    echo "Gentoo Linux Installer Log - $(date)" > "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
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
    > "$CONFIG_FILE"
    for key in "${!CONFIG[@]}"; do
        echo "CONFIG[$key]=\"${CONFIG[$key]}\"" >> "$CONFIG_FILE"
    done
}

# Main menu - Updated with latest Gentoo Handbook structure
show_main_menu() {
    local choice
    while true; do
        choice=$(dialog --clear --title "Gentoo Linux Installer - AMD64 Handbook Compatible" \
            --menu "Select installation step:" 22 70 12 \
            1 "System Information & Profile Selection" \
            2 "Disk Configuration (GPT/MBR)" \
            3 "Filesystem Setup (XFS recommended)" \
            4 "Encryption (LUKS)" \
            5 "Stage File Selection & Download" \
            6 "Portage Configuration" \
            7 "Kernel Setup (Distribution/Manual)" \
            8 "System Configuration" \
            9 "Bootloader Installation" \
            10 "Finalize Installation" \
            11 "Review & Execute" \
            12 "Exit" \
            3>&1 1>&2 2>&3)

        case $choice in
            1) show_system_info_menu ;;
            2) source "$MODULES_DIR/disk.sh" ;;
            3) source "$MODULES_DIR/filesystem.sh" ;;
            4) source "$MODULES_DIR/encryption.sh" ;;
            5) source "$MODULES_DIR/stage.sh" ;;
            6) source "$MODULES_DIR/portage.sh" ;;
            7) source "$MODULES_DIR/kernel.sh" ;;
            8) source "$MODULES_DIR/config.sh" ;;
            9) source "$MODULES_DIR/bootloader.sh" ;;
            10) source "$MODULES_DIR/finalize.sh" ;;
            11) show_review_menu ;;
            12) confirm_exit ;;
            *) break ;;
        esac
    done
}

# System information menu - Updated with profile selection
show_system_info_menu() {
    local choice
    choice=$(dialog --title "System Information & Profile" \
        --menu "Select option:" 18 70 8 \
        1 "Select Init System (Current: ${CONFIG[init_system]})" \
        2 "Select Boot Mode (Current: ${CONFIG[boot_mode]})" \
        3 "Choose Profile (Current: ${CONFIG[profile]})" \
        4 "Set Hostname (Current: ${CONFIG[hostname]})" \
        5 "Set Timezone (Current: ${CONFIG[timezone]})" \
        6 "Set Keymap (Current: ${CONFIG[keymap]})" \
        7 "Enable Binary Package Host" \
        8 "Back" \
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
                1 "EFI (UEFI)" \
                2 "BIOS/Legacy" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
        3)
            select_profile
            show_system_info_menu
            ;;
        4)
            CONFIG[hostname]=$(dialog --title "Hostname" \
                --inputbox "Enter hostname:" 8 40 "${CONFIG[hostname]}" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
        5)
            CONFIG[timezone]=$(dialog --title "Timezone" \
                --inputbox "Enter timezone (e.g., UTC, America/New_York):" 8 40 "${CONFIG[timezone]}" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
        6)
            CONFIG[keymap]=$(dialog --title "Keymap" \
                --inputbox "Enter keymap (e.g., us, uk, de):" 8 40 "${CONFIG[keymap]}" \
                3>&1 1>&2 2>&3)
            show_system_info_menu
            ;;
        7)
            toggle_binary_host
            show_system_info_menu
            ;;
    esac
}

# Profile selection - New function based on handbook
select_profile() {
    local choice=$(dialog --title "Profile Selection" \
        --menu "Choose system profile:" 18 60 10 \
        1 "default/linux/amd64/23.0 (base)" \
        2 "default/linux/amd64/23.0/desktop (desktop)" \
        3 "default/linux/amd64/23.0/desktop/gnome" \
        4 "default/linux/amd64/23.0/desktop/kde" \
        5 "default/linux/amd64/23.0/no-multilib (pure 64-bit)" \
        6 "default/linux/amd64/23.0/no-multilib/desktop" \
        7 "default/linux/amd64/23.0/hardened (security)" \
        8 "default/linux/amd64/23.0/desktop/hardened" \
        9 "Custom profile" \
        10 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) CONFIG[profile]="default/linux/amd64/23.0" ;;
        2) CONFIG[profile]="default/linux/amd64/23.0/desktop" ;;
        3) CONFIG[profile]="default/linux/amd64/23.0/desktop/gnome" ;;
        4) CONFIG[profile]="default/linux/amd64/23.0/desktop/kde" ;;
        5) CONFIG[profile]="default/linux/amd64/23.0/no-multilib" ;;
        6) CONFIG[profile]="default/linux/amd64/23.0/no-multilib/desktop" ;;
        7) CONFIG[profile]="default/linux/amd64/23.0/hardened" ;;
        8) CONFIG[profile]="default/linux/amd64/23.0/desktop/hardened" ;;
        9)
            CONFIG[profile]=$(dialog --title "Custom Profile" \
                --inputbox "Enter custom profile path:" 8 60 "${CONFIG[profile]}" \
                3>&1 1>&2 2>&3)
            ;;
    esac
}

# Toggle binary package host
toggle_binary_host() {
    if [[ "${CONFIG[use_binary_host]}" == "true" ]]; then
        CONFIG[use_binary_host]="false"
    else
        CONFIG[use_binary_host]="true"
    fi
}

# Review menu - Updated with new options
show_review_menu() {
    local summary="Installation Summary (AMD64 Handbook Compatible):\n\n"
    summary+="Init System: ${CONFIG[init_system]}\n"
    summary+="Boot Mode: ${CONFIG[boot_mode]}\n"
    summary+="Profile: ${CONFIG[profile]}\n"
    summary+="Root Filesystem: ${CONFIG[root_fs]} (recommended: xfs)\n"
    summary+="Encryption: ${CONFIG[encrypt_root]}\n"
    summary+="RAID: ${CONFIG[use_raid]}\n"
    summary+="Binary Package Host: ${CONFIG[use_binary_host]}\n"
    summary+="Hostname: ${CONFIG[hostname]}\n"
    summary+="Timezone: ${CONFIG[timezone]}\n"
    summary+="Stage Tarball: ${CONFIG[stage_tarball]}\n"
    summary+="Kernel: ${CONFIG[kernel_type]}\n"
    summary+="Bootloader: ${CONFIG[bootloader_type]}\n"
    summary+="Locale: ${CONFIG[locale]}\n"

    dialog --title "Review Configuration" \
        --yesno "$summary\n\nProceed with installation?" 22 70
}

# Confirm exit
confirm_exit() {
    dialog --title "Exit" \
        --yesno "Are you sure you want to exit?" 7 30
    [[ $? -eq 0 ]] && exit 0
}

# Check dependencies - Updated for latest requirements
check_dependencies() {
    local deps=("fdisk" "mkfs.xfs" "mkfs.ext4" "mkfs.btrfs" "zfs" "cryptsetup" "mdadm" "wget" "gpg")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        warn "Missing dependencies: ${missing_deps[*]}"
        dialog --title "Missing Dependencies" \
            --msgbox "The following dependencies are missing:\n${missing_deps[*]}\n\nPlease install them with:\nemerge ${missing_deps[*]}" 12 50
        return 1
    fi
}

# Initialize
main() {
    # Initialize log
    init_log
    
    # Check if dialog is available
    if ! command -v dialog &> /dev/null; then
        error "dialog is required but not installed. Please install: emerge sys-apps/dialog"
        exit 1
    fi

    # Check for root
    check_root
    
    # Load existing config
    load_config
    
    # Check dependencies
    check_dependencies
    
    # Welcome message - Updated for AMD64 Handbook compatibility
    dialog --title "Gentoo Linux Installer - AMD64 Handbook Compatible" \
        --msgbox "Welcome to the Gentoo Linux Installer!\n\nThis installer follows the latest AMD64 Handbook methods:\n- XFS filesystem (recommended)\n- fdisk partitioning (GPT/MBR)\n- Stage3 tarballs with proper naming\n- Profile-based system configuration\n- Binary package host support\n- Distribution kernel support\n- Modern bootloader options (GRUB2, systemd-boot, EFI stub)\n\nMinimum requirements:\n- x86-64 CPU (AMD64/Intel 64)\n- 2GB RAM, 8GB disk space\n- Internet connection\n\nPlease follow the prompts to configure your installation." 18 70

    # Create modules directory
    mkdir -p "$MODULES_DIR"
    
    # Save initial config
    save_config
    
    # Show main menu
    show_main_menu
}

main "$@"
