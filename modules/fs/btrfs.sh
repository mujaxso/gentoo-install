#!/usr/bin/env bash
format_btrfs_root() {
    mkfs.btrfs -f -L ROOT "$1"
}

mount_btrfs_root() {
    local dev="${CONFIG[ROOT_PART]}"
    local mp="${CONFIG[MOUNT_POINT]}"
    
    # Mount the root filesystem first
    mount -o defaults,noatime,compress=zstd:1,subvol=@ "$dev" "$mp" || {
        # If subvolume doesn't exist, create it
        mount "$dev" /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@snapshots
        umount /mnt
        mount -o defaults,noatime,compress=zstd:1,subvol=@ "$dev" "$mp"
    }
    
    # Create and mount home subvolume
    mkdir -p "${mp}/home"
    mount -o defaults,noatime,compress=zstd:1,subvol=@home "$dev" "${mp}/home" || {
        log_info "Home subvolume not found, creating it"
        mount "$dev" /mnt
        btrfs subvolume create /mnt/@home
        umount /mnt
        mount -o defaults,noatime,compress=zstd:1,subvol=@home "$dev" "${mp}/home"
    }
}
