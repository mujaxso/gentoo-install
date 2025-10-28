#!/usr/bin/env bash
#
# Gentoo Linux Interactive Installer with BTRFS
# Modern, modular, and stage3-compatible
# Author: Mujahid Siyam
# Version: 0.1.0
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global variables
INSTALL_DISK=""
EFI_PART=""
BOOT_PART=""
SWAP_PART=""
ROOT_PART=""
HOSTNAME=""
USERNAME=""
TIMEZONE=""
LOCALE=""
KERNEL_TYPE=""
VIDEO_DRIVER=""
CPU_CORES=""
INSTALL_DESKTOP=""
DESKTOP_ENV=""

# Logging
log() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
  echo -e "${CYAN}[SUCCESS]${NC} $*"
}

prompt() {
  echo -e "${BLUE}[?]${NC} $*"
}

# Error handler
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    error "Installation failed at step: ${BASH_COMMAND}"
    error "Exit code: $exit_code"
  fi
}

trap cleanup EXIT

# Check if running as root
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root"
    exit 1
  fi
}

# Display banner
show_banner() {
  cat <<"EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ██████╗ ███████╗███╗   ██╗████████╗ ██████╗  ██████╗    ║
║  ██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔═══██╗   ║
║  ██║  ███╗█████╗  ██╔██╗ ██║   ██║   ██║   ██║██║   ██║   ║
║  ██║   ██║██╔══╝  ██║╚██╗██║   ██║   ██║   ██║██║   ██║   ║
║  ╚██████╔╝███████╗██║ ╚████║   ██║   ╚██████╔╝╚██████╔╝   ║
║   ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝  ╚═════╝    ║
║                                                           ║
║         Interactive BTRFS Installer - Version 1.0         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
  echo
}

# Detect CPU cores
detect_cpu_cores() {
  CPU_CORES=$(nproc)
  log "Detected $CPU_CORES CPU cores"
}

# Check internet connectivity
check_internet() {
  log "Checking internet connectivity..."
  if ping -c 1 gentoo.org &>/dev/null; then
    success "Internet connection verified"
  else
    error "No internet connection. Please configure networking first."
    exit 1
  fi
}

# Disk selection
select_disk() {
  echo
  log "Available disks:"
  lsblk -d -o NAME,SIZE,TYPE | grep disk
  echo
  prompt "Enter the disk to install Gentoo (e.g., sda, nvme0n1, vda):"
  read -r disk_input
  INSTALL_DISK="/dev/${disk_input}"

  if [ ! -b "$INSTALL_DISK" ]; then
    error "Invalid disk: $INSTALL_DISK"
    exit 1
  fi

  warn "WARNING: All data on $INSTALL_DISK will be destroyed!"
  prompt "Continue? (yes/no):"
  read -r confirm
  if [ "$confirm" != "yes" ]; then
    error "Installation cancelled"
    exit 1
  fi
}

# Partition disk
partition_disk() {
  log "Partitioning disk: $INSTALL_DISK"

  # Wipe disk
  wipefs -af "$INSTALL_DISK" || true
  sgdisk -Z "$INSTALL_DISK"

  # Create GPT partition table
  parted -s "$INSTALL_DISK" mklabel gpt

  # Create partitions
  # 1. EFI partition (512MB)
  parted -s "$INSTALL_DISK" mkpart primary fat32 1MiB 513MiB
  parted -s "$INSTALL_DISK" set 1 esp on

  # 2. Boot partition (1GB)
  parted -s "$INSTALL_DISK" mkpart primary ext4 513MiB 1537MiB

  # 3. Swap partition (RAM size or 8GB)
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  local swap_size=$((ram_gb > 8 ? 8 : ram_gb))
  local swap_end=$((1537 + swap_size * 1024))
  parted -s "$INSTALL_DISK" mkpart primary linux-swap 1537MiB "${swap_end}MiB"

  # 4. Root partition (remaining space)
  parted -s "$INSTALL_DISK" mkpart primary btrfs "${swap_end}MiB" 100%

  # Set partition variables
  if [[ $INSTALL_DISK == *"nvme"* ]] || [[ $INSTALL_DISK == *"mmcblk"* ]]; then
    EFI_PART="${INSTALL_DISK}p1"
    BOOT_PART="${INSTALL_DISK}p2"
    SWAP_PART="${INSTALL_DISK}p3"
    ROOT_PART="${INSTALL_DISK}p4"
  else
    EFI_PART="${INSTALL_DISK}1"
    BOOT_PART="${INSTALL_DISK}2"
    SWAP_PART="${INSTALL_DISK}3"
    ROOT_PART="${INSTALL_DISK}4"
  fi

  # Wait for partitions to be recognized
  sleep 2
  partprobe "$INSTALL_DISK"
  sleep 2

  success "Disk partitioned successfully"
  lsblk "$INSTALL_DISK"
}

