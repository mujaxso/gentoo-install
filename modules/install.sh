#!/bin/bash

# Gentoo Installation Module

INSTALL_CONFIG_FILE="/tmp/gentoo-install-config"
STAGE_CONFIG_FILE="/tmp/gentoo-stage-config"

declare -gA STAGE_CONFIG
STAGE_CONFIG[mirror]="https://distfiles.gentoo.org"
STAGE_CONFIG[stage_type]="stage3-amd64"
STAGE_CONFIG[portage_sync]="rsync"

log_install() {
    echo -e "${GREEN}[INSTALL]${NC} $1" | tee -a "/tmp/gentoo-install.log"
}

warn_install() {
    echo -e "${YELLOW}[INSTALL-WARN]${NC} $1" | tee -a "/tmp/gentoo-install.log"
}

error_install() {
    echo -e "${RED}[INSTALL-ERROR]${NC} $1" | tee -a "/tmp/gentoo-install.log"
}

success_install() {
    echo -e "${GREEN}[INSTALL-SUCCESS]${NC} $1" | tee -a "/tmp/gentoo-install.log"
}

show_install_menu() {
    local choice
    choice=$(dialog --title "Gentoo Installation" \
        --menu "Select option:" 15 60 8 \
        1 "Stage Tarball Configuration" \
        2 "Portage Configuration" \
        3 "Kernel Configuration" \
        4 "Network Configuration" \
        5 "Begin Installation" \
        6 "Installation Progress" \
        7 "Installation Logs" \
        8 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) stage_configuration ;;
        2) portage_configuration ;;
        3) kernel_configuration ;;
        4) network_configuration ;;
        5) begin_installation ;;
        6) show_installation_progress ;;
        7) show_installation_logs ;;
        8) return ;;
    esac
    
    show_install_menu
}

stage_configuration() {
    local choice=$(dialog --title "Stage Tarball" \
        --menu "Choose stage tarball type:" 15 50 5 \
        1 "stage3-amd64 (recommended)" \
        2 "stage3-amd64-hardened" \
        3 "stage3-amd64-nomultilib" \
        4 "stage3-amd64-musl" \
        5 "Custom URL" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) 
            CONFIG[stage_tarball]="stage3-amd64"
            STAGE_CONFIG[stage_type]="stage3-amd64"
            ;;
        2) 
            CONFIG[stage_tarball]="stage3-amd64-hardened"
            STAGE_CONFIG[stage_type]="stage3-amd64-hardened"
            ;;
        3) 
            CONFIG[stage_tarball]="stage3-amd64-nomultilib"
            STAGE_CONFIG[stage_type]="stage3-amd64-nomultilib"
            ;;
        4) 
            CONFIG[stage_tarball]="stage3-amd64-musl"
            STAGE_CONFIG[stage_type]="stage3-amd64-musl"
            ;;
        5)
            CONFIG[stage_url]=$(dialog --title "Custom Stage URL" \
                --inputbox "Enter custom stage tarball URL:" 8 60 "" \
                3>&1 1>&2 2>&3)
            ;;
    esac
    
    # Mirror selection
    local mirror_choice=$(dialog --title "Mirror Selection" \
        --menu "Choose Gentoo mirror:" 15 60 4 \
        1 "https://distfiles.gentoo.org (official)" \
        2 "https://mirror.sjtu.edu.cn/gentoo" \
        3 "https://mirror.karneval.org/gentoo" \
        4 "Custom mirror" \
        3>&1 1>&2 2>&3)

    case $mirror_choice in
        1) STAGE_CONFIG[mirror]="https://distfiles.gentoo.org" ;;
        2) STAGE_CONFIG[mirror]="https://mirror.sjtu.edu.cn/gentoo" ;;
        3) STAGE_CONFIG[mirror]="https://mirror.karneval.org/gentoo" ;;
        4) STAGE_CONFIG[mirror]=$(dialog --title "Custom Mirror" \
            --inputbox "Enter custom mirror URL:" 8 60 "https://distfiles.gentoo.org" \
            3>&1 1>&2 2>&3)
            ;;
    esac
}

