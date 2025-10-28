#!/usr/bin/env bash
format_zfs_root() {
    zpool create -f -o ashift=12 -O compression=lz4 -O atime=off rpool "$1"
    zfs create -o mountpoint=/ rpool/ROOT
    zfs create -o mountpoint=/home rpool/home
}

mount_zfs_root() {
    zpool import -f rpool 2>/dev/null || true
    zfs mount -a
}
