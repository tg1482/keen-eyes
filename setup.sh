#!/bin/bash
set -e

INSTALL_DIR="$HOME/.keen-eyes"
BIN_DIR="/usr/local/bin"

echo "Installing Keen Eyes..."

# Create installation directories
mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/lib"

# Copy and modify main script
if [ -f "bin/keen-eyes.sh" ]; then
    cp "bin/keen-eyes.sh" "$INSTALL_DIR/bin/keen-eyes"
    chmod +x "$INSTALL_DIR/bin/keen-eyes"
    
    # Update library paths in the main script
    sed -i.bak "s|source \"\$(dirname \"\$0\")/\.\./lib/|source \"$INSTALL_DIR/lib/|g" "$INSTALL_DIR/bin/keen-eyes"
    rm "$INSTALL_DIR/bin/keen-eyes.bak"
    
    echo "Copied and updated keen-eyes.sh to $INSTALL_DIR/bin/keen-eyes"
else
    echo "Error: Could not find bin/keen-eyes.sh. Make sure you're in the correct directory."
    exit 1
fi

# Copy library files
if [ -d "lib" ]; then
    cp lib/*.sh "$INSTALL_DIR/lib/"
    chmod +x "$INSTALL_DIR/lib/"*.sh
    echo "Copied library files to $INSTALL_DIR/lib/"
else
    echo "Error: lib directory not found. Installation cannot proceed."
    exit 1
fi

# Create symlink
if [ -w "$BIN_DIR" ]; then
    ln -sf "$INSTALL_DIR/bin/keen-eyes" "$BIN_DIR/keen-eyes"
else
    sudo ln -sf "$INSTALL_DIR/bin/keen-eyes" "$BIN_DIR/keen-eyes"
fi

echo "Keen Eyes has been installed successfully!"
echo "You can now use the 'keen-eyes' command from anywhere."

# Verify installation
if ! command -v keen-eyes &> /dev/null; then
    echo "WARNING: The 'keen-eyes' command is not found in the PATH."
    echo "You may need to add $BIN_DIR to your PATH or restart your terminal."
fi