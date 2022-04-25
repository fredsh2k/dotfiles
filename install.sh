#!/bin/sh

apt() {
    apt update 
    apt install -y curl git jq zsh 
    apt-get autoremove -y
    apt-get clean -y
}

zshrc() {
    echo "==========================================================="
    echo "             cloning zsh-autosuggestions                   "
    echo "-----------------------------------------------------------"                    
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    echo "==========================================================="
    echo "             cloning zsh-syntax-highlighting               "
    echo "-----------------------------------------------------------"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    echo "==========================================================="
    echo "                 Copy .zshrc to HOME                       "
    echo "-----------------------------------------------------------"
    cat .zshrc > $HOME/.zshrc
}

apt

zshrc

