#!/bin/bash

# Filesystem Configuration Module

FILESYSTEM_CONFIG_FILE="/tmp/gentoo-filesystem-config"

declare -gA FS_CONFIG
FS_CONFIG[root_fs]="ext4"
FS_CONFIG[boot_fs]="vfat"
FS_CONFIG[home_fs]="ext4"
FS_CONFIG[var_fs]="ext4"
FS_CONFIG[separate_home]="false"
FS_CONFIG[separate_var]="false"

log_fs() {
    echo -e "${GREEN}[FS]${NC} $1"
}

show_fs_menu() {
    local choice
    choice=$(dialog --title "Filesystem Configuration" \
        --menu "Select option:" 15 60 8 \
        1 "Root Filesystem (Current: ${FS_CONFIG[root_fs]})" \
        2 "Boot Filesystem (Current: ${FS_CONFIG[boot_fs]})" \
        3 "Home Filesystem (Current: ${FS_CONFIG[home_fs]})" \
        4 "Var Filesystem (Current: ${FS_CONFIG[var_fs]})" \
        5 "Enable Separate Home Partition (Current: ${FS_CONFIG[separate_home]})" \
        6 "Enable Separate Var Partition (Current: ${FS_CONFIG[separate_var]})" \
        7 "Mount Options" \
        8 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) select_root_fs ;;
        2) select_boot_fs ;;
        3) select_home_fs ;;
        4) select_var_fs ;;
        5) toggle_separate_home ;;
        6) toggle_separate_var ;;
        7) configure_mount_options ;;
        8) return ;;
    esac
    
    show_fs_menu
}

select_root_fs() {
    local choice=$(dialog --title "Root Filesystem" \
        --menu "Choose root filesystem:" 15 50 4 \
        1 "ext4" \
        2 "btrfs" \
        3 "zfs" \
        4 "xfs" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) FS_CONFIG[root_fs]="ext4" ;;
        2) FS_CONFIG[root_fs]="btrfs" ;;
        3) FS_CONFIG[root_fs]="zfs" ;;
        4) FS_CONFIG[root_fs]="xfs" ;;
    esac
    
    # Update global config
    CONFIG[root_fs]="${FS_CONFIG[root_fs]}"
}

select_boot_fs() {
    local choice=$(dialog --title "Boot Filesystem" \
        --menu "Choose boot filesystem:" 10 50 2 \
        1 "vfat (EFI System Partition)" \
        2 "ext4" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) FS_CONFIG[boot_fs]="vfat" ;;
        2) FS_CONFIG[boot_fs]="ext4" ;;
    esac
}

select_home_fs() {
    local choice=$(dialog --title "Home Filesystem" \
        --menu "Choose home filesystem:" 15 50 4 \
        1 "ext4" \
        2 "btrfs" \
        3 "zfs" \
        4 "xfs" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) FS_CONFIG[home_fs]="ext4" ;;
        2) FS_CONFIG[home_fs]="btrfs" ;;
        3) FS_CONFIG[home_fs]="zfs" ;;
        4) FS_CONFIG[home_fs]="xfs" ;;
    esac
}

select_var_fs() {
    local choice=$(dialog --title "Var Filesystem" \
        --menu "Choose var filesystem:" 15 50 4 \
        1 "ext4" \
        2 "btrfs" \
        3 "zfs" \
        4 "xfs" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) FS_CONFIG[var_fs]="ext4" ;;
        2) FS_CONFIG[var_fs]="btrfs" ;;
        3) FS_CONFIG[var_fs]="zfs" ;;
        4) FS_CONFIG[var_fs]="xfs" ;;
    esac
}

toggle_separate_home() {
    if [[ "${FS_CONFIG[separate_home]}" == "true" ]]; then
        FS_CONFIG[separate_home]="false"
    else
        FS_CONFIG[separate_home]="true"
    fi
}

toggle_separate_var() {
    if [[ "${FS_CONFIG[separate_var]}" == "true" ]]; then
        FS_CONFIG[separate_var]="false"
    else
        FS_CONFIG[separate_var]="true"
    fi
}

configure_mount_options() {
    local options="Configure filesystem mount options:\n\n"
    options+="Common mount options:\n"
    options+="- noatime: Disable access time updates (performance)\n"
    options+="- compress=zstd: Enable compression (btrfs only)\n"
    options+="- relatime: Relative time updates\n"
    options+="- discard: Enable TRIM (SSD support)\n\n"
    options+="Current settings will be applied during installation."
    
    dialog --title "Mount Options" \
        --msgbox "$options" 20 60
}

# Filesystem creation functions
create_filesystem() {
    local device="$1"
    local fs_type="$2"
    
    log_fs "Creating $fs_type filesystem on $device"
    
    case "$fs_type" in
        ext4)
            mkfs.ext4 -F "$device"
            ;;
        btrfs)
            mkfs.btrfs -f "$device"
            ;;
        xfs)
            mkfs.xfs -f "$device"
            ;;
        vfat)
            mkfs.vfat -F32 "$device"
            ;;
        zfs)
            zpool create -f gentoo "$device"
            ;;
    esac
}

# Main execution
show_fs_menu
