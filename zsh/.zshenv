# zsh only reads ~/.zshenv from $HOME; everything else lives in ~/.config/zsh.
export ZDOTDIR="$HOME/.config/zsh"
source "$ZDOTDIR/.zshenv"
