# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="spaceship"

SPACESHIP_GOLANG_SHOW=false
SPACESHIP_DOCKER_SHOW=false

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  fzf-tab
)

# Plugin optimizations for speed
ZSH_AUTOSUGGEST_MANUAL_REBIND=1  # Faster autosuggestions
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20  # Limit buffer size
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)  # Limit syntax highlighting

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# vi mode & fzf
zvm_after_init_commands+=('
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  [ -f ~/.fzf/key-bindings.zsh ] && source ~/.fzf/key-bindings.zsh
  [ -f ~/.fzf/completion.zsh ]   && source ~/.fzf/completion.zsh
')
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

# Add GitHub Package Registry credentials for Ruby LSP
local _gh_token="$(gh auth token)"
export BUNDLE_RUBYGEMS__PKG__GITHUB__COM="fredsh2k:${_gh_token}"
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

