#!/bin/bash

# Define the installation directory
INSTALL_DIR="/usr/local/opt/keen-eyes"
BIN_DIR="/usr/local/bin"

# Create the installation directory
sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR/lib"

# Copy files to the installation directory
sudo cp bin/keen-eyes "$INSTALL_DIR/bin/keen-eyes"
sudo cp lib/*.sh "$INSTALL_DIR/lib/"

# Create a symlink in /usr/local/bin
sudo ln -sf "$INSTALL_DIR/bin/keen-eyes" "$BIN_DIR/keen-eyes"

# Set correct permissions
sudo chmod +x "$INSTALL_DIR/bin/keen-eyes"
sudo chmod +x "$INSTALL_DIR/lib/"*.sh

echo "Keen Eyes has been installed successfully!"
echo "You can now use the 'keen-eyes' command from anywhere."