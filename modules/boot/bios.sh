#!/usr/bin/env bash
install_bios_bootloader() {
    local mp="${CONFIG[MOUNT_POINT]}"
    chroot "$mp" grub-install --target=i386-pc "${CONFIG[INSTALL_DISK]}"
    chroot "$mp" grub-mkconfig -o /boot/grub/grub.cfg
    log_success "BIOS bootloader installed"
}
