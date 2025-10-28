#!/usr/bin/env bash
################################################################################
# GENTOO INSTALLER DEBUG UTILITY
# Author: Mujahid Siyam
# Purpose: Validate repository structure and diagnose installation issues
################################################################################

# Color codes for better visibility
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script metadata
readonly SCRIPT_VERSION="1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly MODULE_DIR="${SCRIPT_DIR}/modules"

# Counters
ERRORS=0
WARNINGS=0
PASSED=0

# Print functions
print_header() {
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

print_section() {
  echo ""
  echo -e "${BLUE}▶ $1${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
  ((PASSED++))
}

print_error() {
  echo -e "${RED}✗${NC} $1"
  ((ERRORS++))
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
  ((WARNINGS++))
}

print_info() {
  echo -e "  ${CYAN}ℹ${NC} $1"
}

# Check functions
check_file() {
  local file="$1"
  local description="$2"

  if [[ -f "$file" ]]; then
    print_success "$description exists"
    return 0
  else
    print_error "$description MISSING"
    print_info "Expected location: $file"
    return 1
  fi
}

check_directory() {
  local dir="$1"
  local description="$2"

  if [[ -d "$dir" ]]; then
    print_success "$description exists"
    return 0
  else
    print_error "$description MISSING"
    print_info "Expected location: $dir"
    return 1
  fi
}

check_executable() {
  local file="$1"
  local description="$2"

  if [[ -x "$file" ]]; then
    print_success "$description is executable"
    return 0
  else
    print_warning "$description is NOT executable"
    print_info "Run: chmod +x $file"
    return 1
  fi
}

check_bash_syntax() {
  local file="$1"
  local filename="$(basename "$file")"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  if bash -n "$file" 2>/dev/null; then
    print_success "$filename has valid syntax"
    return 0
  else
    print_error "$filename has SYNTAX ERRORS"
    print_info "Run: bash -n $file"
    return 1
  fi
}

analyze_file_content() {
  local file="$1"
  local filename="$(basename "$file")"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # Check if file has shebang
  if head -n 1 "$file" | grep -q '^#!'; then
    print_info "$filename has shebang: $(head -n 1 "$file")"
  fi

  # Count lines
  local lines=$(wc -l <"$file")
  print_info "$filename: $lines lines"

  # Check for common functions
  if grep -q "^function\|^[a-zA-Z_][a-zA-Z0-9_]*\s*()\s*{" "$file"; then
    local func_count=$(grep -c "^function\|^[a-zA-Z_][a-zA-Z0-9_]*\s*()\s*{" "$file")
    print_info "$filename: $func_count function(s) defined"
  fi
}

check_system_dependencies() {
  print_section "System Dependencies"

  local deps=(
    "bash:Bash Shell"
    "dialog:Dialog (TUI)"
    "wget:wget or curl:curl"
    "parted:Parted"
    "mkfs.ext4:ext4 tools:e2fsprogs"
    "cryptsetup:LUKS encryption:cryptsetup"
  )

  for dep_info in "${deps[@]}"; do
    IFS=':' read -r cmd description package <<<"$dep_info"

    if command -v "$cmd" &>/dev/null; then
      print_success "$description installed ($(command -v "$cmd"))"
    else
      print_warning "$description NOT installed"
      [[ -n "$package" ]] && print_info "Install with: apt/dnf/pacman install $package"
    fi
  done

  # Check if running as root
  echo ""
  if [[ $EUID -eq 0 ]]; then
    print_success "Running as root (required for installation)"
  else
    print_warning "NOT running as root (required for actual installation)"
    print_info "Run installer with: sudo ./install.sh"
  fi
}

# Main validation functions
validate_directory_structure() {
  print_section "Directory Structure"

  print_info "Root directory: $SCRIPT_DIR"

  check_directory "$LIB_DIR" "Library directory (lib/)"
  check_directory "$MODULE_DIR" "Modules directory (modules/)"
  check_directory "$MODULE_DIR/fs" "Filesystem modules (modules/fs/)"
  check_directory "$MODULE_DIR/boot" "Boot modules (modules/boot/)"
}

validate_lib_files() {
  print_section "Library Files"

  local lib_files=(
    "common.sh:Common utilities"
    "ui.sh:User interface"
    "disk.sh:Disk operations"
    "filesystem.sh:Filesystem operations"
    "config.sh:Configuration"
    "network.sh:Network utilities"
    "stage3.sh:Stage3 handling"
    "chroot.sh:Chroot utilities"
    "bootloader.sh:Bootloader installation"
  )

  for lib_info in "${lib_files[@]}"; do
    IFS=':' read -r filename description <<<"$lib_info"
    local filepath="${LIB_DIR}/${filename}"

    if check_file "$filepath" "$description (lib/$filename)"; then
      analyze_file_content "$filepath"
      check_bash_syntax "$filepath"
    fi
  done
}

validate_module_files() {
  print_section "Module Files"

  local module_files=(
    "fs/luks.sh:LUKS encryption module"
    "boot/efi.sh:EFI bootloader module"
    "boot/bios.sh:BIOS bootloader module"
  )

  for module_info in "${module_files[@]}"; do
    IFS=':' read -r filename description <<<"$module_info"
    local filepath="${MODULE_DIR}/${filename}"

    if check_file "$filepath" "$description (modules/$filename)"; then
      analyze_file_content "$filepath"
      check_bash_syntax "$filepath"
    fi
  done
}

validate_main_script() {
  print_section "Main Installation Script"

  local main_script="${SCRIPT_DIR}/install.sh"

  if check_file "$main_script" "Main script (install.sh)"; then
    check_executable "$main_script" "install.sh"
    analyze_file_content "$main_script"
    check_bash_syntax "$main_script"

    # Check for required sections
    echo ""
    print_info "Checking main script structure..."

    if grep -q "main()" "$main_script"; then
      print_success "main() function found"
    else
      print_error "main() function NOT found"
    fi

    if grep -q "main_menu()" "$main_script"; then
      print_success "main_menu() function found"
    else
      print_error "main_menu() function NOT found"
    fi

    if grep -q 'source.*common.sh' "$main_script"; then
      print_success "Sources common.sh"
    else
      print_error "Does NOT source common.sh"
    fi
  fi
}

test_sourcing() {
  print_section "Source File Test"

  print_info "Testing if library files can be sourced..."

  # Create temporary test script
  local test_script=$(mktemp)

  cat >"$test_script" <<'EOFTEST'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

test_source() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "MISSING: $file"
        return 1
    fi
    
    if source "$file" 2>/dev/null; then
        echo "OK: $file"
        return 0
    else
        echo "ERROR: $file"
        return 1
    fi
}

for lib in common ui disk filesystem config network stage3 chroot bootloader; do
    test_source "${LIB_DIR}/${lib}.sh"
done
EOFTEST

  chmod +x "$test_script"

  # Run test in subshell
  if bash "$test_script" 2>&1 | while read -r line; do
    if [[ "$line" == OK:* ]]; then
      print_success "Can source ${line#OK: }"
    elif [[ "$line" == MISSING:* ]]; then
      print_error "Missing ${line#MISSING: }"
    elif [[ "$line" == ERROR:* ]]; then
      print_error "Cannot source ${line#ERROR: } (syntax error or dependency issue)"
    fi
  done; then
    :
  fi

  rm -f "$test_script"
}

