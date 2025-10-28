#!/usr/bin/env bash
# TUI interface functions

DIALOG="dialog"
command -v dialog &>/dev/null || DIALOG="whiptail"

show_menu() {
    local title="$1"; shift
    $DIALOG --clear --title "$title" --menu "Choose:" 20 70 10 "$@" 2>&1 >/dev/tty
}

show_input() {
    $DIALOG --clear --inputbox "$1" 10 60 "${2:-}" 2>&1 >/dev/tty
}

show_password() {
    $DIALOG --clear --passwordbox "$1" 10 60 2>&1 >/dev/tty
}

show_yesno() {
    $DIALOG --clear --yesno "$1" 12 60
}

show_msgbox() {
    $DIALOG --clear --title "$1" --msgbox "$2" 15 70
}

show_info() { show_msgbox "Information" "$1"; }
show_error() { show_msgbox "Error" "$1"; }
show_success() { show_msgbox "Success" "$1"; }
