export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="spaceship"

plugins=(
  git 
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# CTRL+R for fzf-history-widget
source /usr/share/doc/fzf/examples/key-bindings.zsh

