#!/bin/bash

# Portage Configuration Module - Updated for AMD64 Handbook

PORTAGE_CONFIG_FILE="/tmp/gentoo-portage-config"

declare -gA PORTAGE_CONFIG
PORTAGE_CONFIG[sync_method]="rsync"
PORTAGE_CONFIG[use_webrsync]="true"
PORTAGE_CONFIG[profile_set]="false"
PORTAGE_CONFIG[locale_gen]="false"

log_portage() {
    echo -e "${GREEN}[PORTAGE]${NC} $1"
}

show_portage_menu() {
    local choice
    choice=$(dialog --title "Portage Configuration (AMD64 Handbook)" \
        --menu "Select option:" 18 70 9 \
        1 "Install Gentoo Repository Snapshot" \
        2 "Select Profile (Current: ${CONFIG[profile]})" \
        3 "Configure Mirrors" \
        4 "Sync Portage Tree" \
        5 "Configure USE Flags" \
        6 "Set ACCEPT_LICENSE" \
        7 "Configure Locale" \
        8 "Optional: Add Binary Package Host" \
        9 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) install_ebuild_snapshot ;;
        2) select_profile ;;
        3) configure_mirrors ;;
        4) sync_portage_tree ;;
        5) configure_use_flags ;;
        6) configure_license ;;
        7) configure_locale ;;
        8) configure_binary_host ;;
        9) return ;;
    esac
    
    show_portage_menu
}

install_ebuild_snapshot() {
    if [[ ! -d "/mnt/gentoo/var/db/repos/gentoo" ]]; then
        dialog --msgbox "Stage file not extracted yet!\nPlease extract stage file first." 8 40
        return
    fi
    
    log_portage "Installing Gentoo ebuild repository snapshot..."
    
    # Use emerge-webrsync for users behind firewalls
    if [[ "${PORTAGE_CONFIG[use_webrsync]}" == "true" ]]; then
        (
            echo "30"; sleep 1
            echo "Fetching latest snapshot via HTTP..."; sleep 2
            echo "70"
            chroot /mnt/gentoo /bin/bash -c "emerge-webrsync"
            echo "100"; sleep 1
            echo "Snapshot installed!"
        ) | dialog --title "Installing Ebuild Repository" --gauge "Preparing..." 15 60 0
    else
        # Alternative: clone via git
        (
            echo "30"; sleep 1
            echo "Cloning Gentoo repository..."; sleep 2
            echo "70"
            cd /mnt/gentoo/var/db/repos
            rm -rf gentoo
            git clone https://github.com/gentoo/gentoo.git gentoo
            echo "100"; sleep 1
            echo "Repository cloned!"
        ) | dialog --title "Installing Ebuild Repository" --gauge "Preparing..." 15 60 0
    fi
    
    success "Gentoo ebuild repository installed"
    dialog --msgbox "Gentoo ebuild repository installed successfully!\n\nSnapshot method: ${PORTAGE_CONFIG[use_webrsync]}" 10 50
}

select_profile() {
    local choice=$(dialog --title "Profile Selection" \
        --menu "Choose system profile:" 18 60 10 \
        1 "default/linux/amd64/23.0 (base)" \
        2 "default/linux/amd64/23.0/desktop (desktop optimized)" \
        3 "default/linux/amd64/23.0/desktop/gnome" \
        4 "default/linux/amd64/23.0/desktop/gnome/systemd" \
        5 "default/linux/amd64/23.0/desktop/kde" \
        6 "default/linux/amd64/23.0/desktop/kde/systemd" \
        7 "default/linux/amd64/23.0/no-multilib (pure 64-bit)" \
        8 "default/linux/amd64/23.0/hardened" \
        9 "default/linux/amd64/23.0/hardened/systemd" \
        10 "Custom profile" \
        3>&1 1>&2 2>&3)

    local profile=""
    case $choice in
        1) profile="default/linux/amd64/23.0" ;;
        2) profile="default/linux/amd64/23.0/desktop" ;;
        3) profile="default/linux/amd64/23.0/desktop/gnome" ;;
        4) profile="default/linux/amd64/23.0/desktop/gnome/systemd" ;;
        5) profile="default/linux/amd64/23.0/desktop/kde" ;;
        6) profile="default/linux/amd64/23.0/desktop/kde/systemd" ;;
        7) profile="default/linux/amd64/23.0/no-multilib" ;;
        8) profile="default/linux/amd64/23.0/hardened" ;;
        9) profile="default/linux/amd64/23.0/hardened/systemd" ;;
        10)
            profile=$(dialog --title "Custom Profile" \
                --inputbox "Enter custom profile path:" 8 60 "${CONFIG[profile]}" \
                3>&1 1>&2 2>&3)
            ;;
    esac
    
    if [[ -n "$profile" ]]; then
        log_portage "Setting profile: $profile"
        chroot /mnt/gentoo /bin/bash -c "eselect profile set '$profile'"
        CONFIG[profile]="$profile"
        PORTAGE_CONFIG[profile_set]="true"
        success "Profile set to: $profile"
    fi
}

configure_mirrors() {
    log_portage "Configuring Gentoo mirrors..."
    
    # Install mirrorselect if not present
    chroot /mnt/gentoo /bin/bash -c "emerge --ask --quiet app-portage/mirrorselect"
    
    dialog --title "Mirror Selection" \
        --msgbox "Mirrorselect will now help you choose fast mirrors.\n\nUse spacebar to select/deselect mirrors.\nArrow keys to navigate.\nPress Enter when done." 12 50
    
    chroot /mnt/gentoo /bin/bash -c "mirrorselect -i -o >> /etc/portage/make.conf"
    
    success "Mirrors configured"
    dialog --msgbox "Mirrors configured successfully!\n\nCheck /etc/portage/make.conf for mirror list." 10 50
}

