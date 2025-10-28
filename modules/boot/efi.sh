#!/usr/bin/env bash
install_efi_bootloader() {
    local mp="${CONFIG[MOUNT_POINT]}"
    log_info "Installing GRUB for EFI"
    chroot "$mp" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Gentoo --removable
    chroot "$mp" grub-mkconfig -o /boot/grub/grub.cfg
    log_success "EFI bootloader installed"
}
