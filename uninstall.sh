#!/bin/bash

# Define the installation directory
INSTALL_DIR="/usr/local/opt/keen-eyes"
BIN_DIR="/usr/local/bin"

# Remove the symlink
sudo rm -f "$BIN_DIR/keen-eyes"

# Remove the installation directory
sudo rm -rf "$INSTALL_DIR"

echo "Keen Eyes has been uninstalled successfully!"