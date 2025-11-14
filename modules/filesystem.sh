#!/bin/bash

# Filesystem Configuration Module - Updated for AMD64 Handbook (XFS recommended)

FILESYSTEM_CONFIG_FILE="/tmp/gentoo-filesystem-config"

declare -gA FS_CONFIG
FS_CONFIG[root_fs]="xfs"  # XFS is recommended in handbook
FS_CONFIG[boot_fs]="vfat"
FS_CONFIG[home_fs]="xfs"
FS_CONFIG[var_fs]="xfs"
FS_CONFIG[separate_home]="false"
FS_CONFIG[separate_var]="false"

log_fs() {
    echo -e "${GREEN}[FS]${NC} $1"
}

show_fs_menu() {
    local choice
    choice=$(dialog --title "Filesystem Configuration (AMD64 Handbook)" \
        --menu "Select option:" 18 70 9 \
        1 "Root Filesystem (Current: ${FS_CONFIG[root_fs]} - recommended: xfs)" \
        2 "Boot Filesystem (Current: ${FS_CONFIG[boot_fs]})" \
        3 "Home Filesystem (Current: ${FS_CONFIG[home_fs]})" \
        4 "Var Filesystem (Current: ${FS_CONFIG[var_fs]})" \
        5 "Enable Separate Home Partition (Current: ${FS_CONFIG[separate_home]})" \
        6 "Enable Separate Var Partition (Current: ${FS_CONFIG[separate_var]})" \
        7 "Mount Options" \
        8 "Filesystem Info (Handbook Recommendations)" \
        9 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) select_root_fs ;;
        2) select_boot_fs ;;
        3) select_home_fs ;;
        4) select_var_fs ;;
        5) toggle_separate_home ;;
        6) toggle_separate_var ;;
        7) configure_mount_options ;;
        8) show_filesystem_info ;;
        9) return ;;
    esac
    
    show_fs_menu
}

select_root_fs() {
    local choice=$(dialog --title "Root Filesystem (AMD64 Handbook)" \
        --menu "Choose root filesystem:" 18 60 6 \
        1 "xfs (recommended - all-purpose, all-platform)" \
        2 "ext4 (reliable, all-purpose)" \
        3 "btrfs (advanced features, snapshots)" \
        4 "zfs (next-generation, built-in RAID)" \
        5 "f2fs (flash-friendly)" \
        6 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) FS_CONFIG[root_fs]="xfs" ;;
        2) FS_CONFIG[root_fs]="ext4" ;;
        3) FS_CONFIG[root_fs]="btrfs" ;;
        4) FS_CONFIG[root_fs]="zfs" ;;
        5) FS_CONFIG[root_fs]="f2fs" ;;
    esac
    
    # Update global config
    CONFIG[root_fs]="${FS_CONFIG[root_fs]}"
    
    if [[ "${FS_CONFIG[root_fs]}" != "xfs" ]]; then
        warn "XFS is recommended for new Gentoo installations per handbook"
    fi
}

select_boot_fs() {
    local choice=$(dialog --title "Boot Filesystem" \
        --menu "Choose boot filesystem:" 12 50 3 \
        1 "vfat (EFI System Partition - UEFI)" \
        2 "xfs (BIOS/Legacy boot)" \
        3 "ext4 (alternative for BIOS/Legacy)" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) FS_CONFIG[boot_fs]="vfat" ;;
        2) FS_CONFIG[boot_fs]="xfs" ;;
        3) FS_CONFIG[boot_fs]="ext4" ;;
    esac
}

select_home_fs() {
    local choice=$(dialog --title "Home Filesystem" \
        --menu "Choose home filesystem:" 15 50 6 \
        1 "xfs (recommended)" \
        2 "ext4" \
        3 "btrfs (with snapshots)" \
        4 "zfs" \
        5 "f2fs (SSD/flash)" \
        6 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) FS_CONFIG[home_fs]="xfs" ;;
        2) FS_CONFIG[home_fs]="ext4" ;;
        3) FS_CONFIG[home_fs]="btrfs" ;;
        4) FS_CONFIG[home_fs]="zfs" ;;
        5) FS_CONFIG[home_fs]="f2fs" ;;
    esac
}

select_var_fs() {
    local choice=$(dialog --title "Var Filesystem" \
        --menu "Choose var filesystem:" 15 50 6 \
        1 "xfs (recommended)" \
        2 "ext4" \
        3 "btrfs (with snapshots)" \
        4 "zfs" \
        5 "f2fs (SSD/flash)" \
        6 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) FS_CONFIG[var_fs]="xfs" ;;
        2) FS_CONFIG[var_fs]="ext4" ;;
        3) FS_CONFIG[var_fs]="btrfs" ;;
        4) FS_CONFIG[var_fs]="zfs" ;;
        5) FS_CONFIG[var_fs]="f2fs" ;;
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
    options+="- discard: Enable TRIM (SSD support) - not recommended\n"
    options+="  (use periodic fstrim instead)\n\n"
    options+="XFS specific options:\n"
    options+="- largeio: Better performance for large files\n"
    options+="- inode64: Store inodes in separate locations\n\n"
    options+="Current settings will be applied during installation."
    
    dialog --title "Mount Options" \
        --msgbox "$options" 22 70
}

show_filesystem_info() {
    local info="Filesystem Information (AMD64 Handbook):\n\n"
    info+="RECOMMENDED: XFS\n"
    info+="• Filesystem with metadata journaling\n"
    info+="• Robust feature-set, optimized for scalability\n"
    info+="• Modern features: reflinks, Copy on Write (CoW)\n"
    info+="• Excellent for Gentoo due to compilation workload\n"
    info+="• Minimum partition size: 300MB\n\n"
    info+="ALTERNATIVES:\n"
    info+="• ext4: Reliable, all-purpose, lacks modern features\n"
    info+="• btrfs: Advanced features, snapshots, compression\n"
    info+="  (RAID 5/6 unsafe on all versions)\n"
    info+="• zfs: Next-generation, built-in RAID\n"
    info+="• f2fs: Flash-friendly for SSD/USB storage\n\n"
    info+="⚠️ WARNING: \n"
    info+="Do not use 'discard' mount option for SSD\n"
    info+="Use periodic fstrim jobs instead\n\n"
    info+="ESP (EFI System Partition):\n"
    info+="• Must be FAT32 (vfat) for UEFI\n"
    info+="• Recommended size: 1GB\n"
    
    dialog --title "Filesystem Information" \
        --msgbox "$info" 25 70
}

# Filesystem creation functions
create_filesystem() {
    local device="$1"
    local fs_type="$2"
    
    log_fs "Creating $fs_type filesystem on $device"
    
    case "$fs_type" in
        xfs)
            mkfs.xfs -f "$device"
            ;;
        ext4)
            mkfs.ext4 -F "$device"
            ;;
        btrfs)
            mkfs.btrfs -f "$device"
            ;;
        f2fs)
            mkfs.f2fs "$device"
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
