#!/usr/bin/env bash
format_ext4_root() {
    mkfs.ext4 -F -L ROOT "$1"
}

mount_ext4_root() {
    mount -o defaults,noatime "${CONFIG[ROOT_PART]}" "${CONFIG[MOUNT_POINT]}"
}
