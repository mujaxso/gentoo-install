#!/bin/bash

# Disk Configuration Module

DISK_CONFIG_FILE="/tmp/gentoo-disk-config"

# Global variables
declare -gA DISK_CONFIG
DISK_CONFIG[boot_device]=""
DISK_CONFIG[root_device]=""
DISK_CONFIG[boot_size]="512M"
DISK_CONFIG[swap_size]="2G"
DISK_CONFIG[root_size]=""

log_disk() {
    echo -e "${GREEN}[DISK]${NC} $1"
}

show_disk_menu() {
    local choice
    choice=$(dialog --title "Disk Configuration" \
        --menu "Select option:" 15 60 6 \
        1 "Select Boot Device (Current: ${DISK_CONFIG[boot_device]})" \
        2 "Select Root Device (Current: ${DISK_CONFIG[root_device]})" \
        3 "Configure Partition Sizes" \
        4 "Setup Software RAID" \
        5 "Partition and Format" \
        6 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) select_boot_device ;;
        2) select_root_device ;;
        3) configure_partition_sizes ;;
        4) setup_raid ;;
        5) partition_and_format ;;
        6) return ;;
    esac
    
    show_disk_menu
}

select_boot_device() {
    local disks=($(lsblk -d -n -o NAME,SIZE | awk '{print "/dev/" $1 " (" $2 ")"}'))
    local disk_list=""
    
    for i in "${!disks[@]}"; do
        disk_list="$disk_list $((i+1)) ${disks[$i]}"
    done
    
    local choice=$(dialog --title "Select Boot Device" \
        --menu "Choose disk for boot:" 15 60 5 \
        $disk_list \
        3>&1 1>&2 2>&3)
    
    if [[ -n "$choice" ]]; then
        DISK_CONFIG[boot_device]="${disks[$((choice-1))]}"
    fi
}

select_root_device() {
    local disks=($(lsblk -d -n -o NAME,SIZE | awk '{print "/dev/" $1 " (" $2 ")"}'))
    local disk_list=""
    
    for i in "${!disks[@]}"; do
        disk_list="$disk_list $((i+1)) ${disks[$i]}"
    done
    
    local choice=$(dialog --title "Select Root Device" \
        --menu "Choose disk for root:" 15 60 5 \
        $disk_list \
        3>&1 1>&2 2>&3)
    
    if [[ -n "$choice" ]]; then
        DISK_CONFIG[root_device]="${disks[$choice-1]}"
    fi
}

configure_partition_sizes() {
    DISK_CONFIG[boot_size]=$(dialog --title "Boot Partition Size" \
        --inputbox "Enter boot partition size (e.g., 512M, 1G):" 8 40 "${DISK_CONFIG[boot_size]}" \
        3>&1 1>&2 2>&3)
    
    DISK_CONFIG[swap_size]=$(dialog --title "Swap Partition Size" \
        --inputbox "Enter swap partition size (e.g., 2G, 4G):" 8 40 "${DISK_CONFIG[swap_size]}" \
        3>&1 1>&2 2>&3)
    
    DISK_CONFIG[root_size]=$(dialog --title "Root Partition Size" \
        --inputbox "Enter root partition size (leave empty for all remaining space):" 8 40 "${DISK_CONFIG[root_size]}" \
        3>&1 1>&2 2>&3)
}

setup_raid() {
    local choice=$(dialog --title "Software RAID Setup" \
        --menu "RAID Configuration:" 15 60 4 \
        1 "Enable RAID" \
        2 "Disable RAID" \
        3 "Configure RAID Arrays" \
        4 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            CONFIG[use_raid]="true"
            dialog --msgbox "RAID support enabled. Please configure RAID arrays." 7 40
            ;;
        2)
            CONFIG[use_raid]="false"
            dialog --msgbox "RAID support disabled." 7 40
            ;;
    esac
}

partition_and_format() {
    if [[ -z "${DISK_CONFIG[boot_device]}" ]] || [[ -z "${DISK_CONFIG[root_device]}" ]]; then
        dialog --msgbox "Please select boot and root devices first!" 7 40
        return
    fi
    
    dialog --title "Partition and Format" \
        --yesno "This will partition and format:\nBoot: ${DISK_CONFIG[boot_device]}\nRoot: ${DISK_CONFIG[root_device]}\n\nAll data on these devices will be lost!\n\nContinue?" 12 50
    
    if [[ $? -eq 0 ]]; then
        perform_partitioning
    fi
}

perform_partitioning() {
    log_disk "Starting disk partitioning..."
    
    local boot_disk=$(echo "${DISK_CONFIG[boot_device]}" | awk '{print $1}')
    local root_disk=$(echo "${DISK_CONFIG[root_device]}" | awk '{print $1}')
    
    # Partition boot disk
    log_disk "Partitioning boot disk: $boot_disk"
    parted -s "$boot_disk" mklabel gpt
    parted -s "$boot_disk" mkpart primary fat32 1MiB ${DISK_CONFIG[boot_size]}
    parted -s "$boot_disk" set 1 esp on
    
    # Partition root disk
    log_disk "Partitioning root disk: $root_disk"
    parted -s "$root_disk" mklabel gpt
    if [[ -n "${DISK_CONFIG[root_size]}" ]]; then
        local end_size=$(( $(blockdev --getsize64 "$root_disk") / 1024 / 1024 - 1 ))
        parted -s "$root_disk" mkpart primary ${DISK_CONFIG[root_size]} "${end_size}MiB"
    else
        parted -s "$root_disk" mkpart primary 1MiB 100%
    fi
    
    # Create filesystems
    create_filesystems
}

create_filesystems() {
    log_disk "Creating filesystems..."
    
    local boot_disk=$(echo "${DISK_CONFIG[boot_device]}" | awk '{print $1}')
    local root_disk=$(echo "${DISK_CONFIG[root_device]}" | awk '{print $1}')
    
    # Format boot partition
    mkfs.vfat -F32 "${boot_disk}1"
    
    # Format root partition
    case "${CONFIG[root_fs]}" in
        ext4)
            mkfs.ext4 "${root_disk}1"
            ;;
        btrfs)
            mkfs.btrfs "${root_disk}1"
            ;;
    esac
    
    log_disk "Filesystems created successfully"
    dialog --msgbox "Disk partitioning and formatting completed successfully!" 8 40
}

# Initialize disk config
load_disk_config() {
    if [[ -f "$DISK_CONFIG_FILE" ]]; then
        source "$DISK_CONFIG_FILE"
    fi
}

save_disk_config() {
    > "$DISK_CONFIG_FILE"
    for key in "${!DISK_CONFIG[@]}"; do
        echo "DISK_CONFIG[$key]=\"${DISK_CONFIG[$key]}\"" >> "$DISK_CONFIG_FILE"
    done
}

# Main execution
load_disk_config
show_disk_menu