# Format partitions
format_partitions() {
  log "Formatting partitions..."

  # Format EFI partition
  log "Formatting EFI partition: $EFI_PART"
  mkfs.vfat -F32 -n EFI "$EFI_PART"

  # Format boot partition
  log "Formatting boot partition: $BOOT_PART"
  mkfs.ext4 -L BOOT "$BOOT_PART"

  # Format and activate swap
  log "Setting up swap: $SWAP_PART"
  mkswap -L SWAP "$SWAP_PART"
  swapon "$SWAP_PART"

  # Format root partition with BTRFS
  log "Formatting root partition with BTRFS: $ROOT_PART"
  mkfs.btrfs -f -L ROOT "$ROOT_PART"

  success "All partitions formatted"
}

# Create BTRFS subvolumes
create_btrfs_subvolumes() {
  log "Creating BTRFS subvolumes..."

  # Mount top-level subvolume
  mount "$ROOT_PART" /mnt

  # Create subvolumes
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@opt
  btrfs subvolume create /mnt/@srv
  btrfs subvolume create /mnt/@tmp
  btrfs subvolume create /mnt/@var
  btrfs subvolume create /mnt/@snapshots

  # List subvolumes
  log "Created subvolumes:"
  btrfs subvolume list /mnt

  # Unmount
  umount /mnt

  success "BTRFS subvolumes created"
}

# Mount filesystems
mount_filesystems() {
  log "Mounting filesystems..."

  # BTRFS mount options
  local btrfs_opts="defaults,noatime,compress=zstd:1,space_cache=v2,autodefrag"

  # Mount root subvolume
  mkdir -p /mnt/gentoo
  mount -o "${btrfs_opts},subvol=@" "$ROOT_PART" /mnt/gentoo

  # Create directories
  mkdir -p /mnt/gentoo/{boot,home,opt,srv,tmp,var,.snapshots}

  # Mount other subvolumes
  mount -o "${btrfs_opts},subvol=@home" "$ROOT_PART" /mnt/gentoo/home
  mount -o "${btrfs_opts},subvol=@opt" "$ROOT_PART" /mnt/gentoo/opt
  mount -o "${btrfs_opts},subvol=@srv" "$ROOT_PART" /mnt/gentoo/srv
  mount -o "${btrfs_opts},subvol=@tmp" "$ROOT_PART" /mnt/gentoo/tmp
  mount -o "${btrfs_opts},subvol=@var" "$ROOT_PART" /mnt/gentoo/var
  mount -o "${btrfs_opts},subvol=@snapshots" "$ROOT_PART" /mnt/gentoo/.snapshots

  # Mount boot partition
  mount "$BOOT_PART" /mnt/gentoo/boot

  # Create and mount EFI directory
  mkdir -p /mnt/gentoo/boot/efi
  mount "$EFI_PART" /mnt/gentoo/boot/efi

  success "Filesystems mounted"
}

# Download and extract stage3
install_stage3() {
  log "Downloading stage3 tarball..."

  cd /mnt/gentoo

  # Determine architecture
  local arch="amd64"
  local mirror="https://distfiles.gentoo.org/releases/${arch}/autobuilds"

  # Get latest stage3 openrc
  log "Fetching latest stage3-${arch}-openrc tarball..."
  local latest=$(curl -s "${mirror}/latest-stage3-${arch}-openrc.txt" | grep -v "^#" | awk '{print $1}')

  if [ -z "$latest" ]; then
    error "Failed to determine latest stage3 tarball"
    exit 1
  fi

  log "Downloading: $latest"
  wget -c "${mirror}/${latest}"

  # Extract tarball
  log "Extracting stage3 tarball..."
  tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

  # Clean up
  rm stage3-*.tar.xz

  success "Stage3 installed"
}

