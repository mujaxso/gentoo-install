.PHONY: all install clean check-deps

# Gentoo Installer Makefile

# Install dependencies
install-deps:
	@echo "Installing required dependencies..."
	emerge sys-apps/dialog
	emerge sys-block/parted
	emerge sys-fs/e2fsprogs
	emerge sys-fs/btrfs-progs
	emerge sys-fs/cryptsetup
	emerge sys-fs/mdadm
	emerge sys-fs/zfs-kmod
	@echo "Dependencies installed successfully."

# Check dependencies
check-deps:
	@echo "Checking dependencies..."
	@command -v dialog >/dev/null 2>&1 || (echo "ERROR: dialog is not installed" && exit 1)
	@command -v parted >/dev/null 2>&1 || (echo "WARNING: parted is not installed" || true)
	@command -v mkfs.ext4 >/dev/null 2>&1 || (echo "WARNING: e2fsprogs is not installed" || true)
	@command -v mkfs.btrfs >/dev/null 2>&1 || (echo "WARNING: btrfs-progs is not installed" || true)
	@command -v cryptsetup >/dev/null 2>&1 || (echo "WARNING: cryptsetup is not installed" || true)
	@command -v mdadm >/dev/null 2>&1 || (echo "WARNING: mdadm is not installed" || true)
	@command -v zfs >/dev/null 2>&1 || (echo "WARNING: zfs is not installed" || true)
	@echo "Dependency check completed."

# Make installer executable
make-executable:
	@chmod +x gentoo-installer.sh
	@chmod +x modules/*.sh
	@echo "Made installer executable."

# Create directories
setup:
	@mkdir -p modules
	@echo "Setup completed."

# Run installer
run: check-deps make-executable
	@./gentoo-installer.sh

# Default target
all: setup make-executable install-deps
	@echo "Gentoo installer setup completed!"
	@echo "Run with: ./gentoo-installer.sh"

# Clean
clean:
	@rm -rf modules/*.sh
	@rm -f gentoo-installer.sh
	@rm -f /tmp/gentoo-*-config
	@rm -f /tmp/gentoo-fstab
	@echo "Clean completed."
