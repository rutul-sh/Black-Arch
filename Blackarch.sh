#!/bin/bash

# Advanced Arch Linux Installation Script
# Author: AI Assistant
# Version: 2.0
# Description: Automated Arch Linux installation with advanced options

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
DISK=""
HOSTNAME=""
USERNAME=""
PASSWORD=""
ROOT_PASSWORD=""
TIMEZONE=""
LOCALE="en_US.UTF-8"
KEYMAP="us"
FILESYSTEM="ext4"
DESKTOP_ENV=""
GPU_DRIVER=""
ENCRYPTION=""
SWAP_SIZE=""
KERNEL_TYPE="linux"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Check internet connection
check_internet() {
    log "Checking internet connection..."
    if ! ping -c 1 archlinux.org &> /dev/null; then
        error "No internet connection. Please connect to the internet first."
    fi
    log "Internet connection verified"
}

# Update system clock
update_clock() {
    log "Updating system clock..."
    timedatectl set-ntp true
}

# Display available disks
show_disks() {
    echo -e "${CYAN}Available disks:${NC}"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
}

# Get user input for configuration
get_user_input() {
    echo -e "${BLUE}=== Arch Linux Advanced Installation Configuration ===${NC}"
    
    # Disk selection
    show_disks
    while true; do
        read -p "Enter the disk to install on (e.g., /dev/sda): " DISK
        if [[ -b "$DISK" ]]; then
            break
        else
            error "Invalid disk. Please enter a valid block device."
        fi
    done
    
    # Hostname
    while [[ -z "$HOSTNAME" ]]; do
        read -p "Enter hostname: " HOSTNAME
    done
    
    # Username
    while [[ -z "$USERNAME" ]]; do
        read -p "Enter username: " USERNAME
    done
    
    # User password
    while true; do
        read -s -p "Enter user password: " PASSWORD
        echo
        read -s -p "Confirm user password: " PASSWORD_CONFIRM
        echo
        if [[ "$PASSWORD" == "$PASSWORD_CONFIRM" ]]; then
            break
        else
            echo "Passwords do not match. Try again."
        fi
    done
    
    # Root password
    while true; do
        read -s -p "Enter root password: " ROOT_PASSWORD
        echo
        read -s -p "Confirm root password: " ROOT_PASSWORD_CONFIRM
        echo
        if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then
            break
        else
            echo "Passwords do not match. Try again."
        fi
    done
    
    # Timezone
    echo -e "\nAvailable timezones (showing first 20):"
    timedatectl list-timezones | head -20
    read -p "Enter timezone (e.g., America/New_York): " TIMEZONE
    
    # Kernel type
    echo -e "\nKernel options:"
    echo "1) linux (default)"
    echo "2) linux-lts"
    echo "3) linux-zen"
    echo "4) linux-hardened"
    read -p "Choose kernel [1-4]: " kernel_choice
    case $kernel_choice in
        2) KERNEL_TYPE="linux-lts" ;;
        3) KERNEL_TYPE="linux-zen" ;;
        4) KERNEL_TYPE="linux-hardened" ;;
        *) KERNEL_TYPE="linux" ;;
    esac
    
    # Desktop environment
    echo -e "\nDesktop Environment options:"
    echo "1) None (minimal installation)"
    echo "2) GNOME"
    echo "3) KDE Plasma"
    echo "4) XFCE"
    echo "5) i3wm"
    echo "6) Awesome WM"
    read -p "Choose desktop environment [1-6]: " de_choice
    case $de_choice in
        2) DESKTOP_ENV="gnome" ;;
        3) DESKTOP_ENV="kde" ;;
        4) DESKTOP_ENV="xfce" ;;
        5) DESKTOP_ENV="i3" ;;
        6) DESKTOP_ENV="awesome" ;;
        *) DESKTOP_ENV="" ;;
    esac
    
    # GPU driver
    echo -e "\nGPU Driver options:"
    echo "1) Auto-detect"
    echo "2) NVIDIA proprietary"
    echo "3) AMD open source"
    echo "4) Intel"
    echo "5) None"
    read -p "Choose GPU driver [1-5]: " gpu_choice
    case $gpu_choice in
        1) GPU_DRIVER="auto" ;;
        2) GPU_DRIVER="nvidia" ;;
        3) GPU_DRIVER="amd" ;;
        4) GPU_DRIVER="intel" ;;
        *) GPU_DRIVER="" ;;
    esac
    
    # Encryption
    read -p "Enable disk encryption? (y/N): " encrypt
    if [[ $encrypt == [Yy] ]]; then
        ENCRYPTION="yes"
    fi
    
    # Swap size
    read -p "Swap size in GB (0 for no swap): " SWAP_SIZE
    
    # Filesystem
    echo -e "\nFilesystem options:"
    echo "1) ext4 (default)"
    echo "2) btrfs"
    echo "3) xfs"
    read -p "Choose filesystem [1-3]: " fs_choice
    case $fs_choice in
        2) FILESYSTEM="btrfs" ;;
        3) FILESYSTEM="xfs" ;;
        *) FILESYSTEM="ext4" ;;
    esac
}

