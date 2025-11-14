#!/bin/bash

# System Configuration Module

log_config() {
    echo -e "${GREEN}[CONFIG]${NC} $1"
}

show_config_menu() {
    local choice
    choice=$(dialog --title "System Configuration" \
        --menu "Select option:" 15 60 9 \
        1 "User Configuration" \
        2 "Service Configuration" \
        3 "Locale Settings" \
        4 "Clock & Timezone" \
        5 "Hostname & DNS" \
        6 "Bootloader Configuration" \
        7 "Final System Setup" \
        8 "Generate fstab" \
        9 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) user_configuration ;;
        2) service_configuration ;;
        3) locale_configuration ;;
        4) clock_configuration ;;
        5) network_config ;;
        6) bootloader_config ;;
        7) final_setup ;;
        8) generate_fstab ;;
        9) return ;;
    esac
    
    show_config_menu
}

user_configuration() {
    CONFIG[root_password]=$(dialog --title "Root Password" \
        --passwordbox "Enter root password:" 8 40 "" \
        3>&1 1>&2 2>&3)
    
    CONFIG[username]=$(dialog --title "User Configuration" \
        --inputbox "Enter username for regular user:" 8 40 "gentoo" \
        3>&1 1>&2 2>&3)
    
    CONFIG[user_password]=$(dialog --title "User Password" \
        --passwordbox "Enter user password for $CONFIG[username]:" 8 40 "" \
        3>&1 1>&2 2>&3)
    
    CONFIG[add_to_wheel]=$(dialog --title "Sudo Access" \
        --yesno "Add user to wheel group (sudo access)?" 7 30)
    
    [[ $? -eq 0 ]] && CONFIG[enable_sudo]="true" || CONFIG[enable_sudo]="false"
}

service_configuration() {
    local services=""
    
    # Basic services
    CONFIG[enable_ssh]=$(dialog --title "SSH Service" \
        --yesno "Enable SSH service?" 7 30)
    
    CONFIG[enable_networkmanager]=$(dialog --title "NetworkManager" \
        --yesno "Enable NetworkManager?" 7 30)
    
    # Init system specific services
    if [[ "${CONFIG[init_system]}" == "systemd" ]]; then
        CONFIG[enable_systemd_networkd]=$(dialog --title "systemd-networkd" \
            --yesno "Enable systemd-networkd?" 7 30)
    fi
}

locale_configuration() {
    CONFIG[locale]=$(dialog --title "Locale Selection" \
        --inputbox "Enter locale (e.g., en_US.UTF-8):" 8 40 "en_US.UTF-8" \
        3>&1 1>&2 2>&3)
    
    CONFIG[console_locale]=$(dialog --title "Console Locale" \
        --inputbox "Enter console locale:" 8 40 "${CONFIG[locale]}" \
        3>&1 1>&2 2>&3)
}

clock_configuration() {
    CONFIG[timezone]=$(dialog --title "Timezone" \
        --inputbox "Enter timezone (e.g., America/New_York):" 8 40 "${CONFIG[timezone]}" \
        3>&1 1>&2 2>&3)
    
    CONFIG[hardware_clock]=$(dialog --title "Hardware Clock" \
        --menu "Hardware clock mode:" 10 50 2 \
        1 "UTC (recommended)" \
        2 "Local time" \
        3>&1 1>&2 2>&3)
    
    case $choice in
        1) CONFIG[hwclock_mode]="UTC" ;;
        2) CONFIG[hwclock_mode]="local" ;;
    esac
}

network_config() {
    CONFIG[hostname]=$(dialog --title "Hostname" \
        --inputbox "Enter hostname:" 8 40 "${CONFIG[hostname]}" \
        3>&1 1>&2 2>&3)
    
    CONFIG[domainname]=$(dialog --title "Domainname" \
        --inputbox "Enter domainname (optional):" 8 40 "" \
        3>&1 1>&2 2>&3)
}

bootloader_config() {
    CONFIG[bootloader]=$(dialog --title "Bootloader" \
        --menu "Choose bootloader:" 15 50 4 \
        1 "GRUB2 (recommended)" \
        2 "systemd-boot" \
        3 "rEFInd" \
        4 "Custom" \
        3>&1 1>&2 2>&3)
    
    case $choice in
        1) CONFIG[bootloader_type]="grub2" ;;
        2) CONFIG[bootloader_type]="systemd-boot" ;;
        3) CONFIG[bootloader_type]="refind" ;;
        4) CONFIG[bootloader_type]="custom" ;;
    esac
    
    # GRUB specific
    if [[ "${CONFIG[bootloader_type]}" == "grub2" ]]; then
        CONFIG[grub_install_target]=$(dialog --title "GRUB Install Target" \
            --menu "GRUB installation target:" 10 50 2 \
            1 "Boot device (recommended)" \
            2 "EFI System Partition" \
            3>&1 1>&2 2>&3)
    fi
}

final_setup() {
    local summary="Final system configuration:\n\n"
    summary+="Root password: ${CONFIG[root_password]:-not set}\n"
    summary+="User: ${CONFIG[username]:-not set}\n"
    summary+="Locale: ${CONFIG[locale]:-not set}\n"
    summary+="Hostname: ${CONFIG[hostname]:-not set}\n"
    summary+="Bootloader: ${CONFIG[bootloader_type]:-not set}\n"
    summary+="Init system: ${CONFIG[init_system]}\n\n"
    summary+="Apply these settings?"
    
    dialog --title "Final Setup" \
        --yesno "$summary" 15 60
}

generate_fstab() {
    local fstab_content="# /etc/fstab: static file system information\n\n"
    
    # Root filesystem
    fstab_content+="/dev/root    /           ${CONFIG[root_fs]}    defaults,noatime    0 1\n"
    
    # Boot filesystem
    fstab_content+="${DISK_CONFIG[boot_device]}1    /boot       vfat    defaults,noatime    0 2\n"
    
    # Swap (if configured)
    if [[ -n "${DISK_CONFIG[swap_device]}" ]]; then
        fstab_content+="${DISK_CONFIG[swap_device]}    none        swap    sw              0 0\n"
    fi
    
    # Separate partitions (if configured)
    if [[ "${FS_CONFIG[separate_home]}" == "true" ]]; then
        fstab_content+="/dev/home    /home       ${FS_CONFIG[home_fs]}    defaults,noatime    0 2\n"
    fi
    
    if [[ "${FS_CONFIG[separate_var]}" == "true" ]]; then
        fstab_content+="/dev/var     /var        ${FS_CONFIG[var_fs]}    defaults,noatime    0 2\n"
    fi
    
    echo "$fstab_content" > /tmp/gentoo-fstab
    dialog --msgbox "fstab generated successfully at /tmp/gentoo-fstab" 8 40
}

# Main execution
show_config_menu
