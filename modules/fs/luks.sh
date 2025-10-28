#!/usr/bin/env bash
setup_luks_encryption() {
    log_info "Setting up LUKS encryption"
    local password=$(show_password "Enter encryption password:")
    local password2=$(show_password "Confirm password:")
    [ "$password" != "$password2" ] && show_error "Passwords don't match!" && return 1
    echo -n "$password" | cryptsetup luksFormat --type luks2 "${CONFIG[ROOT_PART]}" -
    echo -n "$password" | cryptsetup open "${CONFIG[ROOT_PART]}" cryptroot -
    CONFIG[ROOT_PART]="/dev/mapper/cryptroot"
    log_success "LUKS configured"
}
