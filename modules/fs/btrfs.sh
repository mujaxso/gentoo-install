#!/usr/bin/env bash

format_btrfs_root() {
    # Check if btrfs-tools are available
    if ! command -v mkfs.btrfs &>/dev/null; then
        log_error "mkfs.btrfs command not found. Please install btrfs-progs."
        return 1
    fi
    
    mkfs.btrfs -f -L ROOT "$1"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to format Btrfs filesystem"
        return 1
    fi
}

mount_btrfs_root() {
    local dev="${CONFIG[ROOT_PART]}"
    local mp="${CONFIG[MOUNT_POINT]}"
    
    # Check if btrfs-tools are available
    if ! command -v btrfs &>/dev/null; then
        log_error "btrfs command not found. Please install btrfs-progs."
        return 1
    fi
    
    # Ensure mount point exists
    mkdir -p "$mp"
    
    # First, try to mount the root subvolume
    if ! mount -o defaults,noatime,compress=zstd:1,subvol=@ "$dev" "$mp"; then
        log_info "Root subvolume @ not found, creating Btrfs subvolumes..."
        
        # Mount the raw filesystem to create subvolumes
        if ! mount "$dev" /mnt; then
            log_error "Failed to mount raw Btrfs filesystem for subvolume creation"
            return 1
        fi
        
        # Create required subvolumes
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@snapshots
        
        # Unmount the raw filesystem
        umount /mnt || {
            log_error "Failed to unmount temporary filesystem"
            return 1
        }
        
        # Now try to mount the root subvolume again
        if ! mount -o defaults,noatime,compress=zstd:1,subvol=@ "$dev" "$mp"; then
            log_error "Failed to mount root subvolume after creation"
            return 1
        fi
    fi
    
    # Verify the root subvolume is mounted
    if ! mountpoint -q "$mp"; then
        log_error "Root filesystem is not mounted at $mp"
        return 1
    fi
    
    # Create and mount home subvolume
    mkdir -p "${mp}/home"
    if ! mount -o defaults,noatime,compress=zstd:1,subvol=@home "$dev" "${mp}/home"; then
        log_info "Home subvolume @home not found, creating it..."
        
        # Mount the raw filesystem to create the home subvolume
        if ! mount "$dev" /mnt; then
            log_error "Failed to mount raw Btrfs filesystem for home subvolume creation"
            return 1
        fi
        
        btrfs subvolume create /mnt/@home
        
        # Unmount the raw filesystem
        umount /mnt || {
            log_error "Failed to unmount temporary filesystem"
            return 1
        }
        
        # Try to mount the home subvolume again
        if ! mount -o defaults,noatime,compress=zstd:1,subvol=@home "$dev" "${mp}/home"; then
            log_error "Failed to mount home subvolume after creation"
            return 1
        fi
    fi
    
    log_success "Btrfs filesystems mounted successfully"
}