# Partition the disk
partition_disk() {
    log "Partitioning disk $DISK..."
    
    # Wipe disk
    wipefs -af "$DISK"
    
    if [[ "$ENCRYPTION" == "yes" ]]; then
        # UEFI with encryption
        parted -s "$DISK" mklabel gpt
        parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
        parted -s "$DISK" set 1 boot on
        parted -s "$DISK" mkpart primary 513MiB 100%
        
        # Format EFI partition
        mkfs.fat -F32 "${DISK}1"
        
        # Setup encryption
        echo -n "$ROOT_PASSWORD" | cryptsetup luksFormat "${DISK}2" -
        echo -n "$ROOT_PASSWORD" | cryptsetup open "${DISK}2" cryptroot -
        
        # Create LVM
        pvcreate /dev/mapper/cryptroot
        vgcreate vg0 /dev/mapper/cryptroot
        
        if [[ "$SWAP_SIZE" -gt 0 ]]; then
            lvcreate -L "${SWAP_SIZE}G" vg0 -n swap
            lvcreate -l 100%FREE vg0 -n root
            mkswap /dev/vg0/swap
        else
            lvcreate -l 100%FREE vg0 -n root
        fi
        
        # Format root partition
        case $FILESYSTEM in
            "btrfs")
                mkfs.btrfs /dev/vg0/root
                mount /dev/vg0/root /mnt
                btrfs subvolume create /mnt/@
                btrfs subvolume create /mnt/@home
                umount /mnt
                mount -o subvol=@ /dev/vg0/root /mnt
                mkdir /mnt/home
                mount -o subvol=@home /dev/vg0/root /mnt/home
                ;;
            "xfs")
                mkfs.xfs /dev/vg0/root
                mount /dev/vg0/root /mnt
                ;;
            *)
                mkfs.ext4 /dev/vg0/root
                mount /dev/vg0/root /mnt
                ;;
        esac
        
    else
        # UEFI without encryption
        parted -s "$DISK" mklabel gpt
        parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
        parted -s "$DISK" set 1 boot on
        
        if [[ "$SWAP_SIZE" -gt 0 ]]; then
            parted -s "$DISK" mkpart primary linux-swap 513MiB $((513 + SWAP_SIZE * 1024))MiB
            parted -s "$DISK" mkpart primary 513MiB 100%
            mkswap "${DISK}2"
            ROOT_PART="${DISK}3"
        else
            parted -s "$DISK" mkpart primary 513MiB 100%
            ROOT_PART="${DISK}2"
        fi
        
        # Format EFI partition
        mkfs.fat -F32 "${DISK}1"
        
        # Format root partition
        case $FILESYSTEM in
            "btrfs")
                mkfs.btrfs "$ROOT_PART"
                mount "$ROOT_PART" /mnt
                btrfs subvolume create /mnt/@
                btrfs subvolume create /mnt/@home
                umount /mnt
                mount -o subvol=@ "$ROOT_PART" /mnt
                mkdir /mnt/home
                mount -o subvol=@home "$ROOT_PART" /mnt/home
                ;;
            "xfs")
                mkfs.xfs "$ROOT_PART"
                mount "$ROOT_PART" /mnt
                ;;
            *)
                mkfs.ext4 "$ROOT_PART"
                mount "$ROOT_PART" /mnt
                ;;
        esac
    fi
    
    # Mount EFI partition
    mkdir -p /mnt/boot
    mount "${DISK}1" /mnt/boot
    
    # Enable swap if created
    if [[ "$SWAP_SIZE" -gt 0 ]]; then
        if [[ "$ENCRYPTION" == "yes" ]]; then
            swapon /dev/vg0/swap
        else
            swapon "${DISK}2"
        fi
    fi
}

