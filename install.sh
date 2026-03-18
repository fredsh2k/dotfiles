#!/usr/bin/env bash
# install.sh — bootstrap dotfiles + tools
# Supports: macOS (Homebrew) and Linux/Codespaces (apt)
#
# macOS:      curl -fsSL https://raw.githubusercontent.com/fredsh2k/dotfiles/master/install.sh | bash
# Codespaces: runs automatically when repo is set as dotfiles repo in settings
#             https://github.com/settings/codespaces

set -e

DOTFILES_REPO="https://github.com/fredsh2k/dotfiles.git"
DOTFILES_GIT="$HOME/.dotfiles.git"

info() { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
ok()   { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
warn() { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
die()  { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

IS_MACOS=false
IS_LINUX=false
IS_CODESPACES=false

case "$(uname -s)" in
  Darwin) IS_MACOS=true ;;
  Linux)  IS_LINUX=true ;;
  *)      die "Unsupported OS: $(uname -s)" ;;
esac

[[ -n "${CODESPACES:-}" || -n "${CLOUDENV_ENVIRONMENT_ID:-}" ]] && IS_CODESPACES=true

# ---------------------------------------------------------------------------
# macOS only: Xcode CLT + Homebrew
# ---------------------------------------------------------------------------
if $IS_MACOS; then
  if ! xcode-select -p &>/dev/null; then
    info "Installing Xcode Command Line Tools..."
    xcode-select --install
    read -r -p "Press Enter once the installation is complete..."
  fi
  ok "Xcode CLT ready"

  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  ok "Homebrew ready"

  info "Installing packages via Homebrew..."
  brew install \
    git zsh fzf neovim zellij ripgrep fd sd bat bun gh nvm rbenv \
    zsh-vi-mode zsh-autosuggestions zsh-syntax-highlighting \
    lazygit stylua lua-language-server
  # ghostty is a cask
  brew install --cask ghostty 2>/dev/null || true
  ok "Homebrew packages installed"
fi

# ---------------------------------------------------------------------------
# Linux/Codespaces: apt packages
# ---------------------------------------------------------------------------
if $IS_LINUX; then
  info "Installing packages via apt..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    git zsh fzf ripgrep fd-find bat curl unzip build-essential

  # fd-find installs as 'fdfind' on Debian/Ubuntu — alias to fd
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi

  # batcat vs bat
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi

  # sd — not in apt, install via cargo or prebuilt binary
  if ! command -v sd &>/dev/null; then
    info "Installing sd..."
    curl -fsSL "https://github.com/chmln/sd/releases/latest/download/sd-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz --strip-components=1 -C "$HOME/.local/bin" 2>/dev/null \
      || warn "sd install failed — skipping (non-critical)"
  fi

  # neovim — apt version is often outdated, install AppImage or from releases
  if ! command -v nvim &>/dev/null; then
    info "Installing neovim..."
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
      | sudo tar -xz --strip-components=1 -C /usr/local
  fi

  # zellij — not in apt
  if ! command -v zellij &>/dev/null && ! $IS_CODESPACES; then
    info "Installing zellij..."
    curl -fsSL "https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz -C "$HOME/.local/bin"
  fi

  # bun
  if ! command -v bun &>/dev/null; then
    info "Installing bun..."
    curl -fsSL https://bun.sh/install | bash
  fi

  # gh CLI — may already be present in Codespaces
  if ! command -v gh &>/dev/null; then
    info "Installing gh CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq gh
  fi

  ok "Linux packages installed"
fi

# ---------------------------------------------------------------------------
# oh-my-zsh (both platforms)
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
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" --depth=1
fi
if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
  git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab" --depth=1
fi
if [[ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]]; then
  git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

# zsh-vi-mode: brew on macOS, git clone on Linux
if $IS_LINUX && [[ ! -d "$ZSH_CUSTOM/plugins/zsh-vi-mode" ]]; then
  git clone https://github.com/jeffreytse/zsh-vi-mode "$ZSH_CUSTOM/plugins/zsh-vi-mode" --depth=1
fi
ok "oh-my-zsh plugins & theme ready"

# ---------------------------------------------------------------------------
# opencode (both platforms, skip in Codespaces — not needed there)
# ---------------------------------------------------------------------------
if ! $IS_CODESPACES; then
  if ! command -v opencode &>/dev/null && [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
    info "Installing opencode..."
    curl -fsSL https://opencode.ai/install | bash
  fi
  ok "opencode ready"
fi

# ---------------------------------------------------------------------------
# Dotfiles (bare git repo)
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
if ! dot checkout 2>/dev/null; then
  warn "Backing up conflicting files to ~/.dotfiles-backup/"
  mkdir -p "$HOME/.dotfiles-backup"
  dot checkout 2>&1 \
    | grep "^\s" \
    | awk '{print $1}' \
    | xargs -I{} sh -c 'mkdir -p "$(dirname "$HOME/.dotfiles-backup/{}")" && mv "$HOME/{}" "$HOME/.dotfiles-backup/{}"'
  dot checkout
fi
ok "Dotfiles checked out"

# ---------------------------------------------------------------------------
# Copilot skill symlinks (only if copilot is present or likely to be used)
# ---------------------------------------------------------------------------
if command -v copilot &>/dev/null || [[ -d "$HOME/.copilot" ]] || $IS_CODESPACES; then
  info "Setting up Copilot skill symlinks..."
  mkdir -p "$HOME/.copilot/skills" "$HOME/.copilot/instructions"

  for skill in "$HOME/.agents/skills"/*/; do
    name="$(basename "$skill")"
    target="$HOME/.copilot/skills/$name"
    if [[ ! -L "$target" ]]; then
      ln -s "$skill" "$target"
      ok "  linked skill: $name"
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
# Secrets placeholder (skip in Codespaces — secrets come from env/secrets store)
# ---------------------------------------------------------------------------
if ! $IS_CODESPACES && [[ ! -f "$HOME/.zshrc.local" ]]; then
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
# Set zsh as default shell (Linux only — macOS already defaults to zsh)
# ---------------------------------------------------------------------------
if $IS_LINUX && [[ "$SHELL" != "$(command -v zsh)" ]]; then
  ZSH_PATH="$(command -v zsh)"
  if grep -qF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    chsh -s "$ZSH_PATH" 2>/dev/null || warn "Could not change default shell to zsh (run manually: chsh -s $ZSH_PATH)"
  else
    warn "zsh not in /etc/shells — skipping chsh"
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
ok ""
ok "Bootstrap complete!"
if $IS_CODESPACES; then
  ok "Codespaces: open a new terminal to load zsh with dotfiles applied."
  ok "Copilot skills and instructions are symlinked and ready."
else
  ok "Open a new terminal session to apply all changes."
  ok "Next steps:"
  ok "  1. Fill in your GOPROXY token in ~/.zshrc.local"
  ok "  2. Run 'gh auth login' to authenticate GitHub CLI"
  ok "  3. Open nvim — LazyVim will auto-install plugins on first launch"
  ok "  4. Run 'opencode /connect' to set up your AI provider"
fi
