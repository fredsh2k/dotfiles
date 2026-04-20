#!/usr/bin/env bash
# mac-install.sh — full macOS bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/fredsh2k/dotfiles/main/mac-install.sh | bash
# Or:    clone manually and run: bash mac-install.sh

set -e

DOTFILES_REPO="https://github.com/fredsh2k/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Code/Personal/dotfiles}"

info() { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
ok()   { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
warn() { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
die()  { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This script is macOS only. For Linux/Codespaces use install.sh"

# ---------------------------------------------------------------------------
# Xcode Command Line Tools
# ---------------------------------------------------------------------------
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  read -r -p "Press Enter once the installation is complete..."
fi
ok "Xcode CLT ready"

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
ok "Homebrew ready"

# ---------------------------------------------------------------------------
# CLI tools
# ---------------------------------------------------------------------------
info "Installing CLI tools..."
brew install \
  git \
  zsh \
  fzf \
  ripgrep \
  fd \
  sd \
  bat \
  eza \
  dust \
  bottom \
  broot \
  rm-improved \
  zoxide \
  gh \
  nvm \
  rbenv \
  bun \
  lazygit \
  neovim \
  zellij \
  stylua \
  lua-language-server \
  imagemagick \
  presenterm \
  weasyprint \
  zsh-vi-mode \
  zsh-autosuggestions \
  zsh-syntax-highlighting
ok "CLI tools installed"

# ---------------------------------------------------------------------------
# npm global tools (requires nvm/node)
# ---------------------------------------------------------------------------
info "Installing npm global tools..."
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
if command -v nvm &>/dev/null; then
  nvm install --lts 2>/dev/null || true
  npm install -g @mermaid-js/mermaid-cli 2>/dev/null || warn "mmdc install failed — install manually after nvm setup"
else
  warn "nvm not loaded — skipping npm global tools (run manually after shell reload)"
fi
ok "npm global tools done"

# ---------------------------------------------------------------------------
# GUI apps (casks)
# ---------------------------------------------------------------------------
info "Installing GUI apps..."
brew install --cask ghostty 2>/dev/null || warn "ghostty cask failed — install manually"
ok "GUI apps installed"

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
if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
  git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab" --depth=1
fi
if [[ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]]; then
  git clone https://github.com/spaceship-prompt/spaceship-prompt "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi
ok "oh-my-zsh plugins & theme ready"

# ---------------------------------------------------------------------------
# opencode
# ---------------------------------------------------------------------------
if ! command -v opencode &>/dev/null && [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  info "Installing opencode..."
  curl -fsSL https://opencode.ai/install | bash
fi
ok "opencode ready"

# ---------------------------------------------------------------------------
# Dotfiles — clone real repo + symlink each tracked file into $HOME
# ---------------------------------------------------------------------------
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  warn "$DOTFILES_DIR already exists — skipping clone"
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
# Copilot skill symlinks
# ---------------------------------------------------------------------------
if command -v copilot &>/dev/null || [[ -d "$HOME/.copilot" ]]; then
  info "Setting up Copilot skill symlinks..."
  mkdir -p "$HOME/.copilot/skills" "$HOME/.copilot/instructions"

  for skill in "$HOME/.agents/skills"/*/; do
    name="$(basename "$skill")"
    target="$HOME/.copilot/skills/$name"
    [[ ! -L "$target" ]] && ln -s "$skill" "$target" && ok "  linked skill: $name"
  done

  instr_src="$HOME/.agents/instructions/fredsh2k.instructions.md"
  instr_dst="$HOME/.copilot/instructions/fredsh2k.instructions.md"
  [[ -f "$instr_src" && ! -L "$instr_dst" ]] && ln -s "$instr_src" "$instr_dst" && ok "  linked instructions"
fi

# ---------------------------------------------------------------------------
# Secrets placeholder
# ---------------------------------------------------------------------------
if [[ ! -f "$HOME/.zshrc.local" ]]; then
  info "Creating ~/.zshrc.local placeholder for secrets..."
  cat > "$HOME/.zshrc.local" <<'SECRETS'
# Secrets — NOT tracked in git
# Fill in your tokens below after rotating them.

# GitHub Go proxy token (https://github.com/settings/tokens)
export GOPROXY=https://nobody:REPLACE_ME@goproxy.githubapp.com/mod,https://proxy.golang.org/,direct
SECRETS
  warn "~/.zshrc.local created — fill in your GOPROXY token before using Go"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
ok ""
ok "Bootstrap complete! Open a new terminal to apply all changes."
ok "Next steps:"
ok "  1. Fill in your GOPROXY token in ~/.zshrc.local"
ok "  2. Run 'gh auth login' to authenticate GitHub CLI"
ok "  3. Open nvim — LazyVim will auto-install plugins on first launch"
ok "  4. Run 'opencode' to set up your AI provider"
