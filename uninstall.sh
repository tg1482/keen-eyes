#!/bin/bash
set -e

INSTALL_DIR="$HOME/.keen-eyes"
BIN_DIR="/usr/local/bin"

echo "Uninstalling Keen Eyes..."

# Remove the symlink
if [ -L "$BIN_DIR/keen-eyes" ]; then
    if [ -w "$BIN_DIR" ]; then
        rm "$BIN_DIR/keen-eyes"
    else
        sudo rm "$BIN_DIR/keen-eyes"
    fi
    echo "Removed symlink from $BIN_DIR/keen-eyes"
fi

# Remove the installation directory
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed installation directory: $INSTALL_DIR"
fi

echo "Keen Eyes has been uninstalled successfully."