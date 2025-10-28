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
  local missing=0
  for dep in dialog parted curl wget tar lsblk blkid; do
    if ! command -v "$dep" &>/dev/null; then
      log_error "Missing: $dep"
      missing=1
    fi
  done

  if [ $missing -eq 1 ]; then
    show_error "Please install missing dependencies before continuing"
    exit 1
  fi

  log_success "Dependencies OK"
}

check_internet() {
  ping -c 1 -W 2 gentoo.org &>/dev/null
}

get_cpu_cores() { nproc; }
get_memory_gb() { free -g | awk '/^Mem:/{print $2}'; }
get_uuid() { blkid -s UUID -o value "$1" 2>/dev/null || echo ""; }

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
