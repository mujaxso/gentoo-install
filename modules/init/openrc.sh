#!/usr/bin/env bash
configure_openrc() {
    chroot "${CONFIG[MOUNT_POINT]}" rc-update add NetworkManager default
}
