#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/jefcolbi/anti-eneo"
INSTALL_DIR="$HOME/.local/anti-eneo"
BIN_DIR="$HOME/.local/bin"

echo "Anti-ENEO Installer/Updater"
echo "==========================="
echo

if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git first."
    exit 1
fi

mkdir -p "$BIN_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    echo "Installing anti-eneo..."
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "Updating anti-eneo..."
    cd "$INSTALL_DIR"
    git pull origin main
fi

chmod +x "$INSTALL_DIR/anti-eneo"
chmod +x "$INSTALL_DIR/anti-eneo-watch"

echo "Creating symlinks..."
ln -sf "$INSTALL_DIR/anti-eneo" "$BIN_DIR/anti-eneo"
ln -sf "$INSTALL_DIR/anti-eneo-watch" "$BIN_DIR/anti-eneo-watch"

add_to_path() {
    local shell_config="$1"
    local path_line="export PATH=\"\$HOME/.local/bin:\$PATH\""
    
    if [ -f "$shell_config" ]; then
        if ! grep -q "\$HOME/.local/bin" "$shell_config" 2>/dev/null; then
            echo "" >> "$shell_config"
            echo "# Added by anti-eneo installer" >> "$shell_config"
            echo "$path_line" >> "$shell_config"
            echo "✓ Updated $shell_config"
        fi
    fi
}

add_to_fish_path() {
    local fish_config="$HOME/.config/fish/config.fish"
    local path_line="set -gx PATH \$HOME/.local/bin \$PATH"
    
    if [ -f "$fish_config" ]; then
        if ! grep -q "\$HOME/.local/bin" "$fish_config" 2>/dev/null; then
            mkdir -p "$(dirname "$fish_config")"
            echo "" >> "$fish_config"
            echo "# Added by anti-eneo installer" >> "$fish_config"
            echo "$path_line" >> "$fish_config"
            echo "✓ Updated $fish_config"
        fi
    fi
}

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo
    echo "Updating PATH in shell configuration files..."
    
    updated=false
    
    # Update bashrc
    if [ -f "$HOME/.bashrc" ]; then
        add_to_path "$HOME/.bashrc"
        updated=true
    fi
    
    # Update zshrc
    if [ -f "$HOME/.zshrc" ]; then
        add_to_path "$HOME/.zshrc"
        updated=true
    fi
    
    # Update fish config
    if [ -d "$HOME/.config/fish" ]; then
        add_to_fish_path
        updated=true
    fi
    
    # Update profile as fallback
    if [ "$updated" = false ]; then
        add_to_path "$HOME/.profile"
    fi
    
    # Also export for current session
    export PATH="$HOME/.local/bin:$PATH"
    
    echo
    echo "PATH has been updated. Please restart your terminal or run:"
    echo "  source ~/.bashrc  (for bash)"
    echo "  source ~/.zshrc   (for zsh)"
    echo "  source ~/.config/fish/config.fish  (for fish)"
fi

echo
echo "✓ Installation/Update complete!"
echo
echo "Available commands:"
echo "  anti-eneo       - Main anti-eneo command"
echo "  anti-eneo-watch - Watch mode for anti-eneo"
echo
echo "To update in the future, run this installer again."