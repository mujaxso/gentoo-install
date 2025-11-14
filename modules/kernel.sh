#!/bin/bash

# Kernel Configuration Module - Updated for AMD64 Handbook

KERNEL_CONFIG_FILE="/tmp/gentoo-kernel-config"

declare -gA KERNEL_CONFIG
KERNEL_CONFIG[kernel_type]="distribution"
KERNEL_CONFIG[install_firmware]="true"
KERNEL_CONFIG[install_microcode]="false"

log_kernel() {
    echo -e "${GREEN}[KERNEL]${NC} $1"
}

show_kernel_menu() {
    local choice
    choice=$(dialog --title "Kernel Configuration (AMD64 Handbook)" \
        --menu "Select option:" 18 70 9 \
        1 "Choose Kernel Method (Current: ${KERNEL_CONFIG[kernel_type]})" \
        2 "Install Linux Firmware (Recommended)" \
        3 "Install Microcode Updates" \
        4 "Configure Secure Boot (Optional)" \
        5 "Install Distribution Kernel" \
        6 "Manual Kernel Configuration" \
        7 "Genkernel (Deprecated)" \
        8 "Configure Kernel Modules" \
        9 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) select_kernel_method ;;
        2) install_firmware ;;
        3) install_microcode ;;
        4) configure_secure_boot ;;
        5) install_distribution_kernel ;;
        6) manual_kernel_config ;;
        7) genkernel_method ;;
        8) configure_modules ;;
        9) return ;;
    esac
    
    show_kernel_menu
}

select_kernel_method() {
    local choice=$(dialog --title "Kernel Method (AMD64 Handbook)" \
        --menu "Choose kernel installation method:" 18 60 5 \
        1 "Distribution Kernel (Recommended - Automated)" \
        2 "Manual Configuration (Advanced)" \
        3 "Genkernel (Deprecated - Not Recommended)" \
        4 "EFI Stub (Minimal, Advanced)" \
        5 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) 
            KERNEL_CONFIG[kernel_type]="distribution"
            CONFIG[kernel_type]="distribution"
            ;;
        2) 
            KERNEL_CONFIG[kernel_type]="manual"
            CONFIG[kernel_type]="manual"
            ;;
        3) 
            KERNEL_CONFIG[kernel_type]="genkernel"
            CONFIG[kernel_type]="genkernel"
            warn "Genkernel is deprecated and not recommended"
            ;;
        4) 
            KERNEL_CONFIG[kernel_type]="efistub"
            CONFIG[kernel_type]="efistub"
            ;;
    esac
}

install_firmware() {
    dialog --title "Linux Firmware" \
        --yesno "Install sys-kernel/linux-firmware?\n\nThis provides firmware for many devices including:\n• WiFi adapters\n• GPU firmware\n• Network cards\n• Other hardware requiring firmware\n\nRecommended for most systems." 12 50
    
    if [[ $? -eq 0 ]]; then
        log_kernel "Installing Linux firmware..."
        
        (
            echo "20"; sleep 1
            echo "Emerging linux-firmware package..."; sleep 2
            echo "70"
            chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/linux-firmware"
            echo "100"; sleep 1
            echo "Firmware installation completed!"
        ) | dialog --title "Installing Firmware" --gauge "Preparing..." 15 60 0
        
        success "Linux firmware installed"
        KERNEL_CONFIG[install_firmware]="true"
    fi
}

install_microcode() {
    local choice=$(dialog --title "Microcode Updates" \
        --menu "CPU Microcode Configuration:" 12 50 3 \
        1 "Intel Microcode" \
        2 "AMD Microcode" \
        3 "Skip microcode installation" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            log_kernel "Installing Intel microcode..."
            chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-firmware/intel-microcode"
            success "Intel microcode installed"
            KERNEL_CONFIG[install_microcode]="true"
            ;;
        2)
            log_kernel "AMD microcode is included in linux-firmware"
            success "AMD microcode will be installed with linux-firmware"
            KERNEL_CONFIG[install_microcode]="true"
            ;;
        3)
            log_kernel "Skipping microcode installation"
            ;;
    esac
}