portage_configuration() {
    local choice=$(dialog --title "Portage Configuration" \
        --menu "Portage settings:" 15 60 4 \
        1 "Sync method: rsync (recommended)" \
        2 "Sync method: git" \
        3 "Custom sync URL" \
        4 "Gentoo ebuild repository" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            STAGE_CONFIG[portage_sync]="rsync"
            CONFIG[sync_method]="rsync"
            ;;
        2)
            STAGE_CONFIG[portage_sync]="git"
            CONFIG[sync_method]="git"
            ;;
        3)
            CONFIG[custom_sync_url]=$(dialog --title "Custom Sync URL" \
                --inputbox "Enter custom sync URL:" 8 60 "" \
                3>&1 1>&2 2>&3)
            ;;
        4)
            CONFIG[use_gentoo_repo]="true"
            ;;
    esac
}

kernel_configuration() {
    local choice=$(dialog --title "Kernel Configuration" \
        --menu "Choose kernel type:" 15 50 5 \
        1 "genkernel (recommended for beginners)" \
        2 "genkernel-next (modern genkernel)" \
        3 "Custom kernel compilation" \
        4 "Distribution kernel" \
        5 "Kernel sources only" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) CONFIG[kernel_type]="genkernel" ;;
        2) CONFIG[kernel_type]="genkernel-next" ;;
        3) CONFIG[kernel_type]="custom" ;;
        4) CONFIG[kernel_type]="distribution" ;;
        5) CONFIG[kernel_type]="sources" ;;
    esac
    
    # Kernel configuration options
    if [[ "${CONFIG[kernel_type]}" == "genkernel" ]] || [[ "${CONFIG[kernel_type]}" == "genkernel-next" ]]; then
        CONFIG[genkernel_config]=$(dialog --title "Genkernel Options" \
            --checklist "Select genkernel options:" 15 60 5 \
            1 "menuconfig" off \
            2 "lvm" off \
            3 "dmraid" off \
            4 "busybox" off \
            5 "ssh" off \
            3>&1 1>&2 2>&3)
    fi
}

network_configuration() {
    CONFIG[use_network]="true"
    CONFIG[network_type]=$(dialog --title "Network Configuration" \
        --menu "Choose network setup:" 10 50 4 \
        1 "DHCP (automatic)" \
        2 "Static IP" \
        3 "NetworkManager" \
        4 "systemd-networkd" \
        3>&1 1>&2 2>&3)
    
    case "${CONFIG[network_type]}" in
        1) CONFIG[ip_method]="dhcp" ;;
        2) CONFIG[ip_method]="static" ;;
        3) CONFIG[ip_method]="networkmanager" ;;
        4) CONFIG[ip_method]="systemd-networkd" ;;
    esac
    
    # Static IP configuration
    if [[ "${CONFIG[ip_method]}" == "static" ]]; then
        CONFIG[static_ip]=$(dialog --title "Static IP Configuration" \
            --inputbox "Enter IP address (e.g., 192.168.1.100):" 8 40 "" \
            3>&1 1>&2 2>&3)
        CONFIG[static_netmask]=$(dialog --title "Netmask" \
            --inputbox "Enter netmask (e.g., 255.255.255.0):" 8 40 "255.255.255.0" \
            3>&1 1>&2 2>&3)
        CONFIG[static_gateway]=$(dialog --title "Gateway" \
            --inputbox "Enter gateway (e.g., 192.168.1.1):" 8 40 "" \
            3>&1 1>&2 2>&3)
        CONFIG[static_dns]=$(dialog --title "DNS Server" \
            --inputbox "Enter DNS server (e.g., 8.8.8.8):" 8 40 "8.8.8.8" \
            3>&1 1>&2 2>&3)
    fi
}

