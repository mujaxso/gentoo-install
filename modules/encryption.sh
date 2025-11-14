#!/bin/bash

# Encryption (LUKS) Configuration Module

ENCRYPTION_CONFIG_FILE="/tmp/gentoo-encryption-config"

declare -gA ENCRYPT_CONFIG
ENCRYPT_CONFIG[encrypt_root]="false"
ENCRYPT_CONFIG[encrypt_boot]="false"
ENCRYPT_CONFIG[luks_version]="luks2"
ENCRYPT_CONFIG[crypt_name]="gentoo"
ENCRYPT_CONFIG[use_keyfile]="false"

log_crypt() {
    echo -e "${GREEN}[CRYPT]${NC} $1"
}

show_crypt_menu() {
    local choice
    choice=$(dialog --title "Encryption Configuration" \
        --menu "Select option:" 15 60 7 \
        1 "Encrypt Root Partition (Current: ${ENCRYPT_CONFIG[encrypt_root]})" \
        2 "Encrypt Boot Partition (Current: ${ENCRYPT_CONFIG[encrypt_boot]})" \
        3 "LUKS Version (Current: ${ENCRYPT_CONFIG[luks_version]})" \
        4 "Cryptsetup Name (Current: ${ENCRYPT_CONFIG[crypt_name]})" \
        5 "Use Keyfile (Current: ${ENCRYPT_CONFIG[use_keyfile]})" \
        6 "Test Configuration" \
        7 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) toggle_root_encryption ;;
        2) toggle_boot_encryption ;;
        3) select_luks_version ;;
        4) set_crypt_name ;;
        5) toggle_keyfile ;;
        6) test_encryption ;;
        7) return ;;
    esac
    
    show_crypt_menu
}

toggle_root_encryption() {
    if [[ "${ENCRYPT_CONFIG[encrypt_root]}" == "true" ]]; then
        ENCRYPT_CONFIG[encrypt_root]="false"
    else
        ENCRYPT_CONFIG[encrypt_root]="true"
        CONFIG[encrypt_root]="true"
    fi
}

toggle_boot_encryption() {
    if [[ "${ENCRYPT_CONFIG[encrypt_boot]}" == "true" ]]; then
        ENCRYPT_CONFIG[encrypt_boot]="false"
    else
        ENCRYPT_CONFIG[encrypt_boot]="true"
    fi
}

select_luks_version() {
    local choice=$(dialog --title "LUKS Version" \
        --menu "Choose LUKS version:" 10 40 3 \
        1 "luks1 (compatible)" \
        2 "luks2 (recommended)" \
        3 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) ENCRYPT_CONFIG[luks_version]="luks1" ;;
        2) ENCRYPT_CONFIG[luks_version]="luks2" ;;
    esac
}

set_crypt_name() {
    ENCRYPT_CONFIG[crypt_name]=$(dialog --title "Cryptsetup Name" \
        --inputbox "Enter cryptsetup device name:" 8 40 "${ENCRYPT_CONFIG[crypt_name]}" \
        3>&1 1>&2 2>&3)
}

toggle_keyfile() {
    if [[ "${ENCRYPT_CONFIG[use_keyfile]}" == "true" ]]; then
        ENCRYPT_CONFIG[use_keyfile]="false"
    else
        ENCRYPT_CONFIG[use_keyfile]="true"
    fi
}

test_encryption() {
    local summary="Encryption Configuration Test:\n\n"
    summary+="Encrypt Root: ${ENCRYPT_CONFIG[encrypt_root]}\n"
    summary+="Encrypt Boot: ${ENCRYPT_CONFIG[encrypt_boot]}\n"
    summary+="LUKS Version: ${ENCRYPT_CONFIG[luks_version]}\n"
    summary+="Crypt Name: ${ENCRYPT_CONFIG[crypt_name]}\n"
    summary+="Use Keyfile: ${ENCRYPT_CONFIG[use_keyfile]}\n\n"
    
    if [[ "${ENCRYPT_CONFIG[encrypt_root]}" == "true" ]]; then
        summary+="Root partition will be encrypted with LUKS ${ENCRYPT_CONFIG[luks_version]}\n"
        summary+="Device will be mapped as: /dev/mapper/${ENCRYPT_CONFIG[crypt_name]}\n"
    fi
    
    dialog --title "Encryption Test" \
        --msgbox "$summary" 15 50
}

# LUKS setup functions
setup_luks() {
    local device="$1"
    local crypt_name="$2"
    local luks_version="$3"
    
    log_crypt "Setting up LUKS encryption on $device"
    
    # Check if device is already encrypted
    if cryptsetup isLuks "$device" &>/dev/null; then
        warn "Device $device is already encrypted"
        return 0
    fi
    
    # Format with LUKS
    cryptsetup luksFormat --type "$luks_version" "$device"
    
    # Open the encrypted container
    cryptsetup luksOpen "$device" "$crypt_name"
    
    log_crypt "LUKS encryption setup completed"
}

# Main execution
show_crypt_menu