# Configure make.conf
configure_makeconf() {
  log "Configuring make.conf..."

  local jobs=$((CPU_CORES))
  local load=$((CPU_CORES))

  cat >/mnt/gentoo/etc/portage/make.conf <<EOF
# Compiler flags
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# Parallel compilation
MAKEOPTS="-j${jobs} -l${load}"
EMERGE_DEFAULT_OPTS="--jobs=${jobs} --load-average=${load} --with-bdeps=y --complete-graph=y"

# Portage features
FEATURES="candy parallel-fetch parallel-install"
PORTAGE_NICENESS="1"

# Hardware
INPUT_DEVICES="libinput"
VIDEO_CARDS="${VIDEO_DRIVER}"

# Keywords and licenses
ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"

# Bootloader
GRUB_PLATFORMS="efi-64"

# USE flags
USE="dist-kernel wayland dbus elogind pipewire screencast \
     jit lto pgo vaapi vdpau \
     pulseaudio alsa \
     networkmanager wifi bluetooth \
     -systemd -gnome -kde -xfce"

# Language
LC_MESSAGES=C.utf8
L10N="en"
EOF

  success "make.conf configured"
}

# Setup chroot environment
setup_chroot() {
  log "Setting up chroot environment..."

  # Copy DNS info
  cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

  # Mount necessary filesystems
  mount --types proc /proc /mnt/gentoo/proc
  mount --rbind /sys /mnt/gentoo/sys
  mount --make-rslave /mnt/gentoo/sys
  mount --rbind /dev /mnt/gentoo/dev
  mount --make-rslave /mnt/gentoo/dev
  mount --rbind /run /mnt/gentoo/run
  mount --make-rslave /mnt/gentoo/run

  success "Chroot environment ready"
}

# Generate chroot script
generate_chroot_script() {
  log "Generating chroot configuration script..."

  cat >/mnt/gentoo/root/install-chroot.sh <<'CHROOTEOF'
#!/bin/bash
set -euo pipefail

source /etc/profile
export PS1="(chroot) \${PS1}"

# Sync portage
echo "[INFO] Syncing Portage tree..."
emerge-webrsync
emerge --sync --quiet

# Update portage
echo "[INFO] Updating Portage..."
emerge --oneshot --quiet sys-apps/portage

# Select profile
echo "[INFO] Available profiles:"
eselect profile list
echo ""
read -p "Select profile number (default: desktop/systemd): " profile_num
if [ -n "$profile_num" ]; then
    eselect profile set "$profile_num"
fi

# Update world
echo "[INFO] Updating @world set (this may take a while)..."
emerge --ask --verbose --update --deep --newuse @world || true

# Configure timezone
echo "[INFO] Configuring timezone..."
read -p "Enter timezone (e.g., Europe/Berlin): " tz
echo "$tz" > /etc/timezone
emerge --config sys-libs/timezone-data

# Configure locales
echo "[INFO] Configuring locales..."
cat >> /etc/locale.gen << EOF
en_US.UTF-8 UTF-8
en_US ISO-8859-1
EOF
locale-gen
eselect locale list
read -p "Select locale number: " locale_num
eselect locale set "$locale_num"
env-update
source /etc/profile

# Install firmware
echo "[INFO] Installing firmware..."
mkdir -p /etc/portage
echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" >> /etc/portage/package.license
emerge --ask sys-kernel/linux-firmware

# Install kernel
echo "[INFO] Select kernel type:"
echo "1) gentoo-kernel (distribution kernel)"
echo "2) gentoo-kernel-bin (precompiled binary kernel)"
read -p "Choice [1-2]: " kernel_choice

case $kernel_choice in
    1)
        emerge --ask sys-kernel/gentoo-kernel
        ;;
    2)
        emerge --ask sys-kernel/gentoo-kernel-bin
        ;;
    *)
        echo "[WARN] Invalid choice, installing gentoo-kernel-bin"
        emerge --ask sys-kernel/gentoo-kernel-bin
        ;;
esac

# Install essential tools
echo "[INFO] Installing system tools..."
emerge --ask sys-fs/btrfs-progs sys-fs/dosfstools sys-fs/e2fsprogs
emerge --ask net-misc/dhcpcd net-misc/networkmanager
emerge --ask app-admin/sysklogd sys-process/cronie
emerge --ask sys-boot/grub sys-boot/efibootmgr

# Enable services
rc-update add sysklogd default
rc-update add cronie default
rc-update add NetworkManager default

# Configure fstab
echo "[INFO] Generating fstab..."
BOOT_UUID=$(blkid -s UUID -o value BOOT_PART_PLACEHOLDER)
EFI_UUID=$(blkid -s UUID -o value EFI_PART_PLACEHOLDER)
ROOT_UUID=$(blkid -s UUID -o value ROOT_PART_PLACEHOLDER)
SWAP_UUID=$(blkid -s UUID -o value SWAP_PART_PLACEHOLDER)

