#!/bin/bash
#
# COSMIC Development Installation Script
#
# This script installs COSMIC components to a local development prefix
# and sets up a session file for display managers (SDDM, GDM, etc.)
#
# Usage: ./install-dev.sh [OPTIONS]
#
# Options:
#   --prefix PATH    Installation prefix (default: $HOME/.local/cosmic-dev)
#   --session-dir    Session directory (default: /usr/share/wayland-sessions)
#   --no-session     Skip creating the session file
#   --build          Run build before install
#   --help           Show this help message
#

set -e

# Default configuration
DEV_PREFIX="${HOME}/.local/cosmic-dev"
SESSION_DIR="/usr/share/wayland-sessions"
CREATE_SESSION=true
RUN_BUILD=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            DEV_PREFIX="$2"
            shift 2
            ;;
        --session-dir)
            SESSION_DIR="$2"
            shift 2
            ;;
        --no-session)
            CREATE_SESSION=false
            shift
            ;;
        --build)
            RUN_BUILD=true
            shift
            ;;
        --help)
            grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Expand tilde in prefix if present
DEV_PREFIX="${DEV_PREFIX/#\~/$HOME}"

echo "COSMIC Development Installation"
echo "Installation prefix: $DEV_PREFIX"
echo "Session directory:   $SESSION_DIR"
echo

# Check for required group memberships (needed for DRM access)
check_group_membership() {
    local user=$(whoami)
    local missing_groups=()
    
    # Check video group (required for /dev/dri/card*)
    if ! groups | grep -qw "video"; then
        missing_groups+=("video")
    fi
    
    # Check render group (required for /dev/dri/renderD*)
    if ! groups | grep -qw "render"; then
        missing_groups+=("render")
    fi
    
    if [ ${#missing_groups[@]} -gt 0 ]; then
        echo "WARNING: Missing required group memberships for GPU access!"
        echo
        echo "Your user ($user) needs to be in the following groups:"
        for group in "${missing_groups[@]}"; do
            echo "  - $group"
        done
        echo
        echo "To fix this, run:"
        for group in "${missing_groups[@]}"; do
            echo "  sudo usermod -aG $group $user"
        done
        echo
        echo "Then LOG OUT and log back in for the changes to take effect."
        echo "(Group changes only apply to new login sessions)"
        echo
        read -p "Continue with installation anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled. Please add your user to the required groups first."
            exit 1
        fi
        echo
    fi
}

check_group_membership

# Get the script directory (cosmic-epoch root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Build if requested
if [ "$RUN_BUILD" = true ]; then
    echo "Building COSMIC components..."
    just build
    echo
fi

# Run the installation
echo "Installing COSMIC components to $DEV_PREFIX..."
just install prefix="$DEV_PREFIX"
echo
echo "Installation complete!"
echo

# Create/update the session file for display managers
if [ "$CREATE_SESSION" = true ]; then
    SESSION_FILE="$SESSION_DIR/cosmic-dev.desktop"
    START_COSMIC_PATH="$DEV_PREFIX/bin/start-cosmic"
    
    echo "Setting up display manager session..."
    echo "Session file: $SESSION_FILE"
    
    # Check if we need sudo for the session directory
    if [ ! -w "$SESSION_DIR" ]; then
        echo "Note: Requires sudo to write to $SESSION_DIR"
        
        # Create the session file content
        TEMP_SESSION=$(mktemp)
        cat > "$TEMP_SESSION" <<EOF
[Desktop Entry]
Name=COSMIC (Development)
Comment=COSMIC Desktop Environment - Development Build
Exec=$START_COSMIC_PATH
Type=Application
DesktopNames=COSMIC
EOF
        
        # Install with sudo
        sudo mkdir -p "$SESSION_DIR"
        sudo cp "$TEMP_SESSION" "$SESSION_FILE"
        sudo chmod 644 "$SESSION_FILE"
        rm "$TEMP_SESSION"
        
        echo "✓ Session file created (with sudo)"
    else
        # We can write directly
        mkdir -p "$SESSION_DIR"
        cat > "$SESSION_FILE" <<EOF
[Desktop Entry]
Name=COSMIC (Development)
Comment=COSMIC Desktop Environment - Development Build
Exec=$START_COSMIC_PATH
Type=Application
DesktopNames=COSMIC
EOF
        chmod 644 "$SESSION_FILE"
        
        echo "✓ Session file created"
    fi
    
    echo
    echo "Session 'COSMIC (Development)' is now available in your display manager!"
fi

echo
echo "Installation Summary"
echo "Binaries:        $DEV_PREFIX/bin/"
echo "Libraries:       $DEV_PREFIX/lib/"
echo "Data files:      $DEV_PREFIX/share/"
if [ "$CREATE_SESSION" = true ]; then
    echo "Session file:    $SESSION_FILE"
fi
echo
echo "You can now:"
echo "  1. Log out and select 'COSMIC (Development)' in your display manager"
echo "  2. Re-run this script after building individual components to update"
echo
echo "To rebuild and install everything:"
echo "  ./install-dev.sh --build"
echo
echo "Troubleshooting:"
echo "  If the session crashes immediately, ensure your user is in 'video' and 'render' groups:"
echo "    sudo usermod -aG video,render \$USER"
echo "  Then log out completely and log back in."
echo
