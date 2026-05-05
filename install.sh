#!/usr/bin/env bash
# install.sh — Linux / Codespaces bootstrap
# Runs automatically when this repo is set as your dotfiles repo in:
#   https://github.com/settings/codespaces
#
# Skips steps that are already satisfied (idempotent).
# Installs: fzf (ctrl-r history), zsh-autosuggestions,
#           zsh-syntax-highlighting, oh-my-zsh, dotfiles checkout

set -e

DOTFILES_REPO="https://github.com/fredsh2k/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Code/Personal/dotfiles}"

info() { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
ok()   { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
warn() { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
skip() { printf '\033[0;90m[skip]\033[0m  %s\n' "$*"; }

[[ "$(uname -s)" == "Linux" ]] || warn "This script is for Linux. On macOS use mac-install.sh"

# ---------------------------------------------------------------------------
# fzf — only thing not pre-installed in the Codespaces universal image
# ---------------------------------------------------------------------------
if ! command -v fzf &>/dev/null; then
  info "Installing fzf..."
  # Allow update to fail on bad third-party keys (common in Codespaces universal image)
  sudo apt-get update -qq || true
  sudo apt-get install -y -qq fzf
else
  skip "fzf already installed"
fi

# ---------------------------------------------------------------------------
# oh-my-zsh
# ---------------------------------------------------------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  skip "oh-my-zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  info "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" --depth=1
else
  skip "zsh-autosuggestions already installed"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  info "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" --depth=1
else
  skip "zsh-syntax-highlighting already installed"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
  info "Installing fzf-tab..."
  git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab" --depth=1
else
  skip "fzf-tab already installed"
fi

if [[ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]]; then
  info "Installing spaceship theme..."
  git clone https://github.com/spaceship-prompt/spaceship-prompt "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
else
  skip "spaceship theme already installed"
fi
ok "oh-my-zsh plugins & theme ready"

# ---------------------------------------------------------------------------
# fzf shell integration — ctrl-r history, ctrl-t file search, alt-c cd
# ---------------------------------------------------------------------------
if [[ -d /usr/share/doc/fzf/examples ]]; then
  mkdir -p "$HOME/.fzf"
  cp /usr/share/doc/fzf/examples/key-bindings.zsh "$HOME/.fzf/key-bindings.zsh" 2>/dev/null || true
  cp /usr/share/doc/fzf/examples/completion.zsh   "$HOME/.fzf/completion.zsh"   2>/dev/null || true
  ok "fzf shell integration ready"
else
  skip "fzf examples dir not found — integration skipped"
fi

# ---------------------------------------------------------------------------
# Dotfiles — clone real repo + symlink each tracked file into $HOME
# ---------------------------------------------------------------------------
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  skip "$DOTFILES_DIR already exists"
else
  info "Cloning dotfiles to $DOTFILES_DIR..."
  mkdir -p "$(dirname "$DOTFILES_DIR")"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

info "Symlinking tracked files into \$HOME..."
backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backup_made=0
cd "$DOTFILES_DIR"
for f in $(git ls-files); do
  live="$HOME/$f"
  target="$DOTFILES_DIR/$f"
  if [[ -L "$live" && "$(readlink "$live")" == "$target" ]]; then
    continue
  fi
  mkdir -p "$(dirname "$live")"
  if [[ -e "$live" || -L "$live" ]]; then
    mkdir -p "$(dirname "$backup_dir/$f")"
    mv "$live" "$backup_dir/$f"
    backup_made=1
  fi
  ln -s "$target" "$live"
done
cd - >/dev/null
[[ $backup_made -eq 1 ]] && warn "Pre-existing files backed up to $backup_dir"
ok "Dotfiles symlinked"

# ---------------------------------------------------------------------------
# Set zsh as default shell
# ---------------------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" == "$ZSH_PATH" ]]; then
  skip "zsh already default shell"
else
  if ! grep -qF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  chsh -s "$ZSH_PATH" 2>/dev/null || warn "Could not chsh — run manually: chsh -s $ZSH_PATH"
  ok "zsh set as default shell"
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
