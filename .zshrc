export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="spaceship"

plugins=(
  git 
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# CTRL+R for fzf history
# ESC+C for fzf cd
# CTRL+T for fzf find
source /usr/share/doc/fzf/examples/key-bindings.zsh

