#!/bin/bash

# Disk Configuration Module - Updated for AMD64 Handbook (fdisk/GPT/MBR)

DISK_CONFIG_FILE="/tmp/gentoo-disk-config"

# Global variables
declare -gA DISK_CONFIG
DISK_CONFIG[boot_device]=""
DISK_CONFIG[root_device]=""
DISK_CONFIG[boot_size]="1G"  # Updated to 1G as recommended
DISK_CONFIG[swap_size]="2G"
DISK_CONFIG[root_size]=""
DISK_CONFIG[partition_type]="gpt"  # Default to GPT
DISK_CONFIG[esp_size]="1G"  # EFI System Partition size

log_disk() {
    echo -e "${GREEN}[DISK]${NC} $1"
}

show_disk_menu() {
    local choice
    choice=$(dialog --title "Disk Configuration (AMD64 Handbook)" \
        --menu "Select option:" 18 70 9 \
        1 "Select Boot Device (Current: ${DISK_CONFIG[boot_device]})" \
        2 "Select Root Device (Current: ${DISK_CONFIG[root_device]})" \
        3 "Choose Partition Table (Current: ${DISK_CONFIG[partition_type]})" \
        4 "Configure Partition Sizes" \
        5 "Setup Software RAID" \
        6 "Partition with fdisk" \
        7 "Format Partitions" \
        8 "View Partition Layout" \
        9 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) select_boot_device ;;
        2) select_root_device ;;
        3) select_partition_type ;;
        4) configure_partition_sizes ;;
        5) setup_raid ;;
        6) partition_with_fdisk ;;
        7) format_partitions ;;
        8) view_partition_layout ;;
        9) return ;;
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

select_partition_type() {
    local choice=$(dialog --title "Partition Table Type" \
        --menu "Choose partition table type:" 12 50 3 \
        1 "GPT (recommended for UEFI)" \
        2 "MBR/DOS (for legacy BIOS)" \
        3 "Back" \
        3>&1 1>&2 2>&3)

    case $choice in
        1) DISK_CONFIG[partition_type]="gpt" ;;
        2) DISK_CONFIG[partition_type]="mbr" ;;
    esac
}

