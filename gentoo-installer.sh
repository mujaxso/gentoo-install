#!/bin/bash

# Gentoo Linux Installer with TUI - Updated for latest Gentoo Handbook
# Compatible with AMD64 Handbook: Full Installation methods
# Now with auto-distro detection and dependency management

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

# Distribution detection
DISTRO=""
DISTRO_NAME=""
PACKAGE_MANAGER=""

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
CONFIG[auto_install_deps]="false"  # Auto-install missing dependencies

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

# Detect distribution and package manager
detect_distribution() {
    log "Detecting current distribution..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_NAME="$ID"
        DISTRO="$ID"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO_NAME="debian"
        DISTRO="debian"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO_NAME="arch"
        DISTRO="arch"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO_NAME="rhel"
        DISTRO="rhel"
    elif [[ -f /etc/gentoo-release ]]; then
        DISTRO_NAME="gentoo"
        DISTRO="gentoo"
    elif [[ -f /etc/opensuse-release ]]; then
        DISTRO_NAME="opensuse"
        DISTRO="opensuse"
    elif [[ -f /etc/alpine-release ]]; then
        DISTRO_NAME="alpine"
        DISTRO="alpine"
    elif [[ -f /etc/slackware-version ]]; then
        DISTRO_NAME="slackware"
        DISTRO="slackware"
    else
        DISTRO_NAME="unknown"
        DISTRO="unknown"
    fi
    
    # Detect package manager
    case "$DISTRO" in
        debian|ubuntu|linuxmint|pop|elementary)
            PACKAGE_MANAGER="apt"
            ;;
        arch|manjaro|endeavouros)
            PACKAGE_MANAGER="pacman"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            PACKAGE_MANAGER="dnf"
            ;;
        opensuse*|suse)
            PACKAGE_MANAGER="zypper"
            ;;
        gentoo)
            PACKAGE_MANAGER="emerge"
            ;;
        alpine)
            PACKAGE_MANAGER="apk"
            ;;
        slackware)
            PACKAGE_MANAGER="slackpkg"
            ;;
        *)
            PACKAGE_MANAGER="unknown"
            ;;
    esac
    
    log "Detected distribution: $DISTRO_NAME ($DISTRO)"
    log "Package manager: $PACKAGE_MANAGER"
}

# Get required dependencies for different distros
get_distro_dependencies() {
    local distro="$1"
    
    case "$distro" in
        debian|ubuntu|linuxmint|pop|elementary)
            echo "dialog fdisk xfsprogs e2fsprogs btrfs-progs cryptsetup mdadm wget gnupg"
            ;;
        arch|manjaro|endeavouros)
            echo "dialog fdisk xfsprogs e2fsprogs btrfs-progs cryptsetup mdadm wget gnupg"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            echo "dialog util-linux xfsprogs e2fsprogs btrfs-progs cryptsetup mdadm wget gnupg"
            ;;
        opensuse*|suse)
            echo "dialog util-linux xfsprogs e2fsprogs btrfsprogs cryptsetup mdadm wget gnupg2"
            ;;
        gentoo)
            echo "sys-apps/dialog sys-block/fdisk sys-fs/xfsprogs sys-fs/e2fsprogs sys-fs/btrfs-progs sys-fs/cryptsetup sys-fs/mdadm net-misc/wget app-crypt/gnupg"
            ;;
        alpine)
            echo "dialog util-linux xfsprogs e2fsprogs btrfs-progs cryptsetup mdadm wget gnupg"
            ;;
        slackware)
            echo "dialog util-linux xfsprogs e2fsprogs btrfs-progs cryptsetup mdadm wget gnupg"
            ;;
        *)
            echo "dialog fdisk xfsprogs e2fsprogs btrfs-progs cryptsetup mdadm wget gnupg"
            ;;
    esac
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    
    case "$PACKAGE_MANAGER" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        pacman)
            pacman -Qi "$package" &>/dev/null
            ;;
        dnf)
            dnf list installed "$package" &>/dev/null
            ;;
        zypper)
            zypper search -i "$package" &>/dev/null
            ;;
        emerge)
            qlist "$package" &>/dev/null || emerge --pretend "$package" &>/dev/null
            ;;
        apk)
            apk info "$package" &>/dev/null
            ;;
        slackpkg)
            slackpkg search "$package" &>/dev/null
            ;;
        *)
            # Fallback: check if command exists
            command -v "$package" &>/dev/null
            ;;
    esac
}

