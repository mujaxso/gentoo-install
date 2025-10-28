#!/usr/bin/env bash
setup_luks_encryption() {
    log_info "Setting up LUKS encryption"
    
    # Get password with confirmation
    while true; do
        local password=$(show_password "Enter encryption password:")
        local password2=$(show_password "Confirm password:")
        if [ "$password" == "$password2" ]; then
            break
        else
            show_error "Passwords don't match! Please try again."
        fi
    done
    
    # Format the partition with LUKS
    if ! echo -n "$password" | cryptsetup luksFormat --type luks2 "${CONFIG[ROOT_PART]}" -; then
        show_error "Failed to format partition with LUKS"
        return 1
    fi
    
    # Open the encrypted partition
    if ! echo -n "$password" | cryptsetup open "${CONFIG[ROOT_PART]}" cryptroot -; then
        show_error "Failed to open encrypted partition"
        return 1
    fi
    
    CONFIG[ROOT_PART]="/dev/mapper/cryptroot"
    log_success "LUKS encryption configured successfully"
}