begin_installation() {
    # Verify disk configuration
    if [[ -z "${DISK_CONFIG[boot_device]}" ]] || [[ -z "${DISK_CONFIG[root_device]}" ]]; then
        dialog --title "Error" \
            --msgbox "Please configure disk layout first!\n\nGo to Disk Configuration and set up your partitions." 10 50
        return
    fi
    
    dialog --title "Begin Installation" \
        --yesno "This will begin the complete Gentoo installation process.\n\nThis includes:\n- Disk partitioning and formatting\n- Stage 3 tarball download and extraction\n- Portage configuration and sync\n- Kernel compilation\n- Bootloader installation\n- System configuration\n\nEnsure your disk configuration is correct.\n\nContinue with installation?" 15 60
    
    if [[ $? -eq 0 ]]; then
        execute_installation
    fi
}

execute_installation() {
    log_install "Starting complete Gentoo installation..."
    
    # Create progress dialog
    (
        echo "10"; sleep 1
        echo "Preparing installation environment..."; sleep 2
        echo "20"
        setup_installation_environment
        echo "30"; sleep 1
        echo "Downloading and extracting stage tarball..."; sleep 2
        download_and_extract_stage
        echo "50"; sleep 1
        echo "Configuring Portage..."; sleep 2
        configure_portage
        echo "60"; sleep 1
        echo "Compiling kernel..."; sleep 2
        compile_kernel
        echo "70"; sleep 1
        echo "Configuring system..."; sleep 2
        configure_system
        echo "80"; sleep 1
        echo "Installing bootloader..."; sleep 2
        install_bootloader
        echo "90"; sleep 1
        echo "Finalizing installation..."; sleep 2
        finalize_installation
        echo "100"; sleep 1
        echo "Installation completed successfully!"
    ) | dialog --title "Installation Progress" --gauge "Starting..." 20 70 0
    
    success_install "Gentoo installation completed successfully!"
    dialog --title "Success" \
        --msgbox "Gentoo Linux installation completed successfully!\n\nYou can now reboot into your new system.\n\nDon't forget to:\n- Create a regular user account\n- Configure services\n- Update system with 'emerge --sync && emerge -avuDN @world'" 12 60
}

setup_installation_environment() {
    log_install "Setting up installation environment..."
    
    # Create mount points
    mkdir -p /mnt/gentoo
    mkdir -p /mnt/gentoo/boot
    mkdir -p /mnt/gentoo/proc
    mkdir -p /mnt/gentoo/sys
    mkdir -p /mnt/gentoo/dev
    mkdir -p /mnt/gentoo/dev/pts
    
    # Mount filesystems
    if [[ "${CONFIG[encrypt_root]}" == "true" ]]; then
        log_install "Mounting encrypted root partition"
        source /tmp/gentoo-encryption-config 2>/dev/null || true
        if [[ -n "${ENCRYPT_CONFIG[crypt_name]}" ]]; then
            cryptsetup luksOpen "${DISK_CONFIG[root_device]}1" "${ENCRYPT_CONFIG[crypt_name]}" || true
            mount "/dev/mapper/${ENCRYPT_CONFIG[crypt_name]}" /mnt/gentoo
        else
            mount "${DISK_CONFIG[root_device]}1" /mnt/gentoo
        fi
    else
        mount "${DISK_CONFIG[root_device]}1" /mnt/gentoo
    fi
    
    mount "${DISK_CONFIG[boot_device]}1" /mnt/gentoo/boot
    mount -t proc none /mnt/gentoo/proc
    mount --rbind /sys /mnt/gentoo/sys
    mount --rbind /dev /mnt/gentoo/dev
    
    log_install "Installation environment ready"
}

download_and_extract_stage() {
    log_install "Downloading stage tarball..."
    cd /mnt/gentoo
    
    local stage_url=""
    if [[ -n "${CONFIG[stage_url]}" ]]; then
        stage_url="${CONFIG[stage_url]}"
    else
        local arch="amd64"
        local stage_name="${STAGE_CONFIG[stage_type]}"
        stage_url="${STAGE_CONFIG[mirror]}/releases/${arch}/autobuilds/latest-${stage_name}/${stage_name}-*.tar.xz"
    fi
    
    log_install "Downloading from: $stage_url"
    
    # Download stage tarball
    if ! wget --progress=bar:force -nc "$stage_url"; then
        error_install "Failed to download stage tarball"
        return 1
    fi
    
    log_install "Extracting stage tarball..."
    tar xpf stage3-*.tar.xz --xattrs --numeric-owner
    
    # Copy DNS info
    cp -L /etc/resolv.conf /mnt/gentoo/etc/
    
    log_install "Stage tarball extraction completed"
}