# Install missing dependencies
install_dependencies() {
    local deps=($@)
    local missing_deps=()
    local failed_deps=()
    
    # Check which dependencies are missing
    for dep in "${deps[@]}"; do
        if ! is_package_installed "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log "All dependencies are already installed"
        return 0
    fi
    
    warn "Missing dependencies: ${missing_deps[*]}"
    
    # Interactive installation prompt
    if dialog --title "Install Dependencies" \
        --yesno "The following dependencies are missing:\n${missing_deps[*]}\n\nWould you like to install them automatically?\n\nThis requires $PACKAGE_MANAGER access." 15 60; then
        
        log "Installing missing dependencies with $PACKAGE_MANAGER..."
        
        for dep in "${missing_deps[@]}"; do
            if install_single_dependency "$dep"; then
                success "Successfully installed: $dep"
            else
                failed_deps+=("$dep")
                error "Failed to install: $dep"
            fi
        done
        
        if [[ ${#failed_deps[@]} -eq 0 ]]; then
            success "All dependencies installed successfully"
            return 0
        else
            error "Failed to install: ${failed_deps[*]}"
            return 1
        fi
    else
        error "User declined to install dependencies"
        error "Please install manually using: $PACKAGE_MANAGER ${missing_deps[*]}"
        return 1
    fi
}

# Install a single dependency
install_single_dependency() {
    local package="$1"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt update && apt install -y "$package"
            ;;
        pacman)
            pacman -Sy --noconfirm "$package"
            ;;
        dnf)
            dnf install -y "$package"
            ;;
        zypper)
            zypper install -y "$package"
            ;;
        emerge)
            emerge --ask "$package"
            ;;
        apk)
            apk add "$package"
            ;;
        slackpkg)
            slackpkg install "$package"
            ;;
        *)
            error "Unknown package manager: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
}

# Interactive dependency installation menu
interactive_dependency_menu() {
    local deps=($(get_distro_dependencies "$DISTRO"))
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! is_package_installed "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        dialog --title "Dependencies Check" \
            --msgbox "All required dependencies are already installed!\n\nDistribution: $DISTRO_NAME\nPackage Manager: $PACKAGE_MANAGER" 10 50
        return
    fi
    
    local choice
    choice=$(dialog --title "Dependencies Installation" \
        --menu "Select option for $DISTRO_NAME ($PACKAGE_MANAGER):" 18 70 4 \
        1 "Auto-install all missing dependencies" \
        2 "Install specific dependencies" \
        3 "View missing dependencies list" \
        4 "Skip dependency installation" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            if install_dependencies "${missing_deps[@]}"; then
                CONFIG[auto_install_deps]="true"
                save_config
            else
                dialog --title "Installation Failed" \
                    --msgbox "Some dependencies could not be installed.\n\nPlease install manually:\n$PACKAGE_MANAGER ${missing_deps[*]}" 12 50
            fi
            ;;
        2)
            install_specific_dependencies "${missing_deps[@]}"
            ;;
        3)
            show_missing_dependencies "${missing_deps[@]}"
            interactive_dependency_menu
            ;;
        4)
            warn "Skipping dependency installation"
            ;;
    esac
}

# Install specific dependencies
install_specific_dependencies() {
    local deps=("$@")
    local selected_deps=()
    
    for dep in "${deps[@]}"; do
        if dialog --title "Install $dep" \
            --yesno "Install $dep?" 8 40; then
            selected_deps+=("$dep")
        fi
    done
    
    if [[ ${#selected_deps[@]} -gt 0 ]]; then
        install_dependencies "${selected_deps[@]}"
    else
        warn "No dependencies selected for installation"
    fi
}

# Show missing dependencies
show_missing_dependencies() {
    local deps=("$@")
    local deps_list=""
    
    for i in "${!deps[@]}"; do
        deps_list="$deps_list $((i+1)) ${deps[$i]}"
    done
    
    dialog --title "Missing Dependencies - $DISTRO_NAME" \
        --msgbox "Missing dependencies for $DISTRO_NAME ($PACKAGE_MANAGER):\n\n${deps[*]}\n\nInstall command:\n$PACKAGE_MANAGER install ${deps[*]}" 20 70
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
            --menu "Select installation step:" 22 70 13 \
            0 "Distribution & Dependencies Management" \
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
            0) show_dependency_management ;;
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

# Dependency management menu
show_dependency_management() {
    local choice
    choice=$(dialog --title "Distribution & Dependencies" \
        --menu "Distribution: $DISTRO_NAME ($PACKAGE_MANAGER)" 15 70 5 \
        1 "Check & Install Dependencies" \
        2 "Dependency Information" \
        3 "Distribution Details" \
        4 "Re-detect Distribution" \
        5 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) interactive_dependency_menu ;;
        2) show_dependency_info ;;
        3) show_distribution_details ;;
        4) 
            detect_distribution
            dialog --msgbox "Distribution re-detected:\n\nName: $DISTRO_NAME\nID: $DISTRO\nPackage Manager: $PACKAGE_MANAGER" 10 50
            show_dependency_management
            ;;
        5) return ;;
    esac
    
    show_dependency_management
}

