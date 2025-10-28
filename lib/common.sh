#!/usr/bin/env bash
# Common utilities and logging

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${CYAN}[✓]${NC} $*"; }
log_header() { echo -e "\n${BOLD}═══ $* ═══${NC}\n"; }

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Must run as root"
    exit 1
  fi
}

check_dependencies() {
  log_header "Checking Dependencies"
  
  local missing=0
  local deps=(
    "dialog:Required for text-based user interface"
    "parted:Disk partitioning tool"
    "curl:Downloading stage3 and other files"
    "wget:Alternative download tool"
    "tar:Extracting stage3 archive"
    "lsblk:Listing block devices"
    "blkid:Getting partition UUIDs"
  )
  
  for dep_info in "${deps[@]}"; do
    local dep="${dep_info%%:*}"
    local desc="${dep_info#*:}"
    
    if command -v "$dep" &>/dev/null; then
      log_success "Found: $dep - $desc"
    else
      log_error "Missing: $dep"
      log_error "  Purpose: $desc"
      missing=1
    fi
  done

  if [ $missing -eq 1 ]; then
    show_error "Critical dependencies are missing!"
    echo
    echo "Please install the missing packages using your package manager:"
    echo
    echo "For Gentoo:"
    echo "  emerge -av dialog parted curl wget tar util-linux"
    echo
    echo "For Ubuntu/Debian:"
    echo "  apt install dialog parted curl wget tar util-linux"
    echo
    echo "For CentOS/RHEL/Fedora:"
    echo "  yum install dialog parted curl wget tar util-linux"
    echo "  or"
    echo "  dnf install dialog parted curl wget tar util-linux"
    echo
    exit 1
  fi

  log_success "All dependencies are available"
  echo
}

check_internet() {
  log_info "Checking internet connectivity..."
  if ping -c 1 -W 2 gentoo.org &>/dev/null; then
    log_success "Internet connection is available"
    return 0
  else
    log_error "No internet connection detected"
    show_error "Internet connection is required for downloading stage3 and packages"
    echo
    echo "Please ensure you have a working internet connection and try again."
    echo "You can check your connection with: ping -c 3 gentoo.org"
    echo
    return 1
  fi
}

check_optional_deps() {
  log_info "Checking optional dependencies..."
  local optional_deps=(
    "cryptsetup:LUKS encryption support"
    "btrfs-progs:Btrfs filesystem support"
    "zfs:ZFS filesystem support"
    "mdadm:Software RAID support"
  )
  
  local found_optional=0
  for dep_info in "${optional_deps[@]}"; do
    local dep="${dep_info%%:*}"
    local desc="${dep_info#*:}"
    
    if command -v "$dep" &>/dev/null; then
      log_success "Optional: $dep - $desc"
      found_optional=1
    else
      log_info "Missing optional: $dep - $desc"
    fi
  done
  
  if [ $found_optional -eq 1 ]; then
    log_success "Some optional features are available"
  else
    log_info "No optional dependencies found - some features will be unavailable"
  fi
  echo
}

get_cpu_cores() { 
    if command -v nproc &>/dev/null; then
        nproc
    else
        grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1"
    fi
}

get_memory_gb() { 
    if [[ -r /proc/meminfo ]]; then
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo $(( (mem_kb + 1024*1024 - 1) / (1024*1024) ))
    else
        echo "4"  # Default to 4GB if we can't determine
    fi
}

get_uuid() { 
    if command -v blkid &>/dev/null; then
        blkid -s UUID -o value "$1" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

show_banner() {
  clear
  cat <<"EOF"
╔══════════════════════════════════════════════════════════════╗
║   ██████╗ ███████╗███╗   ██╗████████╗ ██████╗  ██████╗     ║
║  ██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔═══██╗    ║
║  ██║  ███╗█████╗  ██╔██╗ ██║   ██║   ██║   ██║██║   ██║    ║
║  ██║   ██║██║     ██║╚██╗██║   ██║   ██║   ██║██║   ██║    ║
║  ╚██████╔╝███████╗██║ ╚████║   ██║   ╚██████╔╝╚██████╔╝    ║
║          Modular Installer v2.0 - Mujahid Siyam            ║
╚══════════════════════════════════════════════════════════════╝
EOF
  sleep 1
}
