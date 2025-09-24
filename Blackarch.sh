#!/bin/bash

# BlackArch Tools Auto Installation Script for Kali Linux
# Author: Security Tools Installer
# Version: 1.0
# Description: Automated script to install BlackArch tools on Kali Linux

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "    BlackArch Tools Auto Installer for Kali"
    echo "=================================================="
    echo -e "${NC}"
}

# Print colored messages
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. This is not recommended for security reasons."
        echo "Press Enter to continue or Ctrl+C to exit..."
        read
    fi
}

# Check internet connectivity
check_internet() {
    print_info "Checking internet connectivity..."
    if ping -c 1 google.com &> /dev/null; then
        print_success "Internet connection is available"
        return 0
    else
        print_error "No internet connection. Please check your network."
        exit 1
    fi
}

# Check available disk space
check_disk_space() {
    print_info "Checking available disk space..."
    available_space=$(df / | awk 'NR==2 {print $4}')
    required_space=10485760 # 10GB in KB
    
    if [ "$available_space" -gt "$required_space" ]; then
        print_success "Sufficient disk space available ($(($available_space/1024/1024))GB)"
    else
        print_error "Insufficient disk space. At least 10GB required."
        exit 1
    fi
}

# Update system
update_system() {
    print_info "Updating system packages..."
    sudo apt update -y
    if [ $? -eq 0 ]; then
        print_success "System updated successfully"
    else
        print_error "Failed to update system"
        exit 1
    fi
    
    print_info "Upgrading system packages..."
    sudo apt upgrade -y
    if [ $? -eq 0 ]; then
        print_success "System upgraded successfully"
    else
        print_warning "Some packages failed to upgrade, but continuing..."
    fi
}

# Install dependencies
install_dependencies() {
    print_info "Installing required dependencies..."
    sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
}

# Setup BlackArch repository
setup_blackarch_repo() {
    print_info "Setting up BlackArch repository..."
    
    # Add BlackArch GPG key
    print_info "Adding BlackArch GPG key..."
    wget -q -O - https://blackarch.org/keyring/blackarch-keyring.pkg.tar.xz.sig | gpg --import 2>/dev/null
    curl -s https://blackarch.org/keyring/blackarch-keyring.gpg | sudo apt-key add - 2>/dev/null
    
    # Add repository to sources.list
    if ! grep -q "blackarch.org" /etc/apt/sources.list; then
        echo 'deb https://blackarch.org/blackarch/kali kali main' | sudo tee -a /etc/apt/sources.list
        print_success "BlackArch repository added"
    else
        print_warning "BlackArch repository already exists"
    fi
    
    # Update package list
    print_info "Updating package list with BlackArch repository..."
    sudo apt update
    if [ $? -eq 0 ]; then
        print_success "Repository setup completed"
    else
        print_error "Failed to update with BlackArch repository"
        exit 1
    fi
}

# Installation menu
show_installation_menu() {
    echo -e "\n${BLUE}Choose installation option:${NC}"
    echo "1) Install Essential BlackArch Tools (Recommended)"
    echo "2) Install All BlackArch Tools (Full - 6GB+)"
    echo "3) Install by Category"
    echo "4) Install Specific Tools"
    echo "5) Exit"
    echo -n "Enter your choice [1-5]: "
    read choice
}

