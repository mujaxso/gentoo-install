.PHONY: all install clean check-deps make-executable setup

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

# Make installer and all modules executable
make-executable:
	@echo "Making all scripts executable..."
	@chmod +x gentoo-installer.sh 2>/dev/null || echo "Warning: gentoo-installer.sh not found"
	@chmod +x modules/install.sh 2>/dev/null || echo "Warning: modules/install.sh not found"
	@chmod +x modules/encryption.sh 2>/dev/null || echo "Warning: modules/encryption.sh not found"
	@chmod +x modules/disk.sh 2>/dev/null || echo "Warning: modules/disk.sh not found"
	@chmod +x modules/stage.sh 2>/dev/null || echo "Warning: modules/stage.sh not found"
	@chmod +x modules/config.sh 2>/dev/null || echo "Warning: modules/config.sh not found"
	@chmod +x modules/kernel.sh 2>/dev/null || echo "Warning: modules/kernel.sh not found"
	@chmod +x modules/portage.sh 2>/dev/null || echo "Warning: modules/portage.sh not found"
	@chmod +x modules/filesystem.sh 2>/dev/null || echo "Warning: modules/filesystem.sh not found"
	@chmod +x modules/bootloader.sh 2>/dev/null || echo "Warning: modules/bootloader.sh not found"
	@chmod +x modules/finalize.sh 2>/dev/null || echo "Warning: modules/finalize.sh not found"
	@chmod +x Makefile 2>/dev/null || echo "Warning: Makefile permission issue"
	@echo "Made all installer scripts executable."

# Make all scripts executable (alternative target)
setup-executable-permissions:
	@echo "Setting up executable permissions for all scripts..."
	@find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
	@echo "All shell scripts are now executable."
	@find . -name "Makefile" -exec chmod +x {} \; 2>/dev/null || true
	@echo "Makefile permissions updated."

# Create directories
setup:
	@mkdir -p modules
	@echo "Setup completed."

# Run installer
run: check-deps make-executable setup
	@./gentoo-installer.sh

# Default target
all: setup make-executable install-deps
	@echo "Gentoo installer setup completed!"
	@echo "Run with: ./gentoo-installer.sh"
	@echo "Or use: make run"

# Clean
clean:
	@rm -rf modules/*.sh
	@rm -f gentoo-installer.sh
	@rm -f /tmp/gentoo-*-config
	@rm -f /tmp/gentoo-fstab
	@echo "Clean completed."

# Status check
status:
	@echo "=== Gentoo Installer Status ==="
	@if [ -f gentoo-installer.sh ]; then \
		echo "Main script: EXISTS ($$(stat -c%a gentoo-installer.sh 2>/dev/null || echo 'unknown'))"; \
	else \
		echo "Main script: NOT FOUND"; \
	fi
	@echo "Modules directory: $(if [ -d modules ]; then echo "EXISTS"; else echo "NOT FOUND"; fi)"
	@echo "Module files:"
	@for module in install encryption disk stage config kernel portage filesystem bootloader finalize; do \
		if [ -f "modules/$$module.sh" ]; then \
			echo "  $$module.sh: EXISTS ($$(stat -c%a modules/$$module.sh 2>/dev/null || echo 'unknown'))"; \
		else \
			echo "  $$module.sh: NOT FOUND"; \
		fi; \
	done
	@if [ -f Makefile ]; then \
		echo "Makefile: EXISTS ($$(stat -c%a Makefile 2>/dev/null || echo 'unknown'))"; \
	else \
		echo "Makefile: NOT FOUND"; \
	fi
