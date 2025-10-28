#!/usr/bin/env bash
configure_systemd() {
    chroot "${CONFIG[MOUNT_POINT]}" systemctl enable NetworkManager
}
