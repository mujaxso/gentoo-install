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
    cat > "${mp}/root/setup.sh" << CHROOTEOF
#!/bin/bash
set -e
source /etc/profile

echo "=== Gentoo Chroot Configuration ==="

echo "Syncing portage tree..."
emerge-webrsync --quiet
emerge --sync --quiet

echo "Selecting profile..."
eselect profile list
read -p "Enter profile number: " p && eselect profile set "\$p"

echo "Configuring timezone..."
echo "${CONFIG[TIMEZONE]}" > /etc/timezone
emerge --config sys-libs/timezone-data

echo "Configuring locales..."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

echo "Installing system packages..."
echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" >> /etc/portage/package.license
emerge -q sys-kernel/linux-firmware sys-kernel/gentoo-kernel-bin
emerge -q sys-boot/grub net-misc/networkmanager app-admin/doas

echo "Setting hostname..."
echo "hostname=\"${CONFIG[HOSTNAME]}\"" > /etc/conf.d/hostname

echo "Setting root password..."
passwd

echo "Creating user ${CONFIG[USERNAME]}..."
useradd -m -G wheel,audio,video "${CONFIG[USERNAME]}" 
echo "Set password for ${CONFIG[USERNAME]}:"
passwd "${CONFIG[USERNAME]}"

echo "Configuring doas..."
echo "permit persist :wheel" > /etc/doas.conf && chmod 0400 /etc/doas.conf

# Configure init system
if [[ "${CONFIG[INIT_SYSTEM]}" == "systemd" ]]; then
    echo "Enabling systemd services..."
    systemctl enable NetworkManager
else
    echo "Configuring OpenRC services..."
    rc-update add NetworkManager default
fi

echo "=== Chroot configuration complete! ==="
read -p "Press Enter to continue..."
CHROOTEOF
    chmod +x "${mp}/root/setup.sh"
}

enter_chroot() {
    chroot "${CONFIG[MOUNT_POINT]}" /bin/bash -c "/root/setup.sh"
}