# Install essential tools
install_essential_tools() {
    print_info "Installing essential BlackArch tools..."
    
    essential_tools=(
        "nmap"
        "sqlmap" 
        "nikto"
        "dirb"
        "gobuster"
        "hashcat"
        "john"
        "hydra"
        "metasploit-framework"
        "burpsuite"
        "wireshark"
        "aircrack-ng"
        "netcat"
        "masscan"
        "whatweb"
    )
    
    failed_tools=()
    
    for tool in "${essential_tools[@]}"; do
        print_info "Installing $tool..."
        if sudo apt install -y "$tool" &>/dev/null; then
            print_success "$tool installed successfully"
        else
            print_error "Failed to install $tool"
            failed_tools+=("$tool")
        fi
    done
    
    if [ ${#failed_tools[@]} -eq 0 ]; then
        print_success "All essential tools installed successfully!"
    else
        print_warning "Some tools failed to install: ${failed_tools[*]}"
    fi
}

# Install all tools
install_all_tools() {
    print_warning "This will install ALL BlackArch tools (~6GB+). This may take a long time."
    echo -n "Are you sure? (y/N): "
    read confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_info "Installing all BlackArch tools..."
        sudo apt install -y blackarch
        if [ $? -eq 0 ]; then
            print_success "All BlackArch tools installed successfully"
        else
            print_error "Failed to install all tools"
        fi
    else
        print_info "Installation cancelled"
    fi
}

# Install by category
install_by_category() {
    echo -e "\n${BLUE}Select category:${NC}"
    echo "1) Web Application Testing (blackarch-webapp)"
    echo "2) Network Tools (blackarch-networking)"
    echo "3) Wireless Tools (blackarch-wireless)"
    echo "4) Forensics Tools (blackarch-forensic)"
    echo "5) Exploitation Tools (blackarch-exploit)"
    echo "6) Password Attacks (blackarch-passwords)"
    echo "7) Reverse Engineering (blackarch-reversing)"
    echo "8) Back to main menu"
    echo -n "Enter your choice [1-8]: "
    read cat_choice
    
    case $cat_choice in
        1) sudo apt install -y blackarch-webapp ;;
        2) sudo apt install -y blackarch-networking ;;
        3) sudo apt install -y blackarch-wireless ;;
        4) sudo apt install -y blackarch-forensic ;;
        5) sudo apt install -y blackarch-exploit ;;
        6) sudo apt install -y blackarch-passwords ;;
        7) sudo apt install -y blackarch-reversing ;;
        8) return ;;
        *) print_error "Invalid choice" ;;
    esac
}

# Install specific tools
install_specific_tools() {
    echo -e "\n${YELLOW}Enter tool names separated by spaces:${NC}"
    echo "Example: sqlmap nikto nmap"
    echo -n "Tools: "
    read -a tools
    
    for tool in "${tools[@]}"; do
        print_info "Installing $tool..."
        if sudo apt install -y "$tool"; then
            print_success "$tool installed successfully"
        else
            print_error "Failed to install $tool"
        fi
    done
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    test_tools=("nmap" "sqlmap" "nikto")
    
    for tool in "${test_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_success "$tool is available"
        else
            print_warning "$tool is not available"
        fi
    done
}

# Clean up
cleanup() {
    print_info "Cleaning up..."
    sudo apt autoremove -y
    sudo apt autoclean
    print_success "Cleanup completed"
}

# Create desktop shortcuts
create_shortcuts() {
    echo -n "Create desktop shortcuts for common tools? (y/N): "
    read create_desktop
    
    if [[ $create_desktop =~ ^[Yy]$ ]]; then
        print_info "Creating desktop shortcuts..."
        
        # Create Applications menu folder
        mkdir -p ~/.local/share/applications
        
        # Burp Suite shortcut
        cat > ~/.local/share/applications/burpsuite.desktop << EOF
[Desktop Entry]
Name=Burp Suite
Comment=Web Application Security Testing
Exec=burpsuite
Icon=burpsuite
Terminal=false
Type=Application
Categories=Security;Network;
EOF
        
        print_success "Desktop shortcuts created"
    fi
}

# Main execution
main() {
    print_banner
    check_root
    check_internet
    check_disk_space
    
    print_info "Starting BlackArch installation process..."
    
    update_system
    install_dependencies
    setup_blackarch_repo
    
    while true; do
        show_installation_menu
        
        case $choice in
            1)
                install_essential_tools
                break
                ;;
            2)
                install_all_tools
                break
                ;;
            3)
                install_by_category
                ;;
            4)
                install_specific_tools
                ;;
            5)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please select 1-5."
                ;;
        esac
    done
    
    verify_installation
    create_shortcuts
    cleanup
    
    echo -e "\n${GREEN}=================================================="
    echo "    BlackArch Installation Completed!"
    echo "==================================================${NC}"
    echo -e "${YELLOW}Usage Notes:${NC}"
    echo "• Always use tools ethically and legally"
    echo "• Get proper authorization before testing"
    echo "• Keep tools updated regularly"
    echo "• Check tool documentation: man <tool-name>"
    echo ""
    echo -e "${BLUE}Popular tools installed:${NC}"
    echo "• Web Testing: sqlmap, nikto, dirb, gobuster"
    echo "• Network: nmap, masscan, netcat"
    echo "• Password: hashcat, john, hydra"
    echo "• Framework: metasploit-framework"
    echo ""
    print_success "Installation process completed successfully!"
}

# Run main function
main "$@"