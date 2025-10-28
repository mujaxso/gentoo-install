# Gentoo Linux Advanced Installer v2.0

**Author:** Mujahid Siyam  
**License:** MIT  
**Status:** Production Ready

A comprehensive, modular installer for Gentoo Linux featuring an intuitive TUI interface that simplifies the complex installation process while maintaining Gentoo's flexibility and customization capabilities.

## 🚀 Features

### Core Capabilities
- **Dual Init System Support**: Full support for both OpenRC and systemd
- **Boot Mode Flexibility**: EFI/UEFI and legacy BIOS compatibility
- **Advanced Filesystems**: ext4, Btrfs (with subvolumes), and ZFS support
- **Security Features**: LUKS disk encryption with interactive setup
- **Storage Options**: Software RAID (mdraid) configuration
- **Modular Architecture**: Extensible design for easy customization

### User Experience
- **Interactive TUI**: User-friendly dialog/whiptail interface
- **Step-by-Step Guidance**: Clear progression through installation stages
- **Validation & Error Handling**: Comprehensive checks and helpful error messages
- **Progress Indicators**: Real-time feedback on installation steps

### Cross-Platform Compatibility
- **Multi-Distro Support**: Dependency installation guides for:
  - Gentoo Linux
  - Ubuntu/Debian
  - CentOS/RHEL/Fedora
  - Arch Linux

## 📋 Prerequisites

### System Requirements
- **Architecture**: x86_64 (amd64)
- **RAM**: Minimum 2GB (4GB+ recommended)
- **Storage**: 20GB+ available disk space
- **Internet**: Active connection for stage3 download and package installation

### Required Tools
Ensure you have the following tools available in your live environment:
- `dialog` or `whiptail` for TUI interface
- `parted` for disk partitioning
- `curl` or `wget` for downloads
- `tar` for archive extraction
- `lsblk` and `blkid` for disk operations

## 🛠️ Installation Guide

### Quick Start
```bash
# Clone or download the installer
git clone <repository-url>
cd gentoo-installer-v2

# Make all scripts executable
chmod +x install.sh lib/*.sh modules/**/*.sh

# Run the installer
./install.sh
```

### Step-by-Step Process

1. **System Preparation**
   - Boot from Gentoo LiveCD/USB
   - Ensure internet connectivity
   - Verify system meets requirements

2. **Dependency Check**
   - Automatic validation of required tools
   - Installation guidance for missing dependencies
   - Optional feature availability check

3. **System Configuration**
   - Choose init system (OpenRC/systemd)
   - Select boot mode (EFI/BIOS)
   - Configure hostname, username, and timezone

4. **Disk Configuration**
   - Select target disk (automatically excludes system disk)
   - Choose filesystem (ext4, Btrfs, ZFS)
   - Optional LUKS encryption setup
   - Automated partitioning with optimal layouts

5. **Base System Installation**
   - Automatic stage3 download and verification
   - Filesystem formatting and mounting
   - make.conf optimization for your hardware
   - fstab generation with proper UUIDs

6. **System Configuration (Chroot)**
   - Portage tree synchronization
   - Profile selection
   - Locale and timezone configuration
   - Kernel and essential package installation
   - User account creation and password setup

7. **Bootloader Installation**
   - GRUB configuration for selected boot mode
   - EFI: GRUB installation with proper EFI directory
   - BIOS: GRUB installation with BIOS boot partition

8. **Finalization**
   - Filesystem unmounting
   - Clean shutdown/reboot preparation
   - Optional immediate reboot

## 🏗️ Project Structure

```
gentoo-installer-v2/
├── install.sh                 # Main installer entry point
├── README.md                  # This documentation
├── lib/                       # Core libraries
│   ├── common.sh             # Utilities, logging, dependency checks
│   ├── ui.sh                 # TUI interface (dialog/whiptail)
│   ├── disk.sh               # Disk partitioning and management
│   ├── filesystem.sh         # Filesystem operations and fstab
│   ├── stage3.sh             # Stage3 download and extraction
│   ├── chroot.sh             # Chroot environment setup
│   ├── config.sh             # Configuration management
│   ├── network.sh            # Network utilities
│   └── bootloader.sh         # Bootloader wrapper
├── modules/                   # Modular components
│   ├── init/
│   │   ├── openrc.sh         # OpenRC configuration
│   │   └── systemd.sh        # systemd configuration
│   ├── boot/
│   │   ├── efi.sh            # EFI bootloader installation
│   │   └── bios.sh           # BIOS bootloader installation
│   └── fs/
│       ├── ext4.sh           # ext4 filesystem support
│       ├── btrfs.sh          # Btrfs with subvolumes
│       ├── zfs.sh            # ZFS pool and dataset creation
│       ├── luks.sh           # LUKS encryption setup
│       └── mdraid.sh         # Software RAID configuration
├── config/
│   └── default.conf          # Default configuration values
└── templates/                 # File templates (expandable)
```

## 🔧 Customization

### Configuration Files
Edit `config/default.conf` to set default values:
```bash
# Default system configuration
DEFAULT_HOSTNAME="gentoo"
DEFAULT_USERNAME="user"
DEFAULT_TIMEZONE="UTC"
GENTOO_MIRROR="https://distfiles.gentoo.org"
```

### Adding Modules
Extend functionality by creating new modules in the appropriate subdirectories:
```bash
# Example: Adding a new filesystem module
modules/fs/xfs.sh
```

### Modifying Installation Steps
Edit the corresponding library files in `lib/` to customize installation logic while maintaining the modular architecture.

## 🐛 Troubleshooting

### Common Issues

**Dependency Errors**
```bash
# On Gentoo
emerge -av dialog parted curl wget tar util-linux

# On Arch Linux  
pacman -S dialog parted curl wget tar util-linux

# On Ubuntu/Debian
apt install dialog parted curl wget tar util-linux
```

**Disk Partitioning Issues**
- Ensure target disk is not mounted or in use
- Verify disk is not the system disk
- Check for existing partitions that may interfere

**Network Connectivity**
- Verify internet connection before starting
- Check DNS resolution with `ping gentoo.org`
- Ensure network services are running in live environment

**Installation Interruption**
- The installer maintains state between sessions
- Resume from the last completed step
- Check logs for specific error messages

### Debug Mode
Enable debug output by uncommenting `set -x` in `install.sh`:
```bash
# Enable debug mode for troubleshooting
set -x
```

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards
- Follow existing bash scripting conventions
- Include proper error handling
- Maintain modular architecture
- Update documentation for new features

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Gentoo Linux community for documentation and support
- Contributors to the original installation handbook
- Testers and bug reporters who helped improve the installer

---

**Note**: This installer is designed to simplify the Gentoo installation process while maintaining the distribution's philosophy of user control and customization. Always review the automated choices and understand the changes being made to your system.
