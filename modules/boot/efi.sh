#!/usr/bin/env bash
install_efi_bootloader() {
    local mp="${CONFIG[MOUNT_POINT]}"
    show_info "Installing GRUB for EFI system"
    if show_yesno "Install GRUB bootloader to ${CONFIG[INSTALL_DISK]}?"; then
        chroot "$mp" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Gentoo --removable
        chroot "$mp" grub-mkconfig -o /boot/grub/grub.cfg
        log_success "EFI bootloader installed"
    else
        log_error "Bootloader installation cancelled"
        return 1
    fi
}
