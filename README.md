# Gentoo Linux Installer - AMD64 Handbook Compatible

A comprehensive modular interactive shell script installer for Gentoo Linux with TUI interface, fully compatible with the latest AMD64 Handbook installation methods.

## Features

- **AMD64 Handbook Compliant**: Follows the latest installation procedures
- **Complete Installation**: Full Gentoo installation from stage 3 to bootable system
- **TUI Interface**: User-friendly text-based interface using `dialog`
- **Multiple Init Systems**: Support for OpenRC and systemd
- **Boot Support**: Both EFI and BIOS/Legacy boot modes
- **Modern Filesystems**: XFS (recommended), ext4, btrfs, zfs, f2fs
- **Encryption**: LUKS encryption for root and boot partitions
- **RAID Support**: Software RAID (mdadm) configuration
- **Binary Package Host**: Support for Gentoo's official binary packages
- **Distribution Kernels**: Automated kernel management
- **Secure Boot**: Optional Secure Boot support with key management
- **Modular Design**: Separate modules for different installation aspects

## AMD64 Handbook Compatibility

This installer follows the official AMD64 Handbook methods:

### Latest Installation Process

1. **System Information & Profile Selection**
   - Modern profile-based system configuration
   - Desktop, hardened, and no-multilib profiles
   - Init system selection (OpenRC/systemd)

2. **Disk Configuration**
   - fdisk partitioning (GPT for UEFI, MBR for BIOS)
   - Recommended partition sizes (1GB ESP, etc.)
   - Proper partition table creation

3. **Filesystem Setup**
   - XFS as recommended filesystem
   - Proper ESP formatting for UEFI
   - Modern mount options

4. **Stage File Selection**
   - Proper stage3 naming with init system suffixes
   - Download verification with checksums
   - Optimized make.conf configuration

5. **Portage Configuration**
   - Profile-based configuration
   - USE flags optimization
   - Binary package host support
   - Modern licensing policies

6. **Kernel Setup**
   - Distribution kernels (recommended)
   - Optional manual configuration
   - Linux firmware installation
   - Microcode updates

7. **Modern Bootloaders**
   - GRUB2 with UEFI/BIOS support
   - systemd-boot for systemd systems
   - EFI stub support
   - Secure Boot integration

## Supported Configurations

### Init Systems
- **OpenRC** (Gentoo default)
- **systemd** (full integration)

### Boot Modes
- **EFI** (UEFI) with GPT partitioning
- **BIOS/Legacy** with MBR partitioning

### Stage Tarballs (Updated Naming)
- stage3-amd64-openrc (recommended)
- stage3-amd64-systemd
- stage3-amd64-*-desktop (desktop optimized)
- stage3-amd64-no-multilib (pure 64-bit)
- stage3-amd64-hardened (security focused)
- stage3-amd64-musl (alternative libc)

### Profiles
- default/linux/amd64/23.0 (base)
- default/linux/amd64/23.0/desktop (desktop optimized)
- default/linux/amd64/23.0/desktop/gnome
- default/linux/amd64/23.0/desktop/kde
- default/linux/amd64/23.0/no-multilib (pure 64-bit)
- default/linux/amd64/23.0/hardened (security focused)

### Kernel Options
- **Distribution Kernel** (recommended - automated)
- **Manual Configuration** (advanced users)
- **EFI Stub** (minimal, UEFI only)
- **Genkernel** (deprecated, not recommended)

### Filesystems
- **XFS** (recommended - all-purpose, all-platform)
- **ext4** (reliable, all-purpose)
- **btrfs** (advanced features, snapshots, compression)
- **zfs** (next-generation, built-in RAID)
- **f2fs** (flash-friendly for SSD/USB)
- **vfat** (EFI System Partition)

### Binary Package Host
- Official Gentoo binary packages
- Significantly faster installations
- Cryptographically signed packages
- Automatic fallback to source compilation

### Advanced Features
- **Secure Boot** support with key management
- **Firmware** installation (WiFi, GPU, etc.)
- **Microcode** updates for Intel/AMD CPUs
- **Modern bootloaders** with full UEFI support

## Installation

### Prerequisites
- Gentoo Linux boot media
- Root access
- Internet connection
- x86-64 architecture
- Minimum 2GB RAM, 8GB disk space
- UEFI or BIOS support

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone <repository>
   cd gentoo-installer
   ```

2. **Install dependencies**
   ```bash
   make install-deps
   ```
   
   Manual installation:
   ```bash
   emerge sys-apps/dialog
   emerge sys-block/fdisk
   emerge sys-fs/xfsprogs
   emerge sys-fs/e2fsprogs
   emerge sys-fs/btrfs-progs
   emerge sys-fs/cryptsetup
   emerge sys-fs/mdadm
   emerge net-misc/wget
   emerge app-crypt/gnupg
   ```

3. **Run the installer**
   ```bash
   make run
   ```
   
   Or directly:
   ```bash
   ./gentoo-installer.sh
   ```

## Installation Steps

### 1. System Information & Profile Selection
- Choose init system (OpenRC/systemd)
- Select boot mode (EFI/BIOS)
- Pick appropriate system profile
- Configure hostname, timezone, keymap
- Optional: Enable binary package host

### 2. Disk Configuration
- Select boot and root devices
- Choose partition table (GPT/MBR)
- Configure partition sizes
- Partition with fdisk (following handbook)
- Format with recommended filesystems

### 3. Filesystem Setup
- Root: XFS (recommended by handbook)
- Boot: vfat (UEFI) or xfs (BIOS)
- Configure mount options
- Set up separate partitions if desired

### 4. Stage File Selection
- Choose appropriate stage3 tarball
- Set up mirror selection
- Configure date/time (critical for HTTPS)
- Download and verify stage file
- Extract to /mnt/gentoo
- Configure optimized make.conf

### 5. Portage Configuration
- Install Gentoo ebuild repository
- Select system profile
- Configure mirrors
- Sync Portage tree
- Set up USE flags and licenses
- Optional: Configure binary package host

### 6. Kernel Setup
- Install Linux firmware (recommended)
- Choose kernel method:
  - Distribution kernel (automated, recommended)
  - Manual configuration (advanced)
- Optional: Configure Secure Boot
- Set up kernel modules

### 7. System Configuration
- Set timezone and locale
- Configure networking
- Create users and set passwords
- Set up system services
- Configure final system settings

### 8. Bootloader Installation
- GRUB2 (default, UEFI/BIOS support)
- systemd-boot (systemd systems)
- EFI Stub (minimal approach)
- Configure bootloader options

### 9. Finalization
- Generate fstab
- Enable services
- Perform system cleanup
- Complete installation

## Module Structure

