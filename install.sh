#!/usr/bin/env bash
# install.sh — Linux / Codespaces bootstrap
# Runs automatically when this repo is set as your dotfiles repo in:
#   https://github.com/settings/codespaces
#
# Installs: zsh, fzf (ctrl-r history), zsh-autosuggestions,
#           zsh-syntax-highlighting, oh-my-zsh, dotfiles checkout

set -e

DOTFILES_REPO="https://github.com/fredsh2k/dotfiles.git"
DOTFILES_GIT="$HOME/.dotfiles.git"

info() { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
ok()   { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
warn() { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }

[[ "$(uname -s)" == "Linux" ]] || { warn "This script is for Linux. On macOS use mac-install.sh"; }

# ---------------------------------------------------------------------------
# apt packages
# ---------------------------------------------------------------------------
info "Installing packages via apt..."
# Allow update to fail on bad third-party keys (common in Codespaces universal image)
sudo apt-get update -qq || true
sudo apt-get install -y -qq zsh fzf ripgrep fd-find bat curl git unzip

# Debian/Ubuntu ship fd as fdfind and bat as batcat — alias them
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi
ok "apt packages installed"

# ---------------------------------------------------------------------------
# oh-my-zsh
# ---------------------------------------------------------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ok "oh-my-zsh ready"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" --depth=1
fi
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" --depth=1
fi
if [[ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]]; then
  git clone https://github.com/spaceship-prompt/spaceship-prompt "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi
ok "oh-my-zsh plugins & theme ready"

# ---------------------------------------------------------------------------
# fzf shell integration — ctrl-r history, ctrl-t file search, alt-c cd
# ---------------------------------------------------------------------------
if [[ -d /usr/share/doc/fzf/examples ]]; then
  mkdir -p "$HOME/.fzf"
  cp /usr/share/doc/fzf/examples/key-bindings.zsh "$HOME/.fzf/key-bindings.zsh" 2>/dev/null || true
  cp /usr/share/doc/fzf/examples/completion.zsh   "$HOME/.fzf/completion.zsh"   2>/dev/null || true
fi
ok "fzf shell integration ready"

# ---------------------------------------------------------------------------
# Dotfiles (bare git repo)
# ---------------------------------------------------------------------------
if [[ -d "$DOTFILES_GIT" ]]; then
  warn "~/.dotfiles.git already exists — skipping clone"
else
  info "Cloning dotfiles..."
  git clone --bare "$DOTFILES_REPO" "$DOTFILES_GIT"
fi

dot() { git --git-dir="$DOTFILES_GIT" --work-tree="$HOME" "$@"; }
dot config status.showUntrackedFiles no

info "Checking out dotfiles..."
if ! dot checkout 2>/dev/null; then
  warn "Backing up conflicting files to ~/.dotfiles-backup/"
  mkdir -p "$HOME/.dotfiles-backup"
  dot checkout 2>&1 \
    | awk '/^\s/ {print $1}' \
    | xargs -I{} sh -c 'mkdir -p "$(dirname "$HOME/.dotfiles-backup/{}")" && mv "$HOME/{}" "$HOME/.dotfiles-backup/{}"'
  dot checkout
fi
ok "Dotfiles checked out"

# ---------------------------------------------------------------------------
# Set zsh as default shell
# ---------------------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  if grep -qF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    chsh -s "$ZSH_PATH" 2>/dev/null || warn "Could not chsh — run manually: chsh -s $ZSH_PATH"
  else
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    chsh -s "$ZSH_PATH" 2>/dev/null || warn "Could not chsh — run manually: chsh -s $ZSH_PATH"
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
ok ""
ok "Bootstrap complete!"
ok "Run 'exec zsh' or open a new terminal to start using zsh."
ok "ctrl-r  — fzf history search"
ok "ctrl-t  — fzf file search"
ok "alt-c   — fzf cd into directory"
