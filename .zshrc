export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"
ZSH_THEME="spaceship"

DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_AUTO_TITLE="true"

# Skip compaudit security check on every startup (run 'compaudit' manually if needed)
DISABLE_COMPFIX="true"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  fzf-tab
)

ZVM_INIT_MODE=sourcing
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

source $ZSH/oh-my-zsh.sh

# vi mode & fzf
# zsh-vi-mode rewrites widgets during first prompt init, so autosuggestions
# must bind again afterward. fzf keybindings are normal/visual-mode bindings,
# so zvm's lazy-keybinding callback is the safe place to restore them.
function zvm_after_init() {
  (( $+functions[_zsh_autosuggest_bind_widgets] )) && _zsh_autosuggest_bind_widgets
}

function zvm_after_lazy_keybindings() {
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
}
# zsh-vi-mode: Homebrew path on macOS, oh-my-zsh custom plugin on Linux
if [[ -f /opt/homebrew/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh ]]; then
  source /opt/homebrew/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
elif [[ -f "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]]; then
  source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
fi

# Spaceship prompt customization - hide language/runtime versions
export SPACESHIP_GOLANG_SHOW=false
export SPACESHIP_DOCKER_SHOW=false
export SPACESHIP_RUBY_SHOW=false
export SPACESHIP_PYTHON_SHOW=false
export SPACESHIP_NODE_SHOW=false
export SPACESHIP_RUST_SHOW=false
export SPACESHIP_DOTNET_SHOW=false

# golang
export GOPRIVATE=
export GONOPROXY=
export GONOSUMDB='github.com/github/*'
export GOPATH='/Users/fsherman/go'

# Secrets (gitignored — contains GOPROXY token, etc.)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

export PATH="/Users/fsherman/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# ruby - lazy load for speed
export PATH="$HOME/.rbenv/bin:$PATH"
# eval "$(rbenv init - zsh)"  # Comment out for faster startup
rbenv() {
  eval "$(command rbenv init - zsh)"
  rbenv "$@"
}
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export MANPATH="/opt/homebrew/share/man:${MANPATH:-}"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"

# Local overrides (for pinned tools such as latest Neovim) should beat Homebrew.
export PATH="$HOME/.local/bin:$PATH"

alias g=git
alias k=kubectl

# dotfiles — symlinked from ~/Code/Personal/dotfiles
alias dot='git -C $HOME/Code/Personal/dotfiles'

# node - lazy load for speed
export NVM_DIR="$HOME/.nvm"
# Lazy load nvm for faster startup
nvm() {
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
  nvm "$@"
}

# Python
alias python3="/opt/homebrew/bin/python3"

# Tailscale
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# Add GitHub Package Registry credentials for Ruby LSP — lazy to avoid gh subprocess on startup
_bundle_rubygems_token() {
  if [[ -z "$BUNDLE_RUBYGEMS__PKG__GITHUB__COM" ]]; then
    export BUNDLE_RUBYGEMS__PKG__GITHUB__COM="fredsh2k:$(gh auth token)"
  fi
}
add-zsh-hook preexec _bundle_rubygems_token
export PATH="$HOME/.rbenv/shims:$PATH"

# Log all commands (including non-interactive from VS Code Copilot) to history
unsetopt nomatch

# bun completions
[ -s "/Users/fsherman/.bun/_bun" ] && source "/Users/fsherman/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH="/Users/fsherman/.opencode/bin:$PATH"

# Start opencode web server with a stable random port, always scoped to $HOME.
# Port is stored in ~/.opencode-port and reused across sessions.
opencode-start() {
  local port_file="$HOME/.opencode-port"

  if [[ ! -f "$port_file" ]]; then
    local port=$(( RANDOM % 50001 + 10000 ))
    echo "$port" > "$port_file"
    echo "opencode: assigned port $port (saved to $port_file)"
  fi

  local port
  port=$(cat "$port_file")
  echo ""
  echo "  opencode web UI"
  echo "  local:  http://localhost:$port"
  echo "  phone:  http://100.85.21.13:$port"
  echo ""
  ( cd "$HOME" && opencode web --hostname 0.0.0.0 --port "$port" --mdns "$@" )
}

# Explicitly attach to the shared opencode web server when desired.
opencode-attach() {
  local port_file="$HOME/.opencode-port"

  if [[ ! -f "$port_file" ]]; then
    echo "No ~/.opencode-port found. Run opencode-start first."
    return 1
  fi

  local port
  port=$(cat "$port_file")
  opencode attach --dir "$(pwd)" "http://localhost:$port"
}

# Print the opencode web URL
opencode-url() {
  local port_file="$HOME/.opencode-port"

  if [[ ! -f "$port_file" ]]; then
    echo "No ~/.opencode-port found. Run opencode-start first."
    return 1
  fi

  local port
  port=$(cat "$port_file")
  echo "http://100.85.21.13:$port"
}

# Update the local CLI/dev toolchain without upgrading every GUI app by default.
devtools-update() {
  local mode="update"
  if [[ "${1:-}" == "--check" ]]; then
    mode="check"
  elif [[ "${1:-}" == "--greedy" ]]; then
    mode="greedy"
  elif [[ -n "${1:-}" ]]; then
    echo "usage: devtools-update [--check|--greedy]" >&2
    return 2
  fi

  local -a brew_tools=(
    gh lazygit ripgrep fd sd jq yq fzf tmux node watchman
    kubernetes-cli kubectx kustomize helm minikube kind hadolint
    go golangci-lint gopls ruby-build rbenv ruby rust rustup uv pipx neovim
  )

  if [[ "$mode" == "check" ]]; then
    _devtools_versions
    _devtools_check npm npm outdated -g --depth=0
    _devtools_check brew brew outdated --greedy "${brew_tools[@]}"
    _devtools_check gem gem outdated
    _devtools_check rustup rustup check
    _devtools_update_go_bins check
    _devtools_update_superpowers check
    return
  fi

  _devtools_run herdr herdr update
  _devtools_run opencode opencode upgrade
  _devtools_run copilot copilot update
  _devtools_run bun bun upgrade
  _devtools_run npm npm update -g
  _devtools_run corepack corepack install -g pnpm@latest yarn@latest
  _devtools_run rustup rustup update stable
  _devtools_run gem gem update --system
  _devtools_run gem gem update

  if command -v brew >/dev/null; then
    brew update
    if [[ "$mode" == "greedy" ]]; then
      brew upgrade --greedy
    else
      brew upgrade "${brew_tools[@]}"
    fi
  fi

  _devtools_update_go_bins update
  _devtools_update_superpowers update
  _devtools_run rbenv rbenv rehash

  echo ""
  echo "Updated dev tools. Current versions:"
  _devtools_versions
}

_devtools_run() {
  local label="$1"
  shift

  command -v "$1" >/dev/null || return 0
  echo "==> $label: $*"
  "$@" || echo "devtools-update: $label failed" >&2
}

_devtools_check() {
  local label="$1"
  shift

  command -v "$1" >/dev/null || return 0
  echo "==> $label: $*"
  "$@" || true
}

_devtools_update_superpowers() {
  local upstream="$HOME/Code/GitHub/superpowers"
  local vendored="$HOME/Code/Personal/dotfiles/.config/opencode/superpowers"
  [[ -d "$upstream/.git" && -d "$vendored" ]] || return 0

  if [[ "$1" == "check" ]]; then
    echo "==> superpowers: compare upstream checkout to dotfiles vendored copy"
    rsync -ani --checksum --delete --exclude .git --exclude 'skills/using-git-worktrees/SKILL.md' "$upstream/" "$vendored/" || true
    return
  fi

  echo "==> superpowers: update upstream checkout and sync into dotfiles"
  git -C "$upstream" fetch origin main || {
    echo "devtools-update: superpowers fetch failed" >&2
    return 0
  }

  if [[ -n "$(git -C "$upstream" status --short)" ]]; then
    echo "devtools-update: superpowers checkout is dirty, skipping sync: $upstream" >&2
    return 0
  fi

  git -C "$upstream" merge --ff-only origin/main || {
    echo "devtools-update: superpowers fast-forward failed" >&2
    return 0
  }

  rsync -a --delete --exclude .git --exclude 'skills/using-git-worktrees/SKILL.md' "$upstream/" "$vendored/" || {
    echo "devtools-update: superpowers sync failed" >&2
    return 0
  }
}

_devtools_update_go_bins() {
  command -v go >/dev/null || return 0
  command -v rg >/dev/null || return 0

  local gopath
  gopath=$(go env GOPATH 2>/dev/null) || return 0
  [[ -d "$gopath/bin" ]] || return 0

  local bin module
  for bin in "$gopath"/bin/*(N.); do
    module=$(go version -m "$bin" 2>/dev/null | rg '^\tpath\t' | cut -f3)
    [[ -n "$module" && "$module" == */* && "$module" != command-line-arguments ]] || continue

    if [[ "$1" == "check" ]]; then
      echo "go tool: ${bin:t} <- $module"
    else
      echo "==> go tool: ${bin:t} <- $module@latest"
      go install "$module@latest" || echo "devtools-update: go install failed for $module" >&2
    fi
  done
}

