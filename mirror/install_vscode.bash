#!/bin/bash
# Automatically install the correct VSCode Server version into a remote container

set -e  # Exit on error

# Configuration
USERNAME="${username:-root}"
CONTAINER_NAME="${container_name}"
HOSTNAME="${hostname}"
SSHPORT="${sshport:-22}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validate required variables
if [ -z "$CONTAINER_NAME" ]; then
    print_error "container_name is required!"
    exit 1
fi

if [ -z "$HOSTNAME" ]; then
    print_error "hostname is required!"
    exit 1
fi

# Get VSCode commit hash from local installation
print_info "Detecting local VSCode version..."

# Try different methods to get the commit hash
VSCODE_COMMIT=""

# Method 1: Try code --version
if command -v code &> /dev/null; then
    VSCODE_COMMIT=$(code --version 2>/dev/null | sed -n '2p')
fi

# Method 2: Try code-insiders --version
if [ -z "$VSCODE_COMMIT" ] && command -v code-insiders &> /dev/null; then
    VSCODE_COMMIT=$(code-insiders --version 2>/dev/null | sed -n '2p')
    print_warn "Using code-insiders version"
fi

# Method 3: Check Windows installation (for WSL/Git Bash users)
if [ -z "$VSCODE_COMMIT" ] && [ -f "/mnt/c/Users/$USER/AppData/Local/Programs/Microsoft VS Code/resources/app/product.json" ]; then
    VSCODE_COMMIT=$(grep -oP '"commit":\s*"\K[^"]+' "/mnt/c/Users/$USER/AppData/Local/Programs/Microsoft VS Code/resources/app/product.json")
    print_warn "Detected VSCode on Windows"
fi

# Validate we found a commit hash
if [ -z "$VSCODE_COMMIT" ]; then
    print_error "Could not detect VSCode commit hash!"
    print_error "Please run 'code --version' manually and check the second line"
    exit 1
fi

print_info "Found VSCode commit: $VSCODE_COMMIT"

# Construct the download URL
VSCODE_SERVER_URL="https://update.code.visualstudio.com/commit:${VSCODE_COMMIT}/server-linux-x64/stable"
print_info "Server URL: $VSCODE_SERVER_URL"

# Build the installation command
INSTALL_CMD=$(cat <<EOF
set -e
echo "Creating VSCode server directory..."
mkdir -p /root/.vscode-server/bin/${VSCODE_COMMIT}

echo "Downloading VSCode server..."
wget -q --show-progress ${VSCODE_SERVER_URL} -O /tmp/vscode-server.tar.gz

echo "Extracting VSCode server..."
tar -xzf /tmp/vscode-server.tar.gz -C /root/.vscode-server/bin/${VSCODE_COMMIT} --strip-components=1

echo "Cleaning up..."
rm /tmp/vscode-server.tar.gz

echo "VSCode server installed successfully!"
ls -la /root/.vscode-server/bin/${VSCODE_COMMIT}
EOF
)

# Execute the installation in the container
print_info "Installing VSCode server into container..."
print_info "Container: $CONTAINER_NAME on $HOSTNAME:$SSHPORT"

ssh -p "$SSHPORT" "${USERNAME}@${HOSTNAME}" "docker exec -i ${CONTAINER_NAME} bash -c '${INSTALL_CMD}'"

if [ $? -eq 0 ]; then
    print_info "✓ VSCode server successfully installed!"
    print_info "Commit: $VSCODE_COMMIT"
else
    print_error "Installation failed!"
    exit 1
fi
