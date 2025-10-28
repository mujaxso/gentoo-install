#!/bin/bash
# Auto-generated fix script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Fixing common issues..."

# Make install.sh executable
if [[ -f "${SCRIPT_DIR}/install.sh" ]]; then
    chmod +x "${SCRIPT_DIR}/install.sh"
    echo "✓ Made install.sh executable"
fi

# Create missing directories
mkdir -p "${SCRIPT_DIR}/lib"
mkdir -p "${SCRIPT_DIR}/modules/fs"
mkdir -p "${SCRIPT_DIR}/modules/boot"
echo "✓ Created directory structure"

# Create stub files if missing
create_stub() {
    local file="$1"
    local description="$2"
    
    if [[ ! -f "$file" ]]; then
        cat > "$file" << EOF
#!/usr/bin/env bash
# $description
# TODO: Implement functions

echo "Loading: $description"
EOF
        echo "✓ Created stub: $file"
    fi
}

create_stub "${SCRIPT_DIR}/lib/common.sh" "Common utilities"
create_stub "${SCRIPT_DIR}/lib/ui.sh" "User interface"
create_stub "${SCRIPT_DIR}/lib/disk.sh" "Disk operations"
create_stub "${SCRIPT_DIR}/lib/filesystem.sh" "Filesystem operations"
create_stub "${SCRIPT_DIR}/lib/config.sh" "Configuration"
create_stub "${SCRIPT_DIR}/lib/network.sh" "Network utilities"
create_stub "${SCRIPT_DIR}/lib/stage3.sh" "Stage3 handling"
create_stub "${SCRIPT_DIR}/lib/chroot.sh" "Chroot utilities"
create_stub "${SCRIPT_DIR}/lib/bootloader.sh" "Bootloader installation"
create_stub "${SCRIPT_DIR}/modules/fs/luks.sh" "LUKS encryption"
create_stub "${SCRIPT_DIR}/modules/boot/efi.sh" "EFI bootloader"
create_stub "${SCRIPT_DIR}/modules/boot/bios.sh" "BIOS bootloader"

echo ""
echo "Fix script completed!"
echo "Run './debug.sh' again to verify fixes"