configure_portage() {
    log_install "Configuring Portage..."
    
    cd /mnt/gentoo
    
    # Create make.conf
    local make_conf="/mnt/gentoo/etc/portage/make.conf"
    cat > "$make_conf" << EOF
# Gentoo Linux Configuration
# Generated by Gentoo Installer

# Compiler flags
CFLAGS="-march=native -O2 -pipe"
CXXFLAGS="\${CFLAGS}"
MAKEOPTS="-j$(nproc)"

# USE flags
USE="$CONFIG USE flags based on selections"

# Portage settings
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"

# Gentoo mirror
GENTOO_MIRRORS="${STAGE_CONFIG[mirror]}"

# Parallel emerge jobs
EMERGE_DEFAULT_OPTS="--jobs=\$(nproc) --load-average=\$(nproc)"

# Python options
PYTHON_TARGETS="python3_11 python3_12"
PYTHON_SINGLE_TARGET="python3_11"
EOF
    
    # Set up Portage
    mkdir -p /mnt/gentoo/var/db/repos/gentoo
    mkdir -p /mnt/gentoo/var/cache/distfiles
    mkdir -p /mnt/gentoo/var/cache/binpkgs
    
    # Create repos.conf
    mkdir -p /mnt/gentoo/etc/portage/repos.conf
    cat > /mnt/gentoo/etc/portage/repos.conf/gentoo.conf << EOF
[gentoo]
location = /var/db/repos/gentoo
sync-type = ${STAGE_CONFIG[portage_sync]}
sync-uri = rsync://rsync.gentoo.org/gentoo-portage
auto-sync = yes
EOF
    
    # Sync Portage tree
    log_install "Synchronizing Portage tree..."
    chroot /mnt/gentoo /bin/bash -c "emerge --sync"
    
    # Update @world
    log_install "Updating @world..."
    chroot /mnt/gentoo /bin/bash -c "emerge --quiet --update --deep --newuse @world"
    
    log_install "Portage configuration completed"
}

compile_kernel() {
    log_install "Compiling kernel..."
    
    cd /mnt/gentoo
    
    case "${CONFIG[kernel_type]}" in
        genkernel|genkernel-next)
            log_install "Using genkernel for kernel compilation..."
            
            # Install genkernel
            chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/genkernel"
            
            # Generate kernel with genkernel
            local genkernel_args="--allmodconfig --no-mrproper --bootdir=/boot --bootloader=grub2"
            
            if [[ -n "${CONFIG[genkernel_config]}" ]]; then
                genkernel_args="$genkernel_args --menuconfig"
            fi
            
            chroot /mnt/gentoo /bin/bash -c "genkernel $genkernel_args"
            ;;
        distribution)
            log_install "Installing distribution kernel..."
            chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/gentoo-kernel-bin"
            ;;
        custom)
            log_install "Kernel sources installed. Manual configuration required."
            chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/linux-firmware"
            ;;
    esac
    
    log_install "Kernel compilation completed"
}

