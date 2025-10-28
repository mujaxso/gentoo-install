# Gentoo Linux Advanced Installer v2.0

**Author:** Mujahid Siyam

Complete modular installer for Gentoo Linux with TUI interface.

## Features
- systemd/OpenRC support
- EFI/BIOS boot
- ext4/btrfs/zfs filesystems
- LUKS encryption
- mdraid support
- Fully modular architecture

## Usage
```bash
chmod +x install.sh lib/*.sh modules/**/*.sh
./install.sh
```

## Structure
- `install.sh` - Main entry point
- `lib/` - Core libraries
- `modules/` - Modular components
- `config/` - Configuration files

All 21 files are independent and can be customized individually.
