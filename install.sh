#!/usr/bin/env zsh
# install.sh — bootstrap a new macOS machine with dotfiles + tools
# Usage: curl -fsSL https://raw.githubusercontent.com/fredsh2k/dotfiles/master/install.sh | zsh
# Or: clone manually and run: zsh install.sh

set -e

DOTFILES_REPO="https://github.com/fredsh2k/dotfiles.git"
DOTFILES_GIT="$HOME/.dotfiles.git"

info()  { print -P "%F{blue}[info]%f  $*"; }
ok()    { print -P "%F{green}[ok]%f    $*"; }
warn()  { print -P "%F{yellow}[warn]%f  $*"; }
die()   { print -P "%F{red}[error]%f $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Xcode Command Line Tools
# ---------------------------------------------------------------------------
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  read -r "?Press Enter once the installation is complete..."
fi
ok "Xcode CLT ready"

# ---------------------------------------------------------------------------
# 2. Homebrew
# ---------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
ok "Homebrew ready"

# ---------------------------------------------------------------------------
# 3. Core packages
# ---------------------------------------------------------------------------
info "Installing packages via Homebrew..."
brew install \
  git \
  zsh \
  fzf \
  neovim \
  zellij \
  ghostty \
  ripgrep \
  fd \
  sd \
  bat \
  bun \
  gh \
  nvm \
  rbenv \
  zsh-vi-mode \
  zsh-autosuggestions \
  zsh-syntax-highlighting

# fzf-tab is a zsh plugin, not a brew formula — installed via oh-my-zsh custom later
ok "Packages installed"

# ---------------------------------------------------------------------------
# 4. oh-my-zsh
# ---------------------------------------------------------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ok "oh-my-zsh ready"

# ---------------------------------------------------------------------------
# 5. oh-my-zsh plugins & theme
# ---------------------------------------------------------------------------
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  info "Installing zsh-autosuggestions plugin..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" --depth=1
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  info "Installing zsh-syntax-highlighting plugin..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" --depth=1
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
  info "Installing fzf-tab plugin..."
  git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab" --depth=1
fi

if [[ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]]; then
  info "Installing spaceship-prompt theme..."
  git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi
ok "oh-my-zsh plugins & theme ready"

# ---------------------------------------------------------------------------
# 6. opencode
# ---------------------------------------------------------------------------
if ! command -v opencode &>/dev/null && [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  info "Installing opencode..."
  curl -fsSL https://opencode.ai/install | bash
fi
ok "opencode ready"

# ---------------------------------------------------------------------------
# 7. LazyVim dependencies
# ---------------------------------------------------------------------------
# LazyVim itself is bootstrapped by the nvim config on first launch.
# Install external dependencies here.
brew install lazygit stylua lua-language-server 2>/dev/null || true
ok "LazyVim dependencies ready"

# ---------------------------------------------------------------------------
# 8. Dotfiles (bare git repo)
# ---------------------------------------------------------------------------
if [[ -d "$DOTFILES_GIT" ]]; then
  warn "~/.dotfiles.git already exists — skipping clone"
else
  info "Cloning dotfiles bare repo..."
  git clone --bare "$DOTFILES_REPO" "$DOTFILES_GIT"
fi

dot() { git --git-dir="$DOTFILES_GIT" --work-tree="$HOME" "$@"; }
dot config status.showUntrackedFiles no

info "Checking out dotfiles..."
# Backup any conflicting files
if ! dot checkout 2>/dev/null; then
  warn "Backing up conflicting files to ~/.dotfiles-backup/"
  mkdir -p "$HOME/.dotfiles-backup"
  dot checkout 2>&1 \
    | grep "^\s" \
    | awk '{print $1}' \
    | xargs -I{} sh -c 'mkdir -p "$HOME/.dotfiles-backup/$(dirname {})" && mv "$HOME/{}" "$HOME/.dotfiles-backup/{}"'
  dot checkout
fi
ok "Dotfiles checked out"

# ---------------------------------------------------------------------------
# 9. Copilot skill symlinks
# ---------------------------------------------------------------------------
if command -v copilot &>/dev/null || [[ -d "$HOME/.copilot" ]]; then
  info "Setting up Copilot skill symlinks..."
  mkdir -p "$HOME/.copilot/skills" "$HOME/.copilot/instructions"

  for skill in "$HOME/.agents/skills"/*/; do
    name="$(basename "$skill")"
    target="$HOME/.copilot/skills/$name"
    if [[ ! -L "$target" ]]; then
      ln -s "$skill" "$target"
      ok "  linked $name"
    fi
  done

  instr_src="$HOME/.agents/instructions/fredsh2k.instructions.md"
  instr_dst="$HOME/.copilot/instructions/fredsh2k.instructions.md"
  if [[ -f "$instr_src" && ! -L "$instr_dst" ]]; then
    ln -s "$instr_src" "$instr_dst"
    ok "  linked instructions"
  fi
fi

# ---------------------------------------------------------------------------
# 10. Secrets placeholder
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
ok "Bootstrap complete! Open a new terminal session to apply all changes."
ok "Next steps:"
ok "  1. Fill in your GOPROXY token in ~/.zshrc.local"
ok "  2. Run 'gh auth login' to authenticate GitHub CLI"
ok "  3. Open nvim — LazyVim will auto-install plugins on first launch"
ok "  4. Run 'opencode /connect' to set up your AI provider"
