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

detect_distribution() {
    if [[ -f /etc/gentoo-release ]]; then
        echo "gentoo"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        if grep -qi "centos" /etc/redhat-release; then
            echo "centos"
        elif grep -qi "fedora" /etc/redhat-release; then
            echo "fedora"
        else
            echo "rhel"
        fi
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    elif [[ -f /etc/alpine-release ]]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

get_install_command() {
    local distro="$1"
    case "$distro" in
        gentoo) echo "emerge -av" ;;
        debian|ubuntu) echo "apt install -y" ;;
        centos|rhel) echo "yum install -y" ;;
        fedora) echo "dnf install -y" ;;
        arch) echo "pacman -S --noconfirm" ;;
        alpine) echo "apk add" ;;
        *) echo "" ;;
    esac
}

get_package_name() {
    local dep="$1"
    local distro="$2"
    
    # Some packages have different names across distributions
    case "$dep" in
        lsblk|blkid)
            case "$distro" in
                gentoo) echo "util-linux" ;;
                debian|ubuntu) echo "util-linux" ;;
                centos|rhel|fedora) echo "util-linux" ;;
                arch) echo "util-linux" ;;
                alpine) echo "util-linux" ;;
                *) echo "$dep" ;;
            esac
            ;;
        *)
            echo "$dep"
            ;;
    esac
}

check_dependencies() {
    log_header "Checking Dependencies"
    
    local missing_deps=()
    local critical_deps=("dialog" "parted" "curl" "wget" "tar" "lsblk" "blkid")
    
    # Check which dependencies are missing
    for dep in "${critical_deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Show status in TUI
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        show_success "All dependencies are available"
        return 0
    else
        # Show missing dependencies in TUI
        local missing_list=$(printf "%s, " "${missing_deps[@]}")
        missing_list="${missing_list%, }"
        show_error "Missing dependencies: $missing_list"
        
        # Detect distribution
        local distro=$(detect_distribution)
        local install_cmd=$(get_install_command "$distro")
        
        if [[ -n "$install_cmd" ]]; then
            # Build package list for installation
            local packages=()
            for dep in "${missing_deps[@]}"; do
                packages+=("$(get_package_name "$dep" "$distro")")
            done
            
            # Remove duplicates
            local unique_packages=($(echo "${packages[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
            
            show_info "Detected distribution: $distro"
            show_info "Install command: $install_cmd ${unique_packages[*]}"
            
            if show_yesno "Would you like to install the missing dependencies automatically?"; then
                log_info "Installing dependencies: ${unique_packages[*]}"
                
                # Execute the installation command
                if $install_cmd "${unique_packages[@]}"; then
                    log_success "Dependencies installed successfully"
                    
                    # Verify all dependencies are now available
                    local still_missing=0
                    for dep in "${missing_deps[@]}"; do
                        if ! command -v "$dep" &>/dev/null; then
                            log_error "Still missing: $dep"
                            still_missing=1
                        fi
                    done
                    
                    if [[ $still_missing -eq 0 ]]; then
                        show_success "All dependencies are now available"
                        return 0
                    else
                        show_error "Some dependencies are still missing after installation"
                        return 1
                    fi
                else
                    show_error "Failed to install dependencies"
                    return 1
                fi
            else
                show_error "Cannot continue without required dependencies"
                echo
                echo "Please install the missing packages manually:"
                echo "  $install_cmd ${unique_packages[*]}"
                echo
                return 1
            fi
        else
            show_error "Unknown distribution - cannot provide installation commands"
            echo
            echo "Please install the following packages manually:"
            printf "  %s\n" "${missing_deps[@]}"
            echo
            return 1
        fi
    fi
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
    
    local missing_optional=()
    local found_optional=0
    
    for dep_info in "${optional_deps[@]}"; do
        local dep="${dep_info%%:*}"
        local desc="${dep_info#*:}"
        
        if command -v "$dep" &>/dev/null; then
            log_success "Optional: $dep - $desc"
            found_optional=1
        else
            log_info "Missing optional: $dep - $desc"
            missing_optional+=("$dep:$desc")
        fi
    done
    
    # Show TUI message about optional dependencies
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        local missing_list=""
        for item in "${missing_optional[@]}"; do
            local dep="${item%%:*}"
            local desc="${item#*:}"
            missing_list+="• $dep: $desc\n"
        done
        
        show_info "Some optional features are unavailable:\n\n$missing_list"
        
        # Offer to install optional dependencies
        local distro=$(detect_distribution)
        local install_cmd=$(get_install_command "$distro")
        
        if [[ -n "$install_cmd" && ${#missing_optional[@]} -gt 0 ]]; then
            local optional_packages=()
            for item in "${missing_optional[@]}"; do
                local dep="${item%%:*}"
                optional_packages+=("$(get_package_name "$dep" "$distro")")
            done
            
            # Remove duplicates
            local unique_optional=($(echo "${optional_packages[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
            
            if show_yesno "Would you like to install optional dependencies for enhanced features?"; then
                log_info "Installing optional dependencies: ${unique_optional[*]}"
                if $install_cmd "${unique_optional[@]}"; then
                    show_success "Optional dependencies installed successfully"
                else
                    show_error "Failed to install some optional dependencies"
                fi
            fi
        fi
    fi
    
    if [[ $found_optional -eq 1 ]]; then
        log_success "Optional features are available"
    fi
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
