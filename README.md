# Gentoo Linux Installer

A comprehensive modular interactive shell script installer for Gentoo Linux with TUI interface.

## Features

- **Complete Installation**: Full Gentoo installation from stage 3 to bootable system
- **TUI Interface**: User-friendly text-based interface using `dialog`
- **Multiple Init Systems**: Support for OpenRC and systemd
- **Boot Support**: Both EFI and BIOS/Legacy boot modes
- **Filesystem Support**: ext4, btrfs, zfs, and xfs
- **Encryption**: LUKS encryption for root and boot partitions
- **RAID Support**: Software RAID (mdadm) configuration
- **Modular Design**: Separate modules for different installation aspects

## Complete Installation Process

### 1. System Information
- Init system selection (OpenRC/systemd)
- Boot mode (EFI/BIOS)
- Hostname, timezone, keymap configuration

### 2. Disk Configuration
- Disk selection and partitioning
- Partition size configuration
- Software RAID setup

### 3. Filesystem Setup
- Root, boot, home, var filesystem selection
- Separate partition configuration
- Mount options

### 4. Encryption (LUKS)
- Root and boot partition encryption
- LUKS1/LUKS2 version selection
- Keyfile support

### 5. Gentoo Installation
- Stage 3 tarball download and extraction
- Portage tree synchronization
- Kernel compilation (genkernel/custom/distribution)
- Network configuration

### 6. System Configuration
- User and password setup
- Service configuration (SSH, NetworkManager, etc.)
- Locale and timezone settings
- Bootloader installation and configuration
- Security settings (firewall, fail2ban)

### 7. Final System Setup
- Automatic service enablement
- System finalization and cleanup
- Installation verification

## Supported Configurations

### Init Systems
- **OpenRC** (Gentoo default)
- **systemd** (full integration)

### Boot Modes
- **EFI** (UEFI) with GRUB2, systemd-boot, rEFInd
- **BIOS/Legacy** with GRUB2

### Stage Tarballs
- stage3-amd64 (recommended)
- stage3-amd64-hardened
- stage3-amd64-nomultilib
- stage3-amd64-musl
- Custom stage tarball URLs

### Kernel Options
- **genkernel** (beginner-friendly, automated)
- **genkernel-next** (modern genkernel)
- **Custom kernel compilation** (manual configuration)
- **Distribution kernel** (pre-compiled)
- **Kernel sources only** (user compiles manually)

### Filesystems
- **ext4** (stable, feature-rich)
- **btrfs** (copy-on-write, snapshots, compression)
- **zfs** (advanced filesystem, built-in RAID)
- **xfs** (high-performance, large files)
- **vfat** (EFI System Partition)

### Encryption
- **LUKS1** (legacy compatibility)
- **LUKS2** (modern, recommended)
- Root partition encryption
- Boot partition encryption
- Keyfile support for automated unlocking

### RAID
- **Software RAID** (mdadm)
- RAID 0, 1, 5, 6, 10 support
- Automatic RAID configuration
- RAID monitoring

## Installation

### Prerequisites
- Gentoo Linux boot media
- Root access
- Internet connection
- Minimum 20GB disk space
- Minimum 2GB RAM (4GB+ recommended for compilation)

### Setup Steps

1. **Download and prepare installer**
   ```bash
   git clone <repository>
   cd gentoo-installer
   ```

2. **Install dependencies**
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
   emerge net-misc/wget
   ```

3. **Run the installer**
   ```bash
   make run
   ```
   
   Or directly:
   ```bash
   ./gentoo-installer.sh
   ```

## Usage Guide

### Step-by-Step Installation

1. **Welcome Screen**
   - Review installer capabilities
   - Confirm system requirements

2. **System Information**
   - Choose init system (OpenRC/systemd)
   - Select boot mode (EFI/BIOS)
   - Set hostname, timezone, keymap

3. **Disk Configuration**
   - Select boot and root devices
   - Configure partition sizes
   - Set up RAID if needed

4. **Filesystem Setup**
   - Choose filesystem for each partition
   - Configure separate partitions (/home, /var)
   - Set mount options

5. **Encryption Configuration**
   - Enable LUKS encryption for root/boot
   - Configure encryption options
   - Test encryption setup

6. **Gentoo Installation**
   - Select stage tarball type
   - Choose kernel compilation method
   - Configure Portage synchronization
   - Set up network configuration

7. **System Configuration**
   - Create users and set passwords
   - Configure services (SSH, NetworkManager, etc.)
   - Set locale and timezone
   - Choose bootloader

8. **Review and Execute**
   - Review all configuration choices
   - Confirm installation
   - Begin automated installation process

### Installation Progress

The installer provides real-time progress feedback:
- Environment preparation (10%)
- Stage 3 download and extraction (20-30%)
- Portage configuration (30-50%)
- Kernel compilation (50-70%)
- System configuration (70-80%)
- Bootloader installation (80-90%)
- Finalization (90-100%)

## Module Structure

