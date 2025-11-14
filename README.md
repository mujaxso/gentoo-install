# Gentoo Linux Installer

A modular interactive shell script installer for Gentoo Linux with TUI interface.

## Features

- **TUI Interface**: User-friendly text-based interface using `dialog`
- **Multiple Init Systems**: Support for OpenRC and systemd
- **Boot Support**: Both EFI and BIOS/Legacy boot modes
- **Filesystem Support**: ext4, btrfs, zfs, and xfs
- **Encryption**: LUKS encryption for root and boot partitions
- **RAID Support**: Software RAID (mdadm) configuration
- **Modular Design**: Separate modules for different installation aspects

## Supported Configurations

### Init Systems
- OpenRC (Gentoo default)
- systemd

### Boot Modes
- EFI (UEFI)
- BIOS/Legacy

### Filesystems
- ext4
- btrfs (with compression support)
- zfs
- xfs
- vfat (EFI System Partition)

### Encryption
- LUKS1 and LUKS2
- Keyfile support
- Separate boot encryption

### RAID
- Software RAID (mdadm)
- RAID 0, 1, 5, 6, 10

## Installation

1. **Clone or download the installer**
2. **Install dependencies**:
   ```bash
   make install-deps
   ```
   Or manually:
   ```bash
   emerge sys-apps/dialog
   emerge sys-block/parted
   emerge sys-fs/e2fsprogs
   emerge sys-fs/btrfs-progs
   emerge sys-fs/cryptsetup
   emerge sys-fs/mdadm
   ```

3. **Run the installer**:
   ```bash
   make run
   ```
   Or directly:
   ```bash
   ./gentoo-installer.sh
   ```

## Usage

The installer provides a step-by-step guided installation:

1. **System Information**: Configure init system, boot mode, hostname, timezone, keymap
2. **Disk Configuration**: Select disks, configure partitions, setup RAID
3. **Filesystem Setup**: Choose filesystem types and mount options
4. **Encryption**: Configure LUKS encryption for partitions
5. **Gentoo Installation**: Stage tarball, Portage, kernel, network configuration
6. **System Configuration**: Users, services, locales, bootloader
7. **Review & Execute**: Review configuration and start installation

## Module Structure

