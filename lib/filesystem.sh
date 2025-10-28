#!/usr/bin/env bash
format_partitions() {
    [ "${CONFIG[BOOT_MODE]}" = "efi" ] && mkfs.vfat -F32 -n EFI "${CONFIG[EFI_PART]}"
    mkfs.ext4 -F -L BOOT "${CONFIG[BOOT_PART]}"
    mkswap -L SWAP "${CONFIG[SWAP_PART]}"
    swapon "${CONFIG[SWAP_PART]}"
    case "${CONFIG[FILESYSTEM]}" in
        ext4) source "${MODULE_DIR}/fs/ext4.sh"; format_ext4_root "${CONFIG[ROOT_PART]}";;
        btrfs) source "${MODULE_DIR}/fs/btrfs.sh"; format_btrfs_root "${CONFIG[ROOT_PART]}";;
        zfs) source "${MODULE_DIR}/fs/zfs.sh"; format_zfs_root "${CONFIG[ROOT_PART]}";;
    esac
    log_success "Formatted"
}

mount_filesystems() {
    local mp="${CONFIG[MOUNT_POINT]}"
    mkdir -p "$mp"
    case "${CONFIG[FILESYSTEM]}" in
        ext4) source "${MODULE_DIR}/fs/ext4.sh"; mount_ext4_root;;
        btrfs) source "${MODULE_DIR}/fs/btrfs.sh"; mount_btrfs_root;;
        zfs) source "${MODULE_DIR}/fs/zfs.sh"; mount_zfs_root;;
    esac
    mkdir -p "${mp}/boot"
    mount "${CONFIG[BOOT_PART]}" "${mp}/boot"
    if [ "${CONFIG[BOOT_MODE]}" = "efi" ]; then
        mkdir -p "${mp}/boot/efi"
        mount "${CONFIG[EFI_PART]}" "${mp}/boot/efi"
    fi
    log_success "Mounted"
}

umount_all() {
    umount -R "${CONFIG[MOUNT_POINT]}" 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    [ "${CONFIG[FILESYSTEM]}" = "zfs" ] && zpool export rpool 2>/dev/null || true
}

generate_fstab() {
    local mp="${CONFIG[MOUNT_POINT]}"
    cat > "${mp}/etc/fstab" << EOF
# /etc/fstab
EOF
    [ "${CONFIG[BOOT_MODE]}" = "efi" ] && echo "UUID=$(get_uuid "${CONFIG[EFI_PART]}")  /boot/efi  vfat  defaults  0 2" >> "${mp}/etc/fstab"
    echo "UUID=$(get_uuid "${CONFIG[BOOT_PART]}")  /boot  ext4  defaults  0 2" >> "${mp}/etc/fstab"
    echo "UUID=$(get_uuid "${CONFIG[SWAP_PART]}")  none   swap  sw        0 0" >> "${mp}/etc/fstab"
    case "${CONFIG[FILESYSTEM]}" in
        ext4) echo "UUID=$(get_uuid "${CONFIG[ROOT_PART]}")  /  ext4  defaults  0 1" >> "${mp}/etc/fstab";;
        btrfs)
            local uuid=$(get_uuid "${CONFIG[ROOT_PART]}")
            echo "UUID=$uuid  /      btrfs  defaults,compress=zstd,subvol=@      0 0" >> "${mp}/etc/fstab"
            echo "UUID=$uuid  /home  btrfs  defaults,compress=zstd,subvol=@home  0 0" >> "${mp}/etc/fstab"
            ;;
    esac
    log_success "fstab generated"
}