configure_system() {
    log_install "Configuring system..."
    
    cd /mnt/gentoo
    
    # Set timezone
    ln -sf /usr/share/zoneinfo/"${CONFIG[timezone]}" /etc/localtime
    echo "${CONFIG[timezone]}" > /etc/timezone
    
    # Set locale
    echo "${CONFIG[locale]} UTF-8" >> /etc/locale.gen
    chroot /mnt/gentoo /bin/bash -c "locale-gen"
    
    # Set keymap
    echo 'keymap="us"' > /etc/conf.d/keymaps
    
    # Set hostname
    echo "hostname=\"${CONFIG[hostname]}\"" > /etc/conf.d/hostname
    
    # Configure network
    configure_network_chroot
    
    # Create fstab
    generate_fstab_chroot
    
    # Set root password
    if [[ -n "${CONFIG[root_password]}" ]]; then
        echo "root:${CONFIG[root_password]}" | chroot /mnt/gentoo /bin/bash -c "chpasswd"
    fi
    
    # Create user
    if [[ -n "${CONFIG[username]}" ]] && [[ "${CONFIG[username]}" != "root" ]]; then
        chroot /mnt/gentoo /bin/bash -c "useradd -m -G users,wheel,audio,video,usb ${CONFIG[username]}"
        if [[ -n "${CONFIG[user_password]}" ]]; then
            echo "${CONFIG[username]}:${CONFIG[user_password]}" | chroot /mnt/gentoo /bin/bash -c "chpasswd"
        fi
    fi
    
    log_install "System configuration completed"
}

configure_network_chroot() {
    case "${CONFIG[ip_method]}" in
        dhcp)
            if [[ "${CONFIG[init_system]}" == "openrc" ]]; then
                echo "config_eth0=\"dhcp\"" >> /mnt/gentoo/etc/conf.d/net
                chroot /mnt/gentoo /bin/bash -c "ln -sf /etc/init.d/net.lo /etc/init.d/net.eth0"
                chroot /mnt/gentoo /bin/bash -c "rc-update add net.eth0 default"
            elif [[ "${CONFIG[init_system]}" == "systemd" ]]; then
                chroot /mnt/gentoo /bin/bash -c "systemctl enable systemd-networkd"
            fi
            ;;
        static)
            if [[ "${CONFIG[init_system]}" == "openrc" ]]; then
                cat >> /mnt/gentoo/etc/conf.d/net << EOF
config_eth0="${CONFIG[static_ip]}/${CONFIG[static_netmask]}"
routes_eth0="default via ${CONFIG[static_gateway]}"
EOF
                echo "dns_servers_eth0=\"${CONFIG[static_dns]}\"" >> /mnt/gentoo/etc/conf.d/net
                chroot /mnt/gentoo /bin/bash -c "ln -sf /etc/init.d/net.lo /etc/init.d/net.eth0"
                chroot /mnt/gentoo /bin/bash -c "rc-update add net.eth0 default"
            elif [[ "${CONFIG[init_system]}" == "systemd" ]]; then
                # Create systemd network file
                cat > /mnt/gentoo/etc/systemd/network/eth0.network << EOF
[Match]
Name=eth0

[Network]
Address=${CONFIG[static_ip]}/${CONFIG[static_netmask]}
Gateway=${CONFIG[static_gateway]}
DNS=${CONFIG[static_dns]}
EOF
                chroot /mnt/gentoo /bin/bash -c "systemctl enable systemd-networkd"
            fi
            ;;
    esac
}

generate_fstab_chroot() {
    local fstab_content="# /etc/fstab: static file system information
# Generated by Gentoo Installer

"
    
    # Root filesystem
    if [[ "${CONFIG[encrypt_root]}" == "true" ]]; then
        fstab_content+="/dev/mapper/${ENCRYPT_CONFIG[crypt_name]}    /           ${CONFIG[root_fs]}    defaults,noatime    0 1\n"
    else
        fstab_content+="${DISK_CONFIG[root_device]}1    /           ${CONFIG[root_fs]}    defaults,noatime    0 1\n"
    fi
    
    # Boot filesystem
    fstab_content+="${DISK_CONFIG[boot_device]}1    /boot       ${FS_CONFIG[boot_fs]:-vfat}    defaults,noatime    0 2\n"
    
    # Swap (if configured)
    if [[ -n "${DISK_CONFIG[swap_device]}" ]]; then
        fstab_content+="${DISK_CONFIG[swap_device]}    none        swap    sw              0 0\n"
    fi
    
    # tmpfs for temporary files
    fstab_content+="tmpfs       /tmp        tmpfs   defaults,size=2g    0 0\n"
    
    echo -e "$fstab_content" > /mnt/gentoo/etc/fstab
}

