#!/bin/bash

# Gentoo Installation Module

INSTALL_CONFIG_FILE="/tmp/gentoo-install-config"

log_install() {
    echo -e "${GREEN}[INSTALL]${NC} $1"
}

show_install_menu() {
    local choice
    choice=$(dialog --title "Gentoo Installation" \
        --menu "Select option:" 15 60 8 \
        1 "Stage Tarball Configuration" \
        2 "Portage Configuration" \
        3 "Kernel Configuration" \
        4 "Network Configuration" \
        5 "Begin Installation" \
        6 "Installation Progress" \
        7 "Troubleshoot" \
        8 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) stage_configuration ;;
        2) portage_configuration ;;
        3) kernel_configuration ;;
        4) network_configuration ;;
        5) begin_installation ;;
        6) show_installation_progress ;;
        7) troubleshoot ;;
        8) return ;;
    esac
    
    show_install_menu
}

stage_configuration() {
    local choice=$(dialog --title "Stage Tarball" \
        --menu "Choose stage tarball type:" 15 50 4 \
        1 "stage3-amd64 (recommended)" \
        2 "stage3-amd64-hardened" \
        3 "stage3-amd64-nomultilib" \
        4 "Custom URL" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) CONFIG[stage_tarball]="stage3-amd64" ;;
        2) CONFIG[stage_tarball]="stage3-amd64-hardened" ;;
        3) CONFIG[stage_tarball]="stage3-amd64-nomultilib" ;;
        4)
            CONFIG[stage_url]=$(dialog --title "Custom Stage URL" \
                --inputbox "Enter custom stage tarball URL:" 8 60 "http://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64.txt" \
                3>&1 1>&2 2>&3)
            ;;
    esac
}

portage_configuration() {
    local choice=$(dialog --title "Portage Configuration" \
        --menu "Portage settings:" 15 60 4 \
        1 "Gentoo ebuild repository (recommended)" \
        2 "Sync method: rsync" \
        3 "Sync method: git" \
        4 "Custom sync URL" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            CONFIG[use_gentoo_repo]="true"
            ;;
        2)
            CONFIG[sync_method]="rsync"
            ;;
        3)
            CONFIG[sync_method]="git"
            ;;
        4)
            CONFIG[custom_sync_url]=$(dialog --title "Custom Sync URL" \
                --inputbox "Enter custom sync URL:" 8 60 "" \
                3>&1 1>&2 2>&3)
            ;;
    esac
}

kernel_configuration() {
    local choice=$(dialog --title "Kernel Configuration" \
        --menu "Choose kernel type:" 15 50 4 \
        1 "genkernel (recommended for beginners)" \
        2 "Custom kernel compilation" \
        3 "Distribution kernel" \
        4 "Kernel sources only" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) CONFIG[kernel_type]="genkernel" ;;
        2) CONFIG[kernel_type]="custom" ;;
        3) CONFIG[kernel_type]="distribution" ;;
        4) CONFIG[kernel_type]="sources" ;;
    esac
}

network_configuration() {
    CONFIG[use_network]="true"
    CONFIG[network_type]=$(dialog --title "Network Configuration" \
        --menu "Choose network setup:" 10 50 3 \
        1 "DHCP (automatic)" \
        2 "Static IP" \
        3 "NetworkManager" \
        3>&1 1>&2 2>&3)
    
    case "${CONFIG[network_type]}" in
        1) CONFIG[ip_method]="dhcp" ;;
        2) CONFIG[ip_method]="static" ;;
        3) CONFIG[ip_method]="networkmanager" ;;
    esac
}

begin_installation() {
    dialog --title "Begin Installation" \
        --yesno "This will begin the Gentoo installation process.\n\nEnsure your disk configuration is correct.\n\nContinue with installation?" 12 50
    
    if [[ $? -eq 0 ]]; then
        execute_installation
    fi
}

execute_installation() {
    log_install "Starting Gentoo installation..."
    
    # Create mount points
    mkdir -p /mnt/gentoo
    
    # Mount root partition
    if [[ "${CONFIG[encrypt_root]}" == "true" ]]; then
        log_install "Mounting encrypted root partition"
        cryptsetup open "${DISK_CONFIG[root_device]}1" "${ENCRYPT_CONFIG[crypt_name]}"
        mount "/dev/mapper/${ENCRYPT_CONFIG[crypt_name]}" /mnt/gentoo
    else
        mount "${DISK_CONFIG[root_device]}1" /mnt/gentoo
    fi
    
    # Mount boot partition
    mkdir -p /mnt/gentoo/boot
    mount "${DISK_CONFIG[boot_device]}1" /mnt/gentoo/boot
    
    # Download and extract stage tarball
    log_install "Downloading stage tarball..."
    cd /mnt/gentoo
    
    local stage_url="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-*.tar.xz"
    wget "$stage_url"
    
    log_install "Extracting stage tarball..."
    tar xpf stage3-*.tar.xz --xattrs
    
    # Copy DNS info
    cp -L /etc/resolv.conf /mnt/gentoo/etc/
    
    log_install "Gentoo base installation completed!"
    dialog --msgbox "Gentoo base installation completed successfully!" 8 40
}

show_installation_progress() {
    dialog --title "Installation Progress" \
        --msgbox "Installation is in progress...\n\nPlease check the installation logs for details.\n\nThe process includes:\n- Downloading stage tarball\n- Extracting system files\n- Configuring portage\n- Compiling kernel\n- Setting up bootloader\n- Configuring system" 15 60
}

troubleshoot() {
    local logs="Common issues and solutions:\n\n"
    logs+="1. Network issues:\n"
    logs+="   - Check network configuration\n"
    logs+="   - Verify DNS settings\n\n"
    logs+="2. Disk issues:\n"
    logs+="   - Verify disk selection\n"
    logs+="   - Check partition alignment\n\n"
    logs+="3. Installation failures:\n"
    logs+="   - Check available disk space\n"
    logs+="   - Verify tarball integrity\n\n"
    logs+="For more help, visit:\nhttps://wiki.gentoo.org/wiki/Handbook"
    
    dialog --title "Troubleshooting" \
        --msgbox "$logs" 20 70
}

# Main execution
show_install_menu
