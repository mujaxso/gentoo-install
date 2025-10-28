#!/usr/bin/env bash
# TUI interface functions

DIALOG="dialog"
command -v dialog &>/dev/null || DIALOG="whiptail"

show_menu() {
    local title="$1"; shift
    local result
    if result=$($DIALOG --clear --title "$title" --menu "Choose:" 20 70 10 "$@" 2>&1 >/dev/tty); then
        echo "$result"
        return 0
    else
        return 1
    fi
}

show_input() {
    local result
    if result=$($DIALOG --clear --inputbox "$1" 10 60 "${2:-}" 2>&1 >/dev/tty); then
        echo "$result"
        return 0
    else
        return 1
    fi
}

show_password() {
    local result
    if result=$($DIALOG --clear --passwordbox "$1" 10 60 2>&1 >/dev/tty); then
        echo "$result"
        return 0
    else
        return 1
    fi
}

show_yesno() {
    $DIALOG --clear --yesno "$1" 12 60 2>&1 >/dev/tty
}

show_msgbox() {
    $DIALOG --clear --title "$1" --msgbox "$2" 15 70 2>&1 >/dev/tty
}

show_info() { 
    log_info "$1"
    show_msgbox "Information" "$1" 
}

show_error() { 
    log_error "$1"
    show_msgbox "Error" "$1" 
}

show_dependency_status() {
    local title="$1"
    local status="$2"  # "missing" or "available"
    local deps_list="$3"
    
    if [[ "$status" == "available" ]]; then
        show_msgbox "$title" "All dependencies are available:\n\n$deps_list"
    else
        show_msgbox "$title" "Missing dependencies:\n\n$deps_list"
    fi
}

show_success() { 
    log_success "$1"
    show_msgbox "Success" "$1" 
}
