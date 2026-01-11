#!/bin/bash
#
# Vim Configuration Setup Script
# Installs vim-plug, plugins, and configuration
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MAC=true
else
    IS_MAC=false
fi

echo "=== Vim Configuration Setup ==="
echo

# Check for vim
if ! command -v vim &> /dev/null; then
    echo "Error: vim is not installed"
    if $IS_MAC; then
        echo "Install with: brew install vim"
    else
        echo "Install with: sudo apt install vim"
    fi
    exit 1
fi

if $IS_MAC; then
    VIM_VERSION=$(vim --version | head -1 | sed 's/.*Vi IMproved \([0-9]*\.[0-9]*\).*/\1/')
else
    VIM_VERSION=$(vim --version | head -1 | grep -oP '\d+\.\d+' | head -1)
fi
echo "Found vim version: $VIM_VERSION"

# Install system dependencies
echo
echo "=== Checking system dependencies ==="

install_deps() {
    local missing=()

    if ! command -v fzf &> /dev/null; then
        missing+=("fzf")
    fi

    if ! command -v rg &> /dev/null; then
        missing+=("ripgrep")
    fi

    if ! command -v tmux &> /dev/null; then
        missing+=("tmux")
    fi

    # Optional linters
    if ! command -v shellcheck &> /dev/null; then
        missing+=("shellcheck")
    fi

    if ! command -v yamllint &> /dev/null; then
        echo "Note: yamllint not found (pip install yamllint)"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Installing: ${missing[*]}"
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y "${missing[@]}"
        elif command -v brew &> /dev/null; then
            brew install "${missing[@]}"
        else
            echo "Please install manually: ${missing[*]}"
            exit 1
        fi
    else
        echo "All dependencies installed"
    fi
}

install_deps

# Backup existing config
echo
echo "=== Backing up existing configuration ==="

if [ -f ~/.vimrc ]; then
    BACKUP=~/.vimrc.backup.$(date +%Y%m%d%H%M%S)
    echo "Backing up ~/.vimrc to $BACKUP"
    cp ~/.vimrc "$BACKUP"
fi

if [ -d ~/.vim ]; then
    BACKUP=~/.vim.backup.$(date +%Y%m%d%H%M%S)
    echo "Backing up ~/.vim to $BACKUP"
    cp -r ~/.vim "$BACKUP"
fi

# Install vim-plug
echo
echo "=== Installing vim-plug ==="

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "vim-plug installed"

# Copy vimrc
echo
echo "=== Installing vimrc ==="

cp "$SCRIPT_DIR/vimrc" ~/.vimrc
echo "vimrc installed"

# Copy tmux.conf
echo
echo "=== Installing tmux.conf ==="

if [ -f ~/.tmux.conf ]; then
    BACKUP=~/.tmux.conf.backup.$(date +%Y%m%d%H%M%S)
    echo "Backing up ~/.tmux.conf to $BACKUP"
    cp ~/.tmux.conf "$BACKUP"
fi

cp "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
echo "tmux.conf installed"

# Install plugins
echo
echo "=== Installing plugins ==="

vim -es -u ~/.vimrc -i NONE -c "PlugInstall" -c "qa" 2>/dev/null || \
    vim +PlugInstall +qall

echo "Plugins installed"

# Check Go version for vim-go
echo
echo "=== Checking Go (optional) ==="

if command -v go &> /dev/null; then
    if $IS_MAC; then
        GO_VERSION=$(go version | sed 's/.*\(go[0-9]*\.[0-9]*\).*/\1/')
        GO_MINOR=$(echo "$GO_VERSION" | sed 's/go[0-9]*\.\([0-9]*\).*/\1/')
    else
        GO_VERSION=$(go version | grep -oP 'go\d+\.\d+' | head -1)
        GO_MINOR=$(echo "$GO_VERSION" | grep -oP '\d+\.\d+' | cut -d. -f2)
    fi
    echo "Found $GO_VERSION"

    # Check if version is sufficient
    if [ "$GO_MINOR" -ge 24 ]; then
        echo "Go version sufficient for vim-go binaries"
        echo "Run :GoUpdateBinaries in vim to install gopls, goimports, etc."
    else
        echo "Note: Go 1.24+ recommended for vim-go binaries"
        echo "Current: $GO_VERSION"
    fi
else
    echo "Go not installed (vim-go features will be limited)"
fi

echo
echo "=== Setup complete ==="
echo
echo "Start vim and enjoy!"
echo
echo "Key shortcuts:"
echo "  Ctrl-p     Fuzzy find files"
echo "  Ctrl-n     Toggle file tree"
echo "  Ctrl-\\    Toggle terminal"
echo "  Tab        Next buffer"
echo "  :G         Git status"
echo
echo "See README.md for full documentation"
