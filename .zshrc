export ZSH="$HOME/.oh-my-zsh"
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

ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

source $ZSH/oh-my-zsh.sh

# vi mode & fzf
# zvm_after_init is called by zsh-vi-mode after its own init (via precmd on first prompt)
# This re-applies fzf key bindings which zvm would otherwise override
function zvm_after_init() {
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

alias g=git
alias k=kubectl

# dotfiles bare repo management
alias dot='git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'

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
  echo "opencode: web UI at http://100.85.21.13:$port"
  OPENCODE_SERVER_PASSWORD="$OPENCODE_SERVER_PASSWORD" opencode web "$HOME" --hostname 0.0.0.0 --port "$port" "$@"
}

# Attach TUI to the running opencode web server
opencode-tui() {
  local port_file="$HOME/.opencode-port"

  if [[ ! -f "$port_file" ]]; then
    echo "No ~/.opencode-port found. Run opencode-start first."
    return 1
  fi

  local port
  port=$(cat "$port_file")
  OPENCODE_SERVER_PASSWORD="$OPENCODE_SERVER_PASSWORD" opencode attach "http://localhost:$port"
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

