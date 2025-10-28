#!/usr/bin/env bash
install_bios_bootloader() {
    local mp="${CONFIG[MOUNT_POINT]}"
    show_info "Installing GRUB for BIOS system"
    if show_yesno "Install GRUB bootloader to ${CONFIG[INSTALL_DISK]}?"; then
        chroot "$mp" grub-install --target=i386-pc "${CONFIG[INSTALL_DISK]}"
        chroot "$mp" grub-mkconfig -o /boot/grub/grub.cfg
        log_success "BIOS bootloader installed"
    else
        log_error "Bootloader installation cancelled"
        return 1
    fi
}
