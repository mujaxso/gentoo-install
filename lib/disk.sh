#!/usr/bin/env bash
list_disks() { lsblk -dpno NAME,SIZE,TYPE | grep disk; }

select_target_disk() {
    local disks=()
    while IFS= read -r line; do
        disks+=("$(echo "$line" | awk '{print $1}')" "$(echo "$line" | awk '{print $2}')")
    done < <(list_disks)
    CONFIG[INSTALL_DISK]=$(show_menu "Select Disk" "${disks[@]}")
    log_success "Selected: ${CONFIG[INSTALL_DISK]}"
}

get_partition_name() {
    [[ $1 == *"nvme"* ]] && echo "${1}p${2}" || echo "${1}${2}"
}

wipe_disk() {
    wipefs -af "${CONFIG[INSTALL_DISK]}" 2>/dev/null || true
    sgdisk -Z "${CONFIG[INSTALL_DISK]}"
    partprobe "${CONFIG[INSTALL_DISK]}" && sleep 2
}

create_efi_partitions() {
    local disk="${CONFIG[INSTALL_DISK]}"
    parted -s "$disk" mklabel gpt
    parted -s "$disk" mkpart primary fat32 1MiB 513MiB
    parted -s "$disk" set 1 esp on
    parted -s "$disk" mkpart primary ext4 513MiB 1537MiB
    local swap_end=$((1537 + $(get_memory_gb) * 1024))
    parted -s "$disk" mkpart primary linux-swap 1537MiB "${swap_end}MiB"
    parted -s "$disk" mkpart primary ext4 "${swap_end}MiB" 100%
    partprobe "$disk" && sleep 2
    CONFIG[EFI_PART]=$(get_partition_name "$disk" 1)
    CONFIG[BOOT_PART]=$(get_partition_name "$disk" 2)
    CONFIG[SWAP_PART]=$(get_partition_name "$disk" 3)
    CONFIG[ROOT_PART]=$(get_partition_name "$disk" 4)
}

create_bios_partitions() {
    local disk="${CONFIG[INSTALL_DISK]}"
    parted -s "$disk" mklabel gpt
    parted -s "$disk" mkpart primary 1MiB 2MiB
    parted -s "$disk" set 1 bios_grub on
    parted -s "$disk" mkpart primary ext4 2MiB 1026MiB
    local swap_end=$((1026 + $(get_memory_gb) * 1024))
    parted -s "$disk" mkpart primary linux-swap 1026MiB "${swap_end}MiB"
    parted -s "$disk" mkpart primary ext4 "${swap_end}MiB" 100%
    partprobe "$disk" && sleep 2
    CONFIG[BOOT_PART]=$(get_partition_name "$disk" 2)
    CONFIG[SWAP_PART]=$(get_partition_name "$disk" 3)
    CONFIG[ROOT_PART]=$(get_partition_name "$disk" 4)
}

partition_disk() {
    wipe_disk
    [ "${CONFIG[BOOT_MODE]}" = "efi" ] && create_efi_partitions || create_bios_partitions
    log_success "Partitioned"
}