configure_partition_sizes() {
    local boot_size=$(dialog --title "Boot Partition Size" \
        --inputbox "Enter boot partition size (e.g., 1G, 512M):" 8 40 "${DISK_CONFIG[boot_size]}" \
        3>&1 1>&2 2>&3)
    
    local swap_size=$(dialog --title "Swap Partition Size" \
        --inputbox "Enter swap partition size (e.g., 2G, 4G):" 8 40 "${DISK_CONFIG[swap_size]}" \
        3>&1 1>&2 2>&3)
    
    local root_size=$(dialog --title "Root Partition Size" \
        --inputbox "Enter root partition size (leave empty for all remaining space):" 8 40 "${DISK_CONFIG[root_size]}" \
        3>&1 1>&2 2>&3)
    
    # Update ESP size if using UEFI
    if [[ "${CONFIG[boot_mode]}" == "efi" ]]; then
        DISK_CONFIG[esp_size]="1G"
    fi
    
    DISK_CONFIG[boot_size]="$boot_size"
    DISK_CONFIG[swap_size]="$swap_size"
    DISK_CONFIG[root_size]="$root_size"
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

partition_with_fdisk() {
    if [[ -z "${DISK_CONFIG[boot_device]}" ]] || [[ -z "${DISK_CONFIG[root_device]}" ]]; then
        dialog --msgbox "Please select boot and root devices first!" 7 40
        return
    fi
    
    dialog --title "Partition with fdisk" \
        --yesno "This will partition disks using fdisk:\n\nBoot: ${DISK_CONFIG[boot_device]}\nRoot: ${DISK_CONFIG[root_device]}\nPartition Table: ${DISK_CONFIG[partition_type]}\n\nAll data on these devices will be lost!\n\nContinue?" 15 50
    
    if [[ $? -eq 0 ]]; then
        if [[ "${DISK_CONFIG[partition_type]}" == "gpt" ]]; then
            partition_gpt_disk
        else
            partition_mbr_disk
        fi
    fi
}

partition_gpt_disk() {
    log_disk "Partitioning with GPT using fdisk..."
    
    local boot_disk=$(echo "${DISK_CONFIG[boot_device]}" | awk '{print $1}')
    local root_disk=$(echo "${DISK_CONFIG[root_device]}" | awk '{print $1}')
    
    # Create GPT disklabel on boot disk
    echo "Creating GPT disklabel on $boot_disk..."
    echo "g" | fdisk "${boot_disk}" 2>/dev/null
    
    # Create EFI System Partition (ESP) if UEFI
    if [[ "${CONFIG[boot_mode]}" == "efi" ]]; then
        echo "Creating EFI System Partition..."
        echo "n" | fdisk "${boot_disk}" 2>/dev/null
        echo "1" | fdisk "${boot_disk}" 2>/dev/null
        echo "" | fdisk "${boot_disk}" 2>/dev/null
        echo "+${DISK_CONFIG[esp_size]}" | fdisk "${boot_disk}" 2>/dev/null
        echo "t" | fdisk "${boot_disk}" 2>/dev/null
        echo "1" | fdisk "${boot_disk}" 2>/dev/null
        echo "ef" | fdisk "${boot_disk}" 2>/dev/null
    fi
    
    # Create boot partition for BIOS/Legacy
    if [[ "${CONFIG[boot_mode]}" == "bios" ]]; then
        echo "Creating BIOS boot partition..."
        echo "n" | fdisk "${boot_disk}" 2>/dev/null
        echo "1" | fdisk "${boot_disk}" 2>/dev/null
        echo "" | fdisk "${boot_disk}" 2>/dev/null
        echo "+${DISK_CONFIG[boot_size]}" | fdisk "${boot_disk}" 2>/dev/null
        echo "t" | fdisk "${boot_disk}" 2>/dev/null
        echo "1" | fdisk "${boot_disk}" 2>/dev/null
        echo "ef02" | fdisk "${boot_disk}" 2>/dev/null
    fi
    
    # Write changes
    echo "Writing partition table..."
    echo "w" | fdisk "${boot_disk}" 2>/dev/null
    
    # Partition root disk
    echo "Creating GPT disklabel on $root_disk..."
    echo "g" | fdisk "${root_disk}" 2>/dev/null
    
    # Create swap partition
    echo "Creating swap partition..."
    echo "n" | fdisk "${root_disk}" 2>/dev/null
    echo "1" | fdisk "${root_disk}" 2>/dev/null
    echo "" | fdisk "${root_disk}" 2>/dev/null
    echo "+${DISK_CONFIG[swap_size]}" | fdisk "${root_disk}" 2>/dev/null
    echo "t" | fdisk "${root_disk}" 2>/dev/null
    echo "1" | fdisk "${root_disk}" 2>/dev/null
    echo "19" | fdisk "${root_disk}" 2>/dev/null  # Linux swap
    
    # Create root partition
    echo "Creating root partition..."
    echo "n" | fdisk "${root_disk}" 2>/dev/null
    echo "2" | fdisk "${root_disk}" 2>/dev/null
    echo "" | fdisk "${root_disk}" 2>/dev/null
    echo "" | fdisk "${root_disk}" 2>/dev/null  # Use remaining space
    
    # Set root partition type to Linux root
    echo "t" | fdisk "${root_disk}" 2>/dev/null
    echo "2" | fdisk "${root_disk}" 2>/dev/null
    echo "23" | fdisk "${root_disk}" 2>/dev/null  # Linux root (x86-64)
    
    # Write changes
    echo "Writing partition table..."
    echo "w" | fdisk "${root_disk}" 2>/dev/null
    
    log_disk "GPT partitioning completed"
    dialog --msgbox "GPT partitioning completed successfully!\n\nRun 'format_partitions' to create filesystems." 10 50
}

partition_mbr_disk() {
    log_disk "Partitioning with MBR using fdisk..."
    
    local boot_disk=$(echo "${DISK_CONFIG[boot_device]}" | awk '{print $1}')
    local root_disk=$(echo "${DISK_CONFIG[root_device]}" | awk '{print $1}')
    
    # Create MBR disklabel on boot disk
    echo "Creating MBR disklabel on $boot_disk..."
    echo "o" | fdisk "${boot_disk}" 2>/dev/null
    
    # Create boot partition
    echo "Creating boot partition..."
    echo "n" | fdisk "${boot_disk}" 2>/dev/null
    echo "p" | fdisk "${boot_disk}" 2>/dev/null
    echo "1" | fdisk "${boot_disk}" 2>/dev/null
    echo "" | fdisk "${boot_disk}" 2>/dev/null
    echo "+${DISK_CONFIG[boot_size]}" | fdisk "${boot_disk}" 2>/dev/null
    echo "a" | fdisk "${boot_disk}" 2>/dev/null
    echo "1" | fdisk "${boot_disk}" 2>/dev/null
    
    # Write changes
    echo "Writing partition table..."
    echo "w" | fdisk "${boot_disk}" 2>/dev/null
    
    # Partition root disk
    echo "Creating MBR disklabel on $root_disk..."
    echo "o" | fdisk "${root_disk}" 2>/dev/null
    
    # Create swap partition
    echo "Creating swap partition..."
    echo "n" | fdisk "${root_disk}" 2>/dev/null
    echo "p" | fdisk "${root_disk}" 2>/dev/null
    echo "1" | fdisk "${root_disk}" 2>/dev/null
    echo "" | fdisk "${root_disk}" 2>/dev/null
    echo "+${DISK_CONFIG[swap_size]}" | fdisk "${root_disk}" 2>/dev/null
    echo "t" | fdisk "${root_disk}" 2>/dev/null
    echo "1" | fdisk "${root_disk}" 2>/dev/null
    echo "82" | fdisk "${root_disk}" 2>/dev/null  # Linux swap
    
    # Create root partition
    echo "Creating root partition..."
    echo "n" | fdisk "${root_disk}" 2>/dev/null
    echo "p" | fdisk "${root_disk}" 2>/dev/null
    echo "2" | fdisk "${root_disk}" 2>/dev/null
    echo "" | fdisk "${root_disk}" 2>/dev/null
    echo "" | fdisk "${root_disk}" 2>/dev/null  # Use remaining space
    
    # Write changes
    echo "Writing partition table..."
    echo "w" | fdisk "${root_disk}" 2>/dev/null
    
    log_disk "MBR partitioning completed"
    dialog --msgbox "MBR partitioning completed successfully!\n\nRun 'format_partitions' to create filesystems." 10 50
}

format_partitions() {
    log_disk "Formatting partitions..."
    
    local boot_disk=$(echo "${DISK_CONFIG[boot_device]}" | awk '{print $1}')
    local root_disk=$(echo "${DISK_CONFIG[root_device]}" | awk '{print $1}')
    
    # Format boot/ESP partition
    if [[ "${CONFIG[boot_mode]}" == "efi" ]]; then
        log_disk "Formatting EFI System Partition as FAT32..."
        mkfs.vfat -F32 "${boot_disk}1"
    else
        log_disk "Formatting boot partition as XFS..."
        mkfs.xfs -f "${boot_disk}1"
    fi
    
    # Format root partition (XFS recommended)
    log_disk "Formatting root partition as ${CONFIG[root_fs]}..."
    case "${CONFIG[root_fs]}" in
        xfs)
            mkfs.xfs -f "${root_disk}2"
            ;;
        ext4)
            mkfs.ext4 "${root_disk}2"
            ;;
        btrfs)
            mkfs.btrfs -f "${root_disk}2"
            ;;
    esac
    
    # Format swap
    log_disk "Setting up swap partition..."
    mkswap "${root_disk}1"
    swapon "${root_disk}1"
    
    log_disk "All partitions formatted successfully"
    dialog --msgbox "Partition formatting completed successfully!" 8 40
}

view_partition_layout() {
    if [[ -z "${DISK_CONFIG[boot_device]}" ]] || [[ -z "${DISK_CONFIG[root_device]}" ]]; then
        dialog --msgbox "Please configure disks first!" 7 40
        return
    fi
    
    local boot_disk=$(echo "${DISK_CONFIG[boot_device]}" | awk '{print $1}')
    local root_disk=$(echo "${DISK_CONFIG[root_device]}" | awk '{print $1}')
    
    local layout="Current Partition Layout:\n\n"
    layout+="Boot Disk: $boot_disk\n"
    layout+="$(fdisk -l "$boot_disk" 2>/dev/null | grep "^/dev/" | awk '{print $1 " (" $5 ")" }')\n\n"
    layout+="Root Disk: $root_disk\n"
    layout+="$(fdisk -l "$root_disk" 2>/dev/null | grep "^/dev/" | awk '{print $1 " (" $5 ")" }')\n"
    
    dialog --title "Partition Layout" \
        --msgbox "$layout" 20 70
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
