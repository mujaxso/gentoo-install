#!/bin/bash

# System Configuration Module

CONFIG_CONFIG_FILE="/tmp/gentoo-system-config"

declare -gA SYSTEM_CONFIG
SYSTEM_CONFIG[root_password]=""
SYSTEM_CONFIG[username]="gentoo"
SYSTEM_CONFIG[user_password]=""
SYSTEM_CONFIG[enable_sudo]="false"
SYSTEM_CONFIG[enable_ssh]="false"
SYSTEM_CONFIG[enable_networkmanager]="false"
SYSTEM_CONFIG[locale]="en_US.UTF-8"
SYSTEM_CONFIG[timezone]="UTC"

log_config() {
    echo -e "${GREEN}[CONFIG]${NC} $1" | tee -a "/tmp/gentoo-install.log"
}

show_config_menu() {
    local choice
    choice=$(dialog --title "System Configuration" \
        --menu "Select option:" 15 60 10 \
        1 "User Configuration" \
        2 "Service Configuration" \
        3 "Locale Settings" \
        4 "Clock & Timezone" \
        5 "Hostname & DNS" \
        6 "Bootloader Configuration" \
        7 "Security Settings" \
        8 "Generate fstab" \
        9 "Preview Configuration" \
        10 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) user_configuration ;;
        2) service_configuration ;;
        3) locale_configuration ;;
        4) clock_configuration ;;
        5) network_config ;;
        6) bootloader_config ;;
        7) security_config ;;
        8) generate_fstab ;;
        9) preview_config ;;
        10) return ;;
    esac
    
    show_config_menu
}

user_configuration() {
    SYSTEM_CONFIG[root_password]=$(dialog --title "Root Password" \
        --passwordbox "Enter root password:" 8 40 "" \
        3>&1 1>&2 2>&3)
    
    SYSTEM_CONFIG[username]=$(dialog --title "User Configuration" \
        --inputbox "Enter username for regular user:" 8 40 "${SYSTEM_CONFIG[username]}" \
        3>&1 1>&2 2>&3)
    
    SYSTEM_CONFIG[user_password]=$(dialog --title "User Password" \
        --passwordbox "Enter password for ${SYSTEM_CONFIG[username]}:" 8 40 "" \
        3>&1 1>&2 2>&3)
    
    if dialog --title "Sudo Access" \
        --yesno "Add ${SYSTEM_CONFIG[username]} to wheel group for sudo access?" 7 30; then
        SYSTEM_CONFIG[enable_sudo]="true"
    else
        SYSTEM_CONFIG[enable_sudo]="false"
    fi
    
    # Update global config
    CONFIG[root_password]="${SYSTEM_CONFIG[root_password]}"
    CONFIG[username]="${SYSTEM_CONFIG[username]}"
    CONFIG[user_password]="${SYSTEM_CONFIG[user_password]}"
    CONFIG[enable_sudo]="${SYSTEM_CONFIG[enable_sudo]}"
}

service_configuration() {
    if dialog --title "SSH Service" \
        --yesno "Enable SSH service for remote access?" 7 30; then
        SYSTEM_CONFIG[enable_ssh]="true"
    else
        SYSTEM_CONFIG[enable_ssh]="false"
    fi
    
    if dialog --title "NetworkManager" \
        --yesno "Enable NetworkManager for easy network management?" 7 30; then
        SYSTEM_CONFIG[enable_networkmanager]="true"
    else
        SYSTEM_CONFIG[enable_networkmanager]="false"
    fi
    
    # Update global config
    CONFIG[enable_ssh]="${SYSTEM_CONFIG[enable_ssh]}"
    CONFIG[enable_networkmanager]="${SYSTEM_CONFIG[enable_networkmanager]}"
}

locale_configuration() {
    SYSTEM_CONFIG[locale]=$(dialog --title "Locale Selection" \
        --inputbox "Enter locale (e.g., en_US.UTF-8):" 8 40 "${SYSTEM_CONFIG[locale]}" \
        3>&1 1>&2 2>&3)
    
    # Update global config
    CONFIG[locale]="${SYSTEM_CONFIG[locale]}"
}

clock_configuration() {
    SYSTEM_CONFIG[timezone]=$(dialog --title "Timezone" \
        --inputbox "Enter timezone (e.g., America/New_York):" 8 40 "${SYSTEM_CONFIG[timezone]}" \
        3>&1 1>&2 2>&3)
    
    local hw_choice=$(dialog --title "Hardware Clock" \
        --menu "Hardware clock mode:" 10 50 2 \
        1 "UTC (recommended)" \
        2 "Local time" \
        3>&1 1>&2 2>&3)
    
    case $hw_choice in
        1) CONFIG[hwclock_mode]="UTC" ;;
        2) CONFIG[hwclock_mode]="local" ;;
    esac
    
    # Update global config
    CONFIG[timezone]="${SYSTEM_CONFIG[timezone]}"
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
    local choice=$(dialog --title "Bootloader" \
        --menu "Choose bootloader:" 15 50 4 \
        1 "GRUB2 (recommended)" \
        2 "systemd-boot" \
        3 "rEFInd" \
        4 "Custom/Advanced" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) CONFIG[bootloader_type]="grub2" ;;
        2) CONFIG[bootloader_type]="systemd-boot" ;;
        3) CONFIG[bootloader_type]="refind" ;;
        4) CONFIG[bootloader_type]="custom" ;;
    esac
    
    # GRUB specific options
    if [[ "${CONFIG[bootloader_type]}" == "grub2" ]]; then
        CONFIG[grub_theme]=$(dialog --title "GRUB Theme" \
            --inputbox "Enter GRUB theme (optional):" 8 40 "" \
            3>&1 1>&2 2>&3)
        
        CONFIG[grub_timeout]=$(dialog --title "GRUB Timeout" \
            --inputbox "Enter GRUB timeout in seconds:" 8 40 "5" \
            3>&1 1>&2 2>&3)
    fi
}

