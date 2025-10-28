#!/usr/bin/env bash
list_disks() { lsblk -dpno NAME,SIZE,TYPE | grep disk; }

select_target_disk() {
    local disks=()
    while IFS= read -r line; do
        local disk_name=$(echo "$line" | awk '{print $1}')
        # Skip if this is the root disk
        if ! mount | grep -q "^$disk_name"; then
            disks+=("$disk_name" "$(echo "$line" | awk '{print $2}')")
        fi
    done < <(list_disks)
    
    if [ ${#disks[@]} -eq 0 ]; then
        show_error "No available disks found. Make sure you're not trying to use the system disk."
        return 1
    fi
    
    CONFIG[INSTALL_DISK]=$(show_menu "Select Disk" "${disks[@]}")
    log_success "Selected: ${CONFIG[INSTALL_DISK]}"
}

get_partition_name() {
    [[ $1 == *"nvme"* ]] && echo "${1}p${2}" || echo "${1}${2}"
}

wipe_disk() {
    show_info "Wiping disk ${CONFIG[INSTALL_DISK]}. ALL DATA WILL BE LOST!"
    if show_yesno "Are you absolutely sure you want to wipe ${CONFIG[INSTALL_DISK]}?"; then
        # Unmount any mounted partitions first
        for partition in $(lsblk -lnpo NAME "${CONFIG[INSTALL_DISK]}" | tail -n +2); do
            umount "$partition" 2>/dev/null || true
        done
        
        # Use wipefs to remove signatures
        wipefs -af "${CONFIG[INSTALL_DISK]}" 2>/dev/null || true
        
        # Create new partition table
        parted -s "${CONFIG[INSTALL_DISK]}" mklabel gpt
        
        # Force kernel to reread partition table
        partprobe "${CONFIG[INSTALL_DISK]}" || true
        sleep 3
        
        # Sometimes we need to try multiple times
        local attempts=3
        while [ $attempts -gt 0 ]; do
            if parted -s "${CONFIG[INSTALL_DISK]}" print >/dev/null 2>&1; then
                break
            fi
            sleep 2
            attempts=$((attempts - 1))
        done
        
        log_success "Disk wiped successfully"
    else
        log_error "Disk wipe cancelled"
        return 1
    fi
}

create_efi_partitions() {
    local disk="${CONFIG[INSTALL_DISK]}"
    
    # Ensure the disk is ready
    partprobe "$disk" || true
    sleep 2
    
    # Create partitions
    parted -s "$disk" mkpart primary fat32 1MiB 513MiB
    parted -s "$disk" set 1 esp on
    parted -s "$disk" mkpart primary ext4 513MiB 1537MiB
    
    # Get memory size safely
    local memory_gb=$(get_memory_gb)
    if [[ -z "$memory_gb" ]] || [[ "$memory_gb" -lt 1 ]]; then
        memory_gb=4  # Default to 4GB if we can't determine
    fi
    local swap_end=$((1537 + memory_gb * 1024))
    
    parted -s "$disk" mkpart primary linux-swap 1537MiB "${swap_end}MiB"
    parted -s "$disk" mkpart primary ext4 "${swap_end}MiB" 100%
    
    # Update kernel partition table
    partprobe "$disk" || true
    sleep 3
    
    # Wait for partitions to be available
    local attempts=5
    while [ $attempts -gt 0 ]; do
        if [[ -e "$(get_partition_name "$disk" 1)" ]] && \
           [[ -e "$(get_partition_name "$disk" 2)" ]] && \
           [[ -e "$(get_partition_name "$disk" 3)" ]] && \
           [[ -e "$(get_partition_name "$disk" 4)" ]]; then
            break
        fi
        sleep 2
        attempts=$((attempts - 1))
    done
    
    CONFIG[EFI_PART]=$(get_partition_name "$disk" 1)
    CONFIG[BOOT_PART]=$(get_partition_name "$disk" 2)
    CONFIG[SWAP_PART]=$(get_partition_name "$disk" 3)
    CONFIG[ROOT_PART]=$(get_partition_name "$disk" 4)
}

create_bios_partitions() {
    local disk="${CONFIG[INSTALL_DISK]}"
    
    # Ensure the disk is ready
    partprobe "$disk" || true
    sleep 2
    
    # Create partitions
    parted -s "$disk" mkpart primary 1MiB 2MiB
    parted -s "$disk" set 1 bios_grub on
    parted -s "$disk" mkpart primary ext4 2MiB 1026MiB
    
    # Get memory size safely
    local memory_gb=$(get_memory_gb)
    if [[ -z "$memory_gb" ]] || [[ "$memory_gb" -lt 1 ]]; then
        memory_gb=4  # Default to 4GB if we can't determine
    fi
    local swap_end=$((1026 + memory_gb * 1024))
    
    parted -s "$disk" mkpart primary linux-swap 1026MiB "${swap_end}MiB"
    parted -s "$disk" mkpart primary ext4 "${swap_end}MiB" 100%
    
    # Update kernel partition table
    partprobe "$disk" || true
    sleep 3
    
    # Wait for partitions to be available
    local attempts=5
    while [ $attempts -gt 0 ]; do
        if [[ -e "$(get_partition_name "$disk" 2)" ]] && \
           [[ -e "$(get_partition_name "$disk" 3)" ]] && \
           [[ -e "$(get_partition_name "$disk" 4)" ]]; then
            break
        fi
        sleep 2
        attempts=$((attempts - 1))
    done
    
    CONFIG[BOOT_PART]=$(get_partition_name "$disk" 2)
    CONFIG[SWAP_PART]=$(get_partition_name "$disk" 3)
    CONFIG[ROOT_PART]=$(get_partition_name "$disk" 4)
}

partition_disk() {
    wipe_disk
    [ "${CONFIG[BOOT_MODE]}" = "efi" ] && create_efi_partitions || create_bios_partitions
    log_success "Partitioned"
}