configure_secure_boot() {
    dialog --title "Secure Boot Configuration" \
        --yesno "Configure Secure Boot support?\n\nThis requires:\n• Generating signing keys\n• Configuring kernel signing\n• Setting up bootloader signing\n\nAdvanced feature - only if using Secure Boot." 12 50
    
    if [[ $? -eq 0 ]]; then
        log_kernel "Setting up Secure Boot support..."
        
        # Generate signing key
        local key_path="/mnt/gentoo/var/lib/secureboot"
        mkdir -p "$key_path"
        
        openssl req -new -x509 -sha256 -newkey rsa:4096 -keyout "$key_path/kernel_key.pem" \
            -out "$key_path/kernel_key.pem" -days 3650 -nodes -subj "/CN=Gentoo Secure Boot/"
        
        chmod 600 "$key_path/kernel_key.pem"
        
        # Add to make.conf
        echo 'USE="modules-sign secureboot"' >> /mnt/gentoo/etc/portage/make.conf
        echo "MODULES_SIGN_KEY=\"$key_path/kernel_key.pem\"" >> /mnt/gentoo/etc/portage/make.conf
        echo "SECUREBOOT_SIGN_KEY=\"$key_path/kernel_key.pem\"" >> /mnt/gentoo/etc/portage/make.conf
        echo "SECUREBOOT_SIGN_CERT=\"$key_path/kernel_key.pem\"" >> /mnt/gentoo/etc/portage/make.conf
        
        success "Secure Boot configuration completed"
    fi
}

install_distribution_kernel() {
    local choice=$(dialog --title "Distribution Kernel" \
        --menu "Choose distribution kernel type:" 12 50 3 \
        1 "sys-kernel/gentoo-kernel (compile from source)" \
        2 "sys-kernel/gentoo-kernel-bin (pre-compiled)" \
        3 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            log_kernel "Installing gentoo-kernel (from source)..."
            chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/gentoo-kernel"
            ;;
        2)
            log_kernel "Installing gentoo-kernel-bin (pre-compiled)..."
            chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/gentoo-kernel-bin"
            ;;
    esac
    
    # Install required dependencies
    chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/installkernel"
    
    # Enable dist-kernel USE flag
    echo 'USE="dist-kernel"' >> /mnt/gentoo/etc/portage/make.conf
    
    # Configure for initramfs generation
    if [[ "${CONFIG[init_system]}" == "systemd" ]]; then
        echo 'USE="dracut"' >> /mnt/gentoo/etc/portage/make.conf
        chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/dracut"
    fi
    
    success "Distribution kernel installed"
    dialog --msgbox "Distribution kernel installed successfully!\n\nKernel will be managed through Portage like any other package." 12 50
}

manual_kernel_config() {
    dialog --title "Manual Kernel Configuration" \
        --yesno "This will install kernel sources and configure manually.\n\nProceed?" 10 40
    
    if [[ $? -eq 0 ]]; then
        log_kernel "Installing kernel sources..."
        chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/gentoo-sources"
        
        # Set up kernel symlink
        chroot /mnt/gentoo /bin/bash -c "eselect kernel set 1"
        
        log_kernel "Kernel sources installed"
        dialog --msgbox "Kernel sources installed at /usr/src/linux\n\nUse 'make nconfig' to configure manually." 10 50
    fi
}

genkernel_method() {
    warn "Genkernel is deprecated and not recommended"
    warn "Consider using Distribution Kernel instead"
    
    dialog --title "Genkernel (Deprecated)" \
        --yesno "Genkernel is deprecated.\n\nDo you still want to proceed?" 10 40
    
    if [[ $? -eq 0 ]]; then
        log_kernel "Installing genkernel..."
        chroot /mnt/gentoo /bin/bash -c "emerge --ask sys-kernel/genkernel"
        
        dialog --msgbox "Genkernel installed.\n\nRun 'genkernel all' to compile kernel." 8 40
    fi
}

configure_modules() {
    dialog --title "Kernel Modules" \
        --yesno "Configure automatic kernel module loading?\n\nThis sets up modules to load at boot." 10 50
    
    if [[ $? -eq 0 ]]; then
        # Create modules directories
        mkdir -p /mnt/gentoo/etc/modules-load.d
        mkdir -p /mnt/gentoo/etc/modprobe.d
        
        # Example module configurations
        echo "# Network modules" > /mnt/gentoo/etc/modules-load.d/network.conf
        echo "8139too" >> /mnt/gentoo/etc/modules-load.d/network.conf
        echo "e1000" >> /mnt/gentoo/etc/modules-load.d/network.conf
        
        success "Module configuration created"
        dialog --msgbox "Module configuration completed!\n\nCheck /etc/modules-load.d/ for module lists." 10 50
    fi
}

# Initialize kernel config
load_kernel_config() {
    if [[ -f "$KERNEL_CONFIG_FILE" ]]; then
        source "$KERNEL_CONFIG_FILE"
    fi
}

save_kernel_config() {
    > "$KERNEL_CONFIG_FILE"
    for key in "${!KERNEL_CONFIG[@]}"; do
        echo "KERNEL_CONFIG[$key]=\"${KERNEL_CONFIG[$key]}\"" >> "$KERNEL_CONFIG_FILE"
    done
}

# Main execution
load_kernel_config
show_kernel_menu
