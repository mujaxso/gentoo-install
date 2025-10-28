#!/usr/bin/env bash
list_disks() { lsblk -dpno NAME,SIZE,TYPE | grep disk; }

select_target_disk() {
    local disks=()
    while IFS= read -r line; do
        local disk_name=$(echo "$line" | awk '{print $1}')
        local disk_size=$(echo "$line" | awk '{print $2}')
        
        # Get the root disk (the disk where / is mounted)
        local root_disk=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/[0-9]*$//')
        
        # Skip if this is the root disk
        if [[ "$disk_name" != "$root_disk" ]]; then
            disks+=("$disk_name" "$disk_size")
        fi
    done < <(list_disks)
    
    if [ ${#disks[@]} -eq 0 ]; then
        show_error "No available disks found."
        log_error "This could be because:"
        log_error "  - All disks are in use (including the system disk)"
        log_error "  - No additional disks are connected"
        log_error "  - Disk detection is failing"
        
        # Show available disks for debugging
        log_info "All detected disks:"
        list_disks
        
        # Offer to show all disks including root disk
        if show_yesno "Show all disks (including system disk)?"; then
            local all_disks=()
            while IFS= read -r line; do
                local disk_name=$(echo "$line" | awk '{print $1}')
                local disk_size=$(echo "$line" | awk '{print $2}')
                local root_disk=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/[0-9]*$//')
                local marker=""
                if [[ "$disk_name" == "$root_disk" ]]; then
                    marker=" (SYSTEM DISK - DANGEROUS)"
                fi
                all_disks+=("$disk_name" "$disk_size$marker")
            done < <(list_disks)
            
            # Let user choose even if it's the system disk (with warning)
            local selected_disk=$(show_menu "Select Disk (WARNING: System disk is marked)" "${all_disks[@]}")
            if [[ -n "$selected_disk" ]]; then
                if [[ "$selected_disk" == "$root_disk" ]]; then
                    if show_yesno "WARNING: This is your SYSTEM DISK! All data will be lost! Continue?"; then
                        CONFIG[INSTALL_DISK]="$selected_disk"
                        log_success "Selected: ${CONFIG[INSTALL_DISK]} (SYSTEM DISK - PROCEED WITH CAUTION)"
                        return 0
                    else
                        return 1
                    fi
                else
                    CONFIG[INSTALL_DISK]="$selected_disk"
                    log_success "Selected: ${CONFIG[INSTALL_DISK]}"
                    return 0
                fi
            else
                return 1
            fi
        else
            return 1
        fi
    fi
    
    CONFIG[INSTALL_DISK]=$(show_menu "Select Disk" "${disks[@]}")
    log_success "Selected: ${CONFIG[INSTALL_DISK]}"
    return 0
}

get_partition_name() {
    [[ $1 == *"nvme"* ]] && echo "${1}p${2}" || echo "${1}${2}"
}

wipe_disk() {
    show_info "Wiping disk ${CONFIG[INSTALL_DISK]}. ALL DATA WILL BE LOST!"
    if show_yesno "Are you absolutely sure you want to wipe ${CONFIG[INSTALL_DISK]}?"; then
        # Reset disk state first
        reset_disk_state "${CONFIG[INSTALL_DISK]}"
        
        # Use wipefs to remove signatures from all partitions and the disk itself
        log_info "Removing existing filesystem signatures..."
        for partition in $(lsblk -lnpo NAME "${CONFIG[INSTALL_DISK]}" | grep -v "^${CONFIG[INSTALL_DISK]}$"); do
            wipefs -af "$partition" 2>/dev/null || true
        done
        wipefs -af "${CONFIG[INSTALL_DISK]}" 2>/dev/null || true
        
        # Clear the first few MB to remove any remaining partition data
        log_info "Clearing partition data..."
        dd if=/dev/zero of="${CONFIG[INSTALL_DISK]}" bs=1M count=10 2>/dev/null || true
        
        # Create new partition table
        log_info "Creating new GPT partition table..."
        parted -s "${CONFIG[INSTALL_DISK]}" mklabel gpt
        
        # Force kernel to reread partition table multiple times
        log_info "Refreshing partition table..."
        local partprobe_attempts=5
        while [ $partprobe_attempts -gt 0 ]; do
            if partprobe "${CONFIG[INSTALL_DISK]}" 2>/dev/null; then
                break
            fi
            sleep 2
            partprobe_attempts=$((partprobe_attempts - 1))
        done
        
        # Wait for disk to settle
        sleep 3
        
        # Verify the disk is ready
        local verify_attempts=5
        while [ $verify_attempts -gt 0 ]; do
            if parted -s "${CONFIG[INSTALL_DISK]}" print >/dev/null 2>&1; then
                log_success "Disk wiped successfully"
                return 0
            fi
            log_info "Waiting for disk to be ready... ($verify_attempts attempts remaining)"
            sleep 2
            verify_attempts=$((verify_attempts - 1))
        done
        
        log_error "Disk is not responding after wipe operation"
        return 1
    else
        log_error "Disk wipe cancelled"
        return 1
    fi
}

create_efi_partitions() {
    local disk="${CONFIG[INSTALL_DISK]}"
    
    # Ensure the disk is ready
    log_info "Creating EFI partitions on $disk..."
    
    # Refresh partition table before starting
    partprobe "$disk" 2>/dev/null || true
    sleep 3
    
    # Create all partitions in one go to minimize kernel update issues
    log_info "Creating partition layout..."
    if ! parted -s "$disk" -- \
        mklabel gpt \
        mkpart primary fat32 1MiB 513MiB \
        set 1 esp on \
        mkpart primary ext4 513MiB 1537MiB; then
        log_error "Failed to create EFI/boot partitions"
        return 1
    fi
    
    # Get memory size safely
    local memory_gb=$(get_memory_gb)
    if [[ -z "$memory_gb" ]] || [[ "$memory_gb" -lt 1 ]]; then
        memory_gb=4  # Default to 4GB if we can't determine
    fi
    local swap_end=$((1537 + memory_gb * 1024))
    
    # Create swap and root partitions
    if ! parted -s "$disk" -- \
        mkpart primary linux-swap 1537MiB "${swap_end}MiB" \
        mkpart primary ext4 "${swap_end}MiB" 100%; then
        log_error "Failed to create swap/root partitions"
        return 1
    fi
    
    # Force kernel to reread partition table multiple times
    log_info "Updating partition table..."
    local partprobe_attempts=5
    while [ $partprobe_attempts -gt 0 ]; do
        if partprobe "$disk" 2>/dev/null; then
            break
        fi
        sleep 2
        partprobe_attempts=$((partprobe_attempts - 1))
    done
    
    # Wait longer for partitions to appear
    sleep 5
    
    # Wait for partitions to be available
    local attempts=10
    while [ $attempts -gt 0 ]; do
        local part1=$(get_partition_name "$disk" 1)
        local part2=$(get_partition_name "$disk" 2)
        local part3=$(get_partition_name "$disk" 3)
        local part4=$(get_partition_name "$disk" 4)
        
        if [[ -e "$part1" ]] && [[ -e "$part2" ]] && [[ -e "$part3" ]] && [[ -e "$part4" ]]; then
            log_success "All partitions created successfully"
            break
        fi
        log_info "Waiting for partitions to appear... ($attempts attempts remaining)"
        sleep 3
        attempts=$((attempts - 1))
    done
    
    if [ $attempts -eq 0 ]; then
        log_error "Some partitions did not appear after creation"
        log_error "Expected partitions:"
        log_error "  $(get_partition_name "$disk" 1)"
        log_error "  $(get_partition_name "$disk" 2)" 
        log_error "  $(get_partition_name "$disk" 3)"
        log_error "  $(get_partition_name "$disk" 4)"
        log_error "Current block devices:"
        lsblk -lnpo NAME "$disk" | while read line; do
            log_error "  $line"
        done
        return 1
    fi
    
    CONFIG[EFI_PART]=$(get_partition_name "$disk" 1)
    CONFIG[BOOT_PART]=$(get_partition_name "$disk" 2)
    CONFIG[SWAP_PART]=$(get_partition_name "$disk" 3)
    CONFIG[ROOT_PART]=$(get_partition_name "$disk" 4)
    
    log_success "Partitions created:"
    log_success "  EFI: ${CONFIG[EFI_PART]}"
    log_success "  Boot: ${CONFIG[BOOT_PART]}"
    log_success "  Swap: ${CONFIG[SWAP_PART]}"
    log_success "  Root: ${CONFIG[ROOT_PART]}"
    
    # Final partprobe to ensure everything is synced
    partprobe "$disk" 2>/dev/null || true
    sleep 2
}

create_bios_partitions() {
    local disk="${CONFIG[INSTALL_DISK]}"
    
    # Ensure the disk is ready
    log_info "Creating BIOS partitions on $disk..."
    
    # Refresh partition table before starting
    partprobe "$disk" 2>/dev/null || true
    sleep 3
    
    # Create all partitions in one go
    log_info "Creating partition layout..."
    if ! parted -s "$disk" -- \
        mklabel gpt \
        mkpart primary 1MiB 2MiB \
        set 1 bios_grub on \
        mkpart primary ext4 2MiB 1026MiB; then
        log_error "Failed to create BIOS/boot partitions"
        return 1
    fi
    
    # Get memory size safely
    local memory_gb=$(get_memory_gb)
    if [[ -z "$memory_gb" ]] || [[ "$memory_gb" -lt 1 ]]; then
        memory_gb=4  # Default to 4GB if we can't determine
    fi
    local swap_end=$((1026 + memory_gb * 1024))
    
    # Create swap and root partitions
    if ! parted -s "$disk" -- \
        mkpart primary linux-swap 1026MiB "${swap_end}MiB" \
        mkpart primary ext4 "${swap_end}MiB" 100%; then
        log_error "Failed to create swap/root partitions"
        return 1
    fi
    
    # Force kernel to reread partition table
    log_info "Updating partition table..."
    local partprobe_attempts=5
    while [ $partprobe_attempts -gt 0 ]; do
        if partprobe "$disk" 2>/dev/null; then
            break
        fi
        sleep 2
        partprobe_attempts=$((partprobe_attempts - 1))
    done
    
    # Wait longer for partitions to appear
    sleep 5
    
    # Wait for partitions to be available
    local attempts=10
    while [ $attempts -gt 0 ]; do
        local part2=$(get_partition_name "$disk" 2)
        local part3=$(get_partition_name "$disk" 3)
        local part4=$(get_partition_name "$disk" 4)
        
        if [[ -e "$part2" ]] && [[ -e "$part3" ]] && [[ -e "$part4" ]]; then
            log_success "All partitions created successfully"
            break
        fi
        log_info "Waiting for partitions to appear... ($attempts attempts remaining)"
        sleep 3
        attempts=$((attempts - 1))
    done
    
    if [ $attempts -eq 0 ]; then
        log_error "Some partitions did not appear after creation"
        log_error "Expected partitions:"
        log_error "  $(get_partition_name "$disk" 2)" 
        log_error "  $(get_partition_name "$disk" 3)"
        log_error "  $(get_partition_name "$disk" 4)"
        return 1
    fi
    
    CONFIG[BOOT_PART]=$(get_partition_name "$disk" 2)
    CONFIG[SWAP_PART]=$(get_partition_name "$disk" 3)
    CONFIG[ROOT_PART]=$(get_partition_name "$disk" 4)
    
    log_success "Partitions created:"
    log_success "  Boot: ${CONFIG[BOOT_PART]}"
    log_success "  Swap: ${CONFIG[SWAP_PART]}"
    log_success "  Root: ${CONFIG[ROOT_PART]}"
    
    # Final partprobe to ensure everything is synced
    partprobe "$disk" 2>/dev/null || true
    sleep 2
}

reset_disk_state() {
    local disk="$1"
    log_info "Resetting disk state for $disk..."
    
    # Unmount all partitions on this disk
    for partition in $(lsblk -lnpo NAME "$disk" | grep -v "^$disk$"); do
        log_info "Unmounting $partition"
        umount -f "$partition" 2>/dev/null || true
    done
    
    # Try to remove any LVM volumes
    if command -v vgremove &>/dev/null; then
        vgremove -f $(pvs --noheadings -o vg_name $disk 2>/dev/null) 2>/dev/null || true
        pvremove -f $disk 2>/dev/null || true
    fi
    
    # Try to remove any mdraid arrays
    if command -v mdadm &>/dev/null; then
        mdadm --stop $(mdadm --detail --scan | grep "$disk" | cut -d: -f1) 2>/dev/null || true
        mdadm --zero-superblock $disk 2>/dev/null || true
    fi
    
    # Try to close any LUKS containers
    if command -v cryptsetup &>/dev/null; then
        cryptsetup close $(dmsetup ls --target crypt | grep -o "^\S*" | xargs -I {} sh -c "cryptsetup status {} 2>/dev/null | grep -q \"$disk\" && echo {}") 2>/dev/null || true
    fi
    
    # Force kernel to reread partition table
    partprobe "$disk" 2>/dev/null || true
    sleep 2
}

partition_disk() {
    # Reset disk state first
    reset_disk_state "${CONFIG[INSTALL_DISK]}"
    
    # Then wipe and partition
    wipe_disk
    [ "${CONFIG[BOOT_MODE]}" = "efi" ] && create_efi_partitions || create_bios_partitions
    log_success "Partitioned"
}
