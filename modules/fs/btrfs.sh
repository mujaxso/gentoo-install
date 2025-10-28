#!/usr/bin/env bash
format_btrfs_root() {
    mkfs.btrfs -f -L ROOT "$1"
}

mount_btrfs_root() {
    local dev="${CONFIG[ROOT_PART]}"
    local mp="${CONFIG[MOUNT_POINT]}"
    mount "$dev" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    umount /mnt
    mount -o defaults,noatime,compress=zstd:1,subvol=@ "$dev" "$mp"
    mkdir -p "${mp}/home"
    mount -o defaults,noatime,compress=zstd:1,subvol=@home "$dev" "${mp}/home"
}