# Show dependency information
show_dependency_info() {
    local deps=($(get_distro_dependencies "$DISTRO"))
    local installed_deps=()
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if is_package_installed "$dep"; then
            installed_deps+=("$dep ✓")
        else
            missing_deps+=("$dep ✗")
        fi
    done
    
    local info="Dependency Status for $DISTRO_NAME\n\n"
    info+="INSTALLED (${#installed_deps[@]}):\n"
    info+="${installed_deps[*]}\n\n"
    info+="MISSING (${#missing_deps[@]}):\n"
    info+="${missing_deps[*]}\n\n"
    info+="Install command:\n$PACKAGE_MANAGER install ${missing_deps[*]}"
    
    dialog --title "Dependency Information" \
        --msgbox "$info" 25 80
}

# Show distribution details
show_distribution_details() {
    local details="Distribution Detection Results\n\n"
    details+="Distribution Name: $DISTRO_NAME\n"
    details+="Distribution ID: $DISTRO\n"
    details+="Package Manager: $PACKAGE_MANAGER\n\n"
    
    case "$PACKAGE_MANAGER" in
        apt)
            details+="Supported Distros: Debian, Ubuntu, Linux Mint, Pop!_OS, Elementary OS\n"
            details+="Update: apt update\n"
            details+="Install: apt install <package>\n"
            ;;
        pacman)
            details+="Supported Distros: Arch Linux, Manjaro, EndeavourOS\n"
            details+="Update: pacman -Sy\n"
            details+="Install: pacman -S <package>\n"
            ;;
        dnf)
            details+="Supported Distros: Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux\n"
            details+="Update: dnf check-update\n"
            details+="Install: dnf install <package>\n"
            ;;
        zypper)
            details+="Supported Distros: openSUSE, SUSE Linux Enterprise\n"
            details+="Update: zypper refresh\n"
            details+="Install: zypper install <package>\n"
            ;;
        emerge)
            details+="Supported Distros: Gentoo Linux\n"
            details+="Update: emerge --sync\n"
            details+="Install: emerge <package>\n"
            ;;
        apk)
            details+="Supported Distros: Alpine Linux\n"
            details+="Update: apk update\n"
            details+="Install: apk add <package>\n"
            ;;
        *)
            details+="Package manager not fully supported\n"
            details+="Manual dependency installation may be required\n"
            ;;
    esac
    
    dialog --title "Distribution Details" \
        --msgbox "$details" 20 70
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
    summary+="Current Distribution: $DISTRO_NAME ($PACKAGE_MANAGER)\n"
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

# Check dependencies - Now distribution-aware
check_dependencies() {
    local deps=($(get_distro_dependencies "$DISTRO"))
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! is_package_installed "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        warn "Missing dependencies for $DISTRO_NAME: ${missing_deps[*]}"
        
        if [[ "${CONFIG[auto_install_deps]}" == "true" ]]; then
            # Auto-install if enabled
            if install_dependencies "${missing_deps[@]}"; then
                return 0
            else
                return 1
            fi
        else
            dialog --title "Missing Dependencies - $DISTRO_NAME" \
                --msgbox "The following dependencies are missing for $DISTRO_NAME:\n${missing_deps[*]}\n\nPlease go to 'Distribution & Dependencies Management' to install them." 12 50
            return 1
        fi
    fi
    
    return 0
}

# Initialize
main() {
    # Initialize log
    init_log
    
    # Detect distribution first
    detect_distribution
    
    # Check if dialog is available
    if ! command -v dialog &> /dev/null; then
        error "dialog is required but not installed"
        error "Please install dialog using: $PACKAGE_MANAGER install dialog"
        exit 1
    fi

    # Check for root
    check_root
    
    # Load existing config
    load_config
    
    # Welcome message - Updated for multi-distro support
    dialog --title "Gentoo Linux Installer - Multi-Distribution Support" \
        --msgbox "Welcome to the Gentoo Linux Installer!\n\nDetected Distribution: $DISTRO_NAME ($PACKAGE_MANAGER)\n\nThis installer follows the latest AMD64 Handbook methods:\n- XFS filesystem (recommended)\n- fdisk partitioning (GPT/MBR)\n- Stage3 tarballs with proper naming\n- Profile-based system configuration\n- Binary package host support\n- Distribution kernel support\n- Modern bootloader options (GRUB2, systemd-boot, EFI stub)\n\nSupported Distributions:\n• Debian/Ubuntu (apt)\n• Arch Linux (pacman) \n• Fedora/RHEL (dnf)\n• openSUSE (zypper)\n• Gentoo (emerge)\n• Alpine (apk)\n\nMinimum requirements:\n- x86-64 CPU (AMD64/Intel 64)\n- 2GB RAM, 8GB disk space\n- Internet connection\n\nPlease follow the prompts to configure your installation." 22 70

    # Create modules directory
    mkdir -p "$MODULES_DIR"
    
    # Save initial config
    save_config
    
    # Auto-check dependencies on startup
    if ! check_dependencies; then
        warn "Please install missing dependencies before continuing"
    fi
    
    # Show main menu
    show_main_menu
}

main "$@"