sync_portage_tree() {
    if [[ "${PORTAGE_CONFIG[sync_method]}" == "rsync" ]]; then
        log_portage "Syncing Portage tree via rsync..."
        
        (
            echo "20"; sleep 1
            echo "Connecting to rsync server..."; sleep 2
            echo "60"
            chroot /mnt/gentoo /bin/bash -c "emerge --sync --quiet"
            echo "100"; sleep 1
            echo "Portage sync completed!"
        ) | dialog --title "Syncing Portage Tree" --gauge "Preparing..." 15 60 0
    else
        # Git sync
        log_portage "Syncing Portage tree via git..."
        cd /mnt/gentoo/var/db/repos/gentoo
        chroot /mnt/gentoo /bin/bash -c "cd /var/db/repos/gentoo && git pull"
    fi
    
    success "Portage tree synchronized"
    dialog --msgbox "Portage tree synchronized successfully!" 8 40
}

configure_use_flags() {
    dialog --title "USE Flags Configuration" \
        --yesno "Configure USE flags based on system profile?\n\nThis will optimize package compilation for your system." 10 50
    
    if [[ $? -eq 0 ]]; then
        # Common USE flags for different profiles
        local use_flags=""
        
        case "${CONFIG[profile]}" in
            *desktop*)
                use_flags="X pulseaudio dbus gtk qt5 kde gdm"
                ;;
            *gnome*)
                use_flags="X pulseaudio dbus gtk3 gnome-shell gnome"
                ;;
            *kde*)
                use_flags="X pulseaudio dbus qt5 kde plasma kde5"
                ;;
            *hardened*)
                use_flags="hardened pie selinux -pcre2"
                ;;
            *no-multilib*)
                use_flags="-multilib -abi_x86_32"
                ;;
            *)
                use_flags="X pulseaudio dbus"
                ;;
        esac
        
        echo "USE=\"$use_flags\"" >> /mnt/gentoo/etc/portage/make.conf
        success "USE flags configured: $use_flags"
    fi
}

configure_license() {
    dialog --title "ACCEPT_LICENSE Configuration" \
        --menu "Choose license policy:" 12 50 4 \
        1 "@FREE (only free software - recommended)" \
        2 "@FREE @BINARY-REDISTRIBUTABLE (free + binary)" \
        3 "ACCEPT_LICENSE=\"-* @FREE @BINARY-REDISTRIBUTABLE\" (explicit)" \
        4 "Custom license policy" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            echo 'ACCEPT_LICENSE="@FREE"' >> /mnt/gentoo/etc/portage/make.conf
            ;;
        2)
            echo 'ACCEPT_LICENSE="@FREE @BINARY-REDISTRIBUTABLE"' >> /mnt/gentoo/etc/portage/make.conf
            ;;
        3)
            echo 'ACCEPT_LICENSE="-* @FREE @BINARY-REDISTRIBUTABLE"' >> /mnt/gentoo/etc/portage/make.conf
            ;;
        4)
            local custom_license=$(dialog --title "Custom License Policy" \
                --inputbox "Enter ACCEPT_LICENSE value:" 8 50 "@FREE" \
                3>&1 1>&2 2>&3)
            echo "ACCEPT_LICENSE=\"$custom_license\"" >> /mnt/gentoo/etc/portage/make.conf
            ;;
    esac
    
    success "License policy configured"
}

configure_locale() {
    # Generate locales
    cat > /mnt/gentoo/etc/locale.gen << EOF
# Generated locale settings
en_US.UTF-8 UTF-8
EOF

    # Add system locale if not en_US
    if [[ "${CONFIG[locale]}" != "en_US.UTF-8" ]]; then
        echo "${CONFIG[locale]} UTF-8" >> /mnt/gentoo/etc/locale.gen
    fi
    
    log_portage "Generating locales..."
    chroot /mnt/gentoo /bin/bash -c "locale-gen"
    
    # Set system locale
    chroot /mnt/gentoo /bin/bash -c "eselect locale set '${CONFIG[locale]}'"
    
    success "Locale configured: ${CONFIG[locale]}"
    PORTAGE_CONFIG[locale_gen]="true"
}

configure_binary_host() {
    if [[ "${CONFIG[use_binary_host]}" == "true" ]]; then
        # Configure binary package host
        mkdir -p /mnt/gentoo/etc/portage/binrepos.conf
        
        cat > /mnt/gentoo/etc/portage/binrepos.conf/gentoobinhost.conf << EOF
[binhost]
priority = 9999
sync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/x86-64/
EOF
        
        # Set up GPG keyring for binary packages
        chroot /mnt/gentoo /bin/bash -c "getuto"
        
        success "Binary package host configured"
        dialog --msgbox "Binary package host configured!\n\nPortage will now use binary packages when available." 10 50
    fi
}

# Initialize portage config
load_portage_config() {
    if [[ -f "$PORTAGE_CONFIG_FILE" ]]; then
        source "$PORTAGE_CONFIG_FILE"
    fi
}

save_portage_config() {
    > "$PORTAGE_CONFIG_FILE"
    for key in "${!PORTAGE_CONFIG[@]}"; do
        echo "PORTAGE_CONFIG[$key]=\"${PORTAGE_CONFIG[$key]}\"" >> "$PORTAGE_CONFIG_FILE"
    done
}

# Main execution
load_portage_config
show_portage_menu