_devtools_versions() {
  local cmd
  for cmd in herdr opencode copilot gh bun npm node ruby gem go golangci-lint gopls rustup rustc cargo uv pipx nvim lazygit rg fd sd jq yq fzf kubectl helm; do
    command -v "$cmd" >/dev/null || continue
    echo "== $cmd =="
    case "$cmd" in
      copilot) copilot version ;;
      kubectl) kubectl version --client ;;
      helm) helm version ;;
      go) go version ;;
      gem) gem --version ;;
      *) "$cmd" --version 2>/dev/null || "$cmd" version 2>/dev/null || true ;;
    esac | head -n 4
  done
}

# Send a Discord notification via webhook.
# Usage: notify "message"
#        notify "title" "message"
#        echo "piped" | notify
# Webhook URL lives at ~/.config/secrets/discord-webhook (gitignored, chmod 600).
notify() {
  local webhook_file="$HOME/.config/secrets/discord-webhook"
  if [[ ! -r "$webhook_file" ]]; then
    echo "notify: missing $webhook_file" >&2
    return 1
  fi

  local webhook
  webhook=$(<"$webhook_file")

  local content
  if [[ $# -eq 0 ]]; then
    content=$(cat)
  elif [[ $# -eq 1 ]]; then
    content="$1"
  else
    content="**$1**
$2"
  fi

  if [[ -z "$content" ]]; then
    echo "notify: empty message" >&2
    return 1
  fi

  # Discord caps message content at 2000 chars.
  content="${content:0:1900}"

  curl -fsS -H "Content-Type: application/json" \
    -d "$(jq -nc --arg c "$content" '{content:$c}')" \
    "$webhook" >/dev/null
}