# Install base system
install_base() {
    log "Installing base system..."
    
    # Update mirrorlist
    reflector --country US --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    
    # Install base packages
    pacstrap /mnt base base-devel $KERNEL_TYPE linux-firmware intel-ucode amd-ucode \
        networkmanager git vim nano sudo grub efibootmgr os-prober ntfs-3g
    
    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab
}

# Configure system
configure_system() {
    log "Configuring system..."
    
    # Chroot and configure
    arch-chroot /mnt /bin/bash << EOF
# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Configure locale
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOL

# Configure mkinitcpio for encryption if enabled
if [[ "$ENCRYPTION" == "yes" ]]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
    mkinitcpio -p $KERNEL_TYPE
fi

# Install and configure bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

if [[ "$ENCRYPTION" == "yes" ]]; then
    # Get UUID of encrypted partition
    CRYPT_UUID=\$(blkid -s UUID -o value ${DISK}2)
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=\$CRYPT_UUID:cryptroot root=\/dev\/vg0\/root\"/" /etc/default/grub
fi

grub-mkconfig -o /boot/grub/grub.cfg

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create user
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Enable NetworkManager
systemctl enable NetworkManager
EOF
}

# Detect and install GPU drivers
install_gpu_drivers() {
    if [[ "$GPU_DRIVER" == "auto" ]]; then
        log "Auto-detecting GPU..."
        if lspci | grep -E "NVIDIA|GeForce"; then
            GPU_DRIVER="nvidia"
        elif lspci | grep -E "Radeon|AMD"; then
            GPU_DRIVER="amd"
        elif lspci | grep -E "Intel"; then
            GPU_DRIVER="intel"
        fi
    fi
    
    case $GPU_DRIVER in
        "nvidia")
            log "Installing NVIDIA drivers..."
            arch-chroot /mnt pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
            ;;
        "amd")
            log "Installing AMD drivers..."
            arch-chroot /mnt pacman -S --noconfirm xf86-video-amdgpu mesa
            ;;
        "intel")
            log "Installing Intel drivers..."
            arch-chroot /mnt pacman -S --noconfirm xf86-video-intel mesa
            ;;
    esac
}

# Install desktop environment
install_desktop() {
    if [[ -z "$DESKTOP_ENV" ]]; then
        return
    fi
    
    log "Installing desktop environment: $DESKTOP_ENV"
    
    arch-chroot /mnt /bin/bash << EOF
case "$DESKTOP_ENV" in
    "gnome")
        pacman -S --noconfirm xorg gnome gnome-extra gdm
        systemctl enable gdm
        ;;
    "kde")
        pacman -S --noconfirm xorg plasma kde-applications sddm
        systemctl enable sddm
        ;;
    "xfce")
        pacman -S --noconfirm xorg xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
        systemctl enable lightdm
        ;;
    "i3")
        pacman -S --noconfirm xorg i3-gaps i3status i3lock dmenu rxvt-unicode lightdm lightdm-gtk-greeter
        systemctl enable lightdm
        ;;
    "awesome")
        pacman -S --noconfirm xorg awesome lightdm lightdm-gtk-greeter
        systemctl enable lightdm
        ;;
