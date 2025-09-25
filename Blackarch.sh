#!/bin/bash

# BlackArch Mirror Fix Script
# Usage: ./mirror_fix.sh

echo "=== BlackArch Mirror Fix Script ==="
echo "Fixing pacman mirror issues..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Backup current mirrorlist
print_status "Backing up current mirrorlist..."
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup.$(date +%Y%m%d_%H%M%S)

# Create new mirrorlist
print_status "Creating optimized mirrorlist..."
sudo tee /etc/pacman.d/mirrorlist > /dev/null << 'EOF'
##
## Arch Linux repository mirrorlist - Optimized
##

## Primary Reliable Mirror (Top Priority)
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch

## India
Server = https://mirror.cse.iitk.ac.in/archlinux/$repo/os/$arch
Server = https://mirrors.piconets.webwerks.in/archlinux-mirror/$repo/os/$arch

## Global Fast Mirrors
Server = https://archlinux.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = https://america.mirror.pkgbuild.com/$repo/os/$arch

## Europe
Server = https://mirror.pseudoform.org/archlinux/$repo/os/$arch
Server = https://archlinux.thaller.ws/$repo/os/$arch

## Asia Pacific
Server = https://mirror.aarnet.edu.au/pub/archlinux/$repo/os/$arch
EOF

# Update BlackArch mirrors
if [ -f "/etc/pacman.d/blackarch-mirrorlist" ]; then
    print_status "Updating BlackArch mirrorlist..."
    sudo cp /etc/pacman.d/blackarch-mirrorlist /etc/pacman.d/blackarch-mirrorlist.backup.$(date +%Y%m%d_%H%M%S)
    
    sudo tee /etc/pacman.d/blackarch-mirrorlist > /dev/null << 'EOF'
##
## BlackArch Linux repository mirrorlist
##

Server = https://mirror.rise.ph/blackarch/$repo/os/$arch
Server = https://blackarch.mirror.garr.it/blackarch/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/blackarch/$repo/os/$arch
Server = https://blackarch.mirror.wearetriple.com/$repo/os/$arch
Server = https://mirror.hackthebox.com/blackarch/$repo/os/$arch
EOF
fi

# Remove pacman lock if exists
if [ -f "/var/lib/pacman/db.lck" ]; then
    print_warning "Removing pacman lock file..."
    sudo rm /var/lib/pacman/db.lck
fi

# Update keyring
print_status "Updating keyrings..."
sudo pacman -S --noconfirm archlinux-keyring blackarch-keyring 2>/dev/null || {
    print_error "Keyring update failed, trying alternative method..."
    sudo pacman-key --init
    sudo pacman-key --populate archlinux blackarch
}

# Refresh package database
print_status "Refreshing package database..."
sudo pacman -Syy

# Test update
print_status "Testing system update..."
if sudo pacman -Syu --noconfirm; then
    print_status "✅ Mirror fix successful! System updated."
else
    print_error "❌ Update failed. Trying fallback mirror..."
    
    # Fallback to single reliable mirror
    echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist
    sudo pacman -Syy
    
    if sudo pacman -Syu --noconfirm; then
        print_status "✅ Fallback successful! System updated."
    else
        print_error "❌ All methods failed. Manual intervention required."
        exit 1
    fi
fi

print_status "Script completed successfully!"
echo -e "\n${GREEN}Next steps:${NC}"
echo "1. Run: sudo pacman -S reflector"
echo "2. Then: sudo reflector --country India --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist"
echo "3. For automatic mirror updates, add reflector to systemd timer"