install_bootloader() {
    log_install "Installing bootloader..."
    
    cd /mnt/gentoo
    
    case "${CONFIG[bootloader_type]}" in
        grub2)
            install_grub2
            ;;
        systemd-boot)
            install_systemd_boot
            ;;
        refind)
            install_refind
            ;;
    esac
    
    log_install "Bootloader installation completed"
}

install_grub2() {
    log_install "Installing GRUB2..."
    
    # Install GRUB
    chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-boot/grub"
    
    # Install GRUB to disk
    local grub_device=""
    if [[ "${CONFIG[boot_mode]}" == "efi" ]]; then
        grub_device="${DISK_CONFIG[boot_device]}"
        chroot /mnt/gentoo /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Gentoo"
    else
        grub_device="${DISK_CONFIG[boot_device]}"
        chroot /mnt/gentoo /bin/bash -c "grub-install --target=i386-pc $grub_device"
    fi
    
    # Generate GRUB configuration
    chroot /mnt/gentoo /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
    
    log_install "GRUB2 installed successfully"
}

install_systemd_boot() {
    log_install "Installing systemd-boot..."
    
    # Install systemd-boot
    chroot /mnt/gentoo /bin/bash -c "bootctl install"
    
    # Create boot entry
    cat > /mnt/gentoo/boot/loader/entries/gentoo.conf << EOF
title Gentoo Linux
linux /vmlinuz-*
initrd /initramfs-*
options root=${DISK_CONFIG[root_device]}1 rw
EOF
    
    log_install "systemd-boot installed successfully"
}

install_refind() {
    log_install "Installing rEFInd..."
    
    # Install rEFInd
    chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-boot/refind"
    
    # Install rEFInd
    chroot /mnt/gentoo /bin/bash -c "refind-install"
    
    log_install "rEFInd installed successfully"
}

finalize_installation() {
    log_install "Finalizing installation..."
    
    cd /mnt/gentoo
    
    # Clean up
    chroot /mnt/gentoo /bin/bash -c "emerge --depclean"
    chroot /mnt/gentoo /bin/bash -c "eclean-dist -q"
    
    # Enable services
    configure_services_chroot
    
    # Save installation log
    cp /tmp/gentoo-install.log /mnt/gentoo/root/gentoo-install.log
    
    log_install "Installation finalization completed"
}

configure_services_chroot() {
    # SSH
    if [[ "${CONFIG[enable_ssh]}" == "true" ]]; then
        if [[ "${CONFIG[init_system]}" == "openrc" ]]; then
            chroot /mnt/gentoo /bin/bash -c "rc-update add sshd default"
        elif [[ "${CONFIG[init_system]}" == "systemd" ]]; then
            chroot /mnt/gentoo /bin/bash -c "systemctl enable sshd"
        fi
    fi
    
    # NetworkManager
    if [[ "${CONFIG[enable_networkmanager]}" == "true" ]]; then
        chroot /mnt/gentoo /bin/bash -c "emerge --ask net-misc/networkmanager"
        if [[ "${CONFIG[init_system]}" == "openrc" ]]; then
            chroot /mnt/gentoo /bin/bash -c "rc-update add NetworkManager default"
        elif [[ "${CONFIG[init_system]}" == "systemd" ]]; then
            chroot /mnt/gentoo /bin/bash -c "systemctl enable NetworkManager"
        fi
    fi
}

show_installation_progress() {
    local progress=$(tail -1 /tmp/gentoo-install.log 2>/dev/null || echo "Installation not started")
    
    dialog --title "Installation Progress" \
        --msgbox "Current status:\n$progress\n\nInstallation log available at:\n/tmp/gentoo-install.log" 12 60
}

show_installation_logs() {
    if [[ -f /tmp/gentoo-install.log ]]; then
        dialog --title "Installation Logs" \
            --msgbox "$(cat /tmp/gentoo-install.log)" 25 80
    else
        dialog --title "No Logs" \
            --msgbox "No installation logs found." 8 40
    fi
}

# Main execution
show_install_menu
