#!/usr/bin/env bash
prepare_chroot() {
    local mp="${CONFIG[MOUNT_POINT]}"
    cp --dereference /etc/resolv.conf "${mp}/etc/" || true
    mount --types proc /proc "${mp}/proc"
    mount --rbind /sys "${mp}/sys"
    mount --make-rslave "${mp}/sys"
    mount --rbind /dev "${mp}/dev"
    mount --make-rslave "${mp}/dev"
    mount --rbind /run "${mp}/run"
    mount --make-rslave "${mp}/run"
    log_success "Chroot ready"
}

generate_chroot_script() {
    local mp="${CONFIG[MOUNT_POINT]}"
    cat > "${mp}/root/setup.sh" << 'CHROOTEOF'
#!/bin/bash
set -e
source /etc/profile
emerge-webrsync --quiet
emerge --sync --quiet
eselect profile list
read -p "Profile number: " p && eselect profile set "$p"
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" >> /etc/portage/package.license
emerge sys-kernel/linux-firmware sys-kernel/gentoo-kernel-bin
emerge sys-boot/grub net-misc/networkmanager app-admin/doas
read -p "Hostname: " h && echo "hostname=\"$h\"" > /etc/conf.d/hostname
passwd
read -p "Username: " u && useradd -m -G wheel,audio,video "$u" && passwd "$u"
echo "permit persist :wheel" > /etc/doas.conf && chmod 0400 /etc/doas.conf
echo "Configuration complete!"
CHROOTEOF
    chmod +x "${mp}/root/setup.sh"
}

enter_chroot() {
    chroot "${CONFIG[MOUNT_POINT]}" /bin/bash -c "/root/setup.sh"
}