security_config() {
    local security_options="Security Configuration:\n\n"
    
    # Firewall
    if dialog --title "Firewall" \
        --yesno "Enable firewall (iptables)?" 7 30; then
        CONFIG[enable_firewall]="true"
    else
        CONFIG[enable_firewall]="false"
    fi
    
    # Fail2ban
    if dialog --title "Fail2ban" \
        --yesno "Install and configure fail2ban for intrusion prevention?" 7 30; then
        CONFIG[enable_fail2ban]="true"
    else
        CONFIG[enable_fail2ban]="false"
    fi
    
    # Automatic updates
    if dialog --title "Automatic Updates" \
        --yesno "Enable automatic security updates?" 7 30; then
        CONFIG[enable_auto_updates]="true"
    else
        CONFIG[enable_auto_updates]="false"
    fi
}

generate_fstab() {
    local fstab_content="# /etc/fstab: static file system information
# Generated by Gentoo Installer

"
    
    # Root filesystem
    if [[ "${CONFIG[encrypt_root]}" == "true" ]]; then
        fstab_content+="# Encrypted root filesystem\n"
        fstab_content+="/dev/mapper/${ENCRYPT_CONFIG[crypt_name]}    /           ${CONFIG[root_fs]}    defaults,noatime    0 1\n\n"
    else
        fstab_content+="# Root filesystem\n"
        fstab_content+="${DISK_CONFIG[root_device]}1    /           ${CONFIG[root_fs]}    defaults,noatime    0 1\n\n"
    fi
    
    # Boot filesystem
    fstab_content+="# Boot filesystem\n"
    fstab_content+="${DISK_CONFIG[boot_device]}1    /boot       ${FS_CONFIG[boot_fs]:-vfat}    defaults,noatime    0 2\n\n"
    
    # Swap (if configured)
    if [[ -n "${DISK_CONFIG[swap_device]}" ]]; then
        fstab_content+="# Swap partition\n"
        fstab_content+="${DISK_CONFIG[swap_device]}    none        swap    sw              0 0\n\n"
    fi
    
    # tmpfs for temporary files
    fstab_content+="# Temporary files\n"
    fstab_content+="tmpfs       /tmp        tmpfs   defaults,size=2g,mode=1777    0 0\n"
    fstab_content+="tmpfs       /var/tmp    tmpfs   defaults,size=1g             0 0\n\n"
    
    # Separate partitions (if configured)
    if [[ "${FS_CONFIG[separate_home]}" == "true" ]]; then
        fstab_content+="# Home partition\n"
        fstab_content+="/dev/home    /home       ${FS_CONFIG[home_fs]}    defaults,noatime    0 2\n\n"
    fi
    
    if [[ "${FS_CONFIG[separate_var]}" == "true" ]]; then
        fstab_content+="# Var partition\n"
        fstab_content+="/dev/var     /var        ${FS_CONFIG[var_fs]}    defaults,noatime    0 2\n\n"
    fi
    
    echo "$fstab_content" > /tmp/gentoo-fstab
    log_config "fstab generated at /tmp/gentoo-fstab"
    
    dialog --msgbox "fstab generated successfully!\n\nPreview the content?" 8 40
}

preview_config() {
    local summary="System Configuration Preview:\n\n"
    summary+="Users:\n"
    summary+="  Root password: ${SYSTEM_CONFIG[root_password]:-not set}\n"
    summary+="  Regular user: ${SYSTEM_CONFIG[username]:-not set}\n"
    summary+="  Sudo access: ${SYSTEM_CONFIG[enable_sudo]}\n\n"
    summary+="Services:\n"
    summary+="  SSH: ${SYSTEM_CONFIG[enable_ssh]}\n"
    summary+="  NetworkManager: ${SYSTEM_CONFIG[enable_networkmanager]}\n\n"
    summary+="Localization:\n"
    summary+="  Locale: ${SYSTEM_CONFIG[locale]}\n"
    summary+="  Timezone: ${SYSTEM_CONFIG[timezone]}\n\n"
    summary+="Network:\n"
    summary+="  Hostname: ${CONFIG[hostname]:-not set}\n"
    summary+="  Domain: ${CONFIG[domainname]:-not set}\n\n"
    summary+="Bootloader: ${CONFIG[bootloader_type]:-not set}\n\n"
    summary+="Security:\n"
    summary+="  Firewall: ${CONFIG[enable_firewall]:-not configured}\n"
    summary+="  Fail2ban: ${CONFIG[enable_fail2ban]:-not configured}\n"
    summary+="  Auto updates: ${CONFIG[enable_auto_updates]:-not configured}\n"
    
    dialog --title "Configuration Preview" \
        --msgbox "$summary" 25 80
}

# Main execution
show_config_menu