check_git_repository() {
  print_section "Git Repository"

  if [[ -d "${SCRIPT_DIR}/.git" ]]; then
    print_success "Git repository detected"

    if command -v git &>/dev/null; then
      local branch=$(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null)
      local commit=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null)
      local status=$(git -C "$SCRIPT_DIR" status --porcelain 2>/dev/null | wc -l)

      print_info "Branch: ${branch:-unknown}"
      print_info "Commit: ${commit:-unknown}"

      if [[ $status -gt 0 ]]; then
        print_warning "$status uncommitted change(s)"
      else
        print_success "Working directory clean"
      fi
    fi
  else
    print_warning "Not a git repository"
    print_info "Run: git init && git add . && git commit -m 'Initial commit'"
  fi
}

generate_fix_script() {
  print_section "Generating Fix Script"

  local fix_script="${SCRIPT_DIR}/fix_issues.sh"

  cat >"$fix_script" <<'EOFFIX'
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
EOFFIX

  chmod +x "$fix_script"
  print_success "Created fix script: fix_issues.sh"
  print_info "Run: ./fix_issues.sh"
}

print_summary() {
  echo ""
  print_header "VALIDATION SUMMARY"

  echo -e "${GREEN}Passed:${NC}   $PASSED"
  echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
  echo -e "${RED}Errors:${NC}   $ERRORS"

  echo ""

  if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo -e "${GREEN}  Your installer should be ready to run.${NC}"
    echo ""
    echo -e "${CYAN}To run the installer:${NC}"
    echo -e "  sudo ./install.sh"
    echo ""
    echo -e "${CYAN}To debug the installer:${NC}"
    echo -e "  sudo bash -x ./install.sh"
  else
    echo -e "${RED}✗ Found $ERRORS critical error(s)${NC}"
    echo -e "${RED}  Fix these issues before running the installer.${NC}"
    echo ""
    echo -e "${CYAN}Suggested actions:${NC}"
    echo -e "  1. Run: ./fix_issues.sh"
    echo -e "  2. Review missing files above"
    echo -e "  3. Check syntax errors: bash -n install.sh"
    echo -e "  4. Run debug script again: ./debug.sh"
  fi

  if [[ $WARNINGS -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}⚠ Found $WARNINGS warning(s)${NC}"
    echo -e "${YELLOW}  These may not prevent installation but should be reviewed.${NC}"
  fi
}

# Main execution
main() {
  clear
  print_header "GENTOO INSTALLER DEBUG UTILITY v${SCRIPT_VERSION}"

  print_info "Script location: $SCRIPT_DIR"
  print_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

  # Run all validation checks
  check_system_dependencies
  validate_directory_structure
  validate_lib_files
  validate_module_files
  validate_main_script
  test_sourcing
  check_git_repository

  # Generate helper script
  generate_fix_script

  # Print summary
  print_summary

  # Return exit code based on errors
  [[ $ERRORS -eq 0 ]] && exit 0 || exit 1
}

# Run main function
main "$@"