cat > /etc/fstab << FSTABEOF
# <fs>                                  <mountpoint>    <type>  <opts>                                                      <dump> <pass>
UUID=$EFI_UUID                          /boot/efi       vfat    defaults,noatime                                            0      2
UUID=$BOOT_UUID                         /boot           ext4    defaults,noatime                                            0      2
UUID=$SWAP_UUID                         none            swap    sw                                                          0      0
UUID=$ROOT_UUID                         /               btrfs   defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@   0      0
UUID=$ROOT_UUID                         /home           btrfs   defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@home 0    0
UUID=$ROOT_UUID                         /opt            btrfs   defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@opt  0    0
UUID=$ROOT_UUID                         /srv            btrfs   defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@srv  0    0
UUID=$ROOT_UUID                         /tmp            btrfs   defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@tmp  0    0
UUID=$ROOT_UUID                         /var            btrfs   defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@var  0    0
UUID=$ROOT_UUID                         /.snapshots     btrfs   defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@snapshots 0 0
FSTABEOF

# Configure hostname
read -p "Enter hostname: " hostname
echo "hostname=\"$hostname\"" > /etc/conf.d/hostname
echo "127.0.0.1 $hostname.localdomain $hostname localhost" > /etc/hosts

# Set root password
echo "[INFO] Set root password:"
passwd

# Create user
read -p "Create a new user? (yes/no): " create_user
if [ "$create_user" = "yes" ]; then
    read -p "Username: " username
    useradd -m -G users,wheel,audio,video,usb,plugdev -s /bin/bash "$username"
    echo "[INFO] Set password for $username:"
    passwd "$username"

    # Install doas
    emerge --ask app-admin/doas
    echo "permit persist :wheel" > /etc/doas.conf
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
fi

# Install and configure GRUB
echo "[INFO] Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Gentoo --removable
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo "[SUCCESS] Installation complete!"
echo "Exit the chroot and reboot your system."
CHROOTEOF

  # Make script executable
  chmod +x /mnt/gentoo/root/install-chroot.sh

  # Replace placeholders
  sed -i "s|BOOT_PART_PLACEHOLDER|${BOOT_PART}|g" /mnt/gentoo/root/install-chroot.sh
  sed -i "s|EFI_PART_PLACEHOLDER|${EFI_PART}|g" /mnt/gentoo/root/install-chroot.sh
  sed -i "s|ROOT_PART_PLACEHOLDER|${ROOT_PART}|g" /mnt/gentoo/root/install-chroot.sh
  sed -i "s|SWAP_PART_PLACEHOLDER|${SWAP_PART}|g" /mnt/gentoo/root/install-chroot.sh

  success "Chroot script generated"
}

# Get user configuration
get_user_config() {
  echo
  log "System Configuration"
  echo

  # Video driver
  prompt "Select video driver:"
  echo "1) intel"
  echo "2) amdgpu radeonsi"
  echo "3) nvidia"
  echo "4) nouveau (open-source nvidia)"
  echo "5) virtualbox"
  read -p "Choice [1-5]: " video_choice

  case $video_choice in
  1) VIDEO_DRIVER="intel" ;;
  2) VIDEO_DRIVER="amdgpu radeonsi" ;;
  3) VIDEO_DRIVER="nvidia" ;;
  4) VIDEO_DRIVER="nouveau" ;;
  5) VIDEO_DRIVER="virtualbox" ;;
  *) VIDEO_DRIVER="intel" ;;
  esac

  log "Video driver set to: $VIDEO_DRIVER"
}

# Main installation function
main() {
  show_banner
  check_root
  detect_cpu_cores
  check_internet
  get_user_config
  select_disk
  partition_disk
  format_partitions
  create_btrfs_subvolumes
  mount_filesystems
  install_stage3
  configure_makeconf
  setup_chroot
  generate_chroot_script

  echo
  success "Base installation complete!"
  echo
  log "Next steps:"
  echo "  1. Enter chroot: chroot /mnt/gentoo /bin/bash"
  echo "  2. Run: /root/install-chroot.sh"
  echo "  3. Follow the interactive prompts"
  echo "  4. Exit chroot and reboot"
  echo
  prompt "Enter chroot now? (yes/no):"
  read -r enter_chroot

  if [ "$enter_chroot" = "yes" ]; then
    log "Entering chroot environment..."
    chroot /mnt/gentoo /bin/bash -c "/root/install-chroot.sh"
  fi
}

# Run main function
main "$@"