esac
EOF
}

# Install additional packages
install_additional_packages() {
    log "Installing additional packages..."
    
    arch-chroot /mnt pacman -S --noconfirm \
        firefox chromium \
        vlc gimp libreoffice-fresh \
        htop neofetch tree \
        zip unzip p7zip \
        wget curl \
        git python python-pip \
        nodejs npm \
        docker docker-compose \
        virtualbox virtualbox-host-modules-arch \
        steam lutris wine \
        discord telegram-desktop \
        code \
        alsa-utils pulseaudio pavucontrol \
        cups system-config-printer \
        bluez bluez-utils
        
    # Enable services
    arch-chroot /mnt systemctl enable bluetooth
    arch-chroot /mnt systemctl enable cups
    arch-chroot /mnt systemctl enable docker
}

# Install AUR helper (yay)
install_aur_helper() {
    log "Installing AUR helper (yay)..."
    
    arch-chroot /mnt /bin/bash << EOF
cd /home/$USERNAME
sudo -u $USERNAME git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $USERNAME makepkg -si --noconfirm
cd ..
rm -rf yay
EOF
}

# Final configuration
final_configuration() {
    log "Applying final configurations..."
    
    # Configure firewall
    arch-chroot /mnt /bin/bash << EOF
pacman -S --noconfirm ufw
ufw enable
systemctl enable ufw
EOF
    
    # Configure zsh (if user wants it)
    read -p "Install and configure zsh with oh-my-zsh? (y/N): " install_zsh
    if [[ $install_zsh == [Yy] ]]; then
        arch-chroot /mnt /bin/bash << EOF
pacman -S --noconfirm zsh
sudo -u $USERNAME sh -c "\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chsh -s /bin/zsh $USERNAME
EOF
    fi
}

# Cleanup and finish
cleanup() {
    log "Cleaning up..."
    
    # Unmount filesystems
    if [[ "$SWAP_SIZE" -gt 0 ]]; then
        swapoff -a
    fi
    
    umount -R /mnt
    
    if [[ "$ENCRYPTION" == "yes" ]]; then
        cryptsetup close cryptroot
    fi
    
    log "Installation completed successfully!"
    log "You can now reboot into your new Arch Linux system."
    log "Default user: $USERNAME"
    log "Desktop Environment: ${DESKTOP_ENV:-None}"
    
    read -p "Reboot now? (y/N): " reboot_now
    if [[ $reboot_now == [Yy] ]]; then
        reboot
    fi
}

# Main installation function
main() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                    Advanced Arch Linux Installer                     ║
    ║                         Version 2.0                                  ║
    ╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "Starting Arch Linux advanced installation..."
    
    check_root
    check_internet
    update_clock
    get_user_input
    
    echo -e "\n${YELLOW}Installation Summary:${NC}"
    echo "Disk: $DISK"
    echo "Hostname: $HOSTNAME"
    echo "Username: $USERNAME"
    echo "Timezone: $TIMEZONE"
    echo "Kernel: $KERNEL_TYPE"
    echo "Desktop: ${DESKTOP_ENV:-None}"
    echo "GPU Driver: ${GPU_DRIVER:-None}"
    echo "Encryption: ${ENCRYPTION:-No}"
    echo "Swap Size: ${SWAP_SIZE:-0}GB"
    echo "Filesystem: $FILESYSTEM"
    
    read -p "Continue with installation? (y/N): " confirm
    if [[ $confirm != [Yy] ]]; then
        log "Installation cancelled."
        exit 0
    fi
    
    partition_disk
    install_base
    configure_system
    install_gpu_drivers
    install_desktop
    install_additional_packages
    install_aur_helper
    final_configuration
    cleanup
}

# Error handling
trap 'error "An error occurred. Installation aborted."' ERR

# Run main function
main "$@"