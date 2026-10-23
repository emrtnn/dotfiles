# Plugins come from pacman: zsh-autosuggestions, zsh-syntax-highlighting,
# zsh-history-substring-search.
typeset -U path cdpath fpath manpath

[[ -d /usr/share/zsh/$ZSH_VERSION/help ]] && HELPDIR="/usr/share/zsh/$ZSH_VERSION/help"

# Use viins keymap as the default.
bindkey -v

autoload -U compinit && compinit
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history)


eval "$(zoxide init zsh --cmd cd)"
eval "$(starship init zsh)"

# History options should be set in .zshrc and after oh-my-zsh sourcing.
HISTSIZE="10000"
SAVEHIST="10000"

HISTFILE="$ZDOTDIR/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

# fzf: defaults and the Ctrl+T / Alt+C / Ctrl+R widgets' previews
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded --info=inline --cycle --margin=1 --padding=1 --no-mouse --bind=ctrl-f:preview-page-down,ctrl-b:preview-page-up"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always {}' --preview-window=right:50%"
export FZF_CTRL_R_OPTS="--sort --preview 'echo {}' --preview-window=down:3:hidden:wrap"

if [[ $options[zle] = on ]]; then
  source /usr/share/fzf/key-bindings.zsh
  source /usr/share/fzf/completion.zsh
fi

# Set shell options
set_opts=(
  HIST_FCNTL_LOCK APPEND_HISTORY EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST
  HIST_FIND_NO_DUPS HIST_IGNORE_ALL_DUPS HIST_IGNORE_DUPS HIST_IGNORE_SPACE
  HIST_SAVE_NO_DUPS SHARE_HISTORY autocd
)
for opt in "${set_opts[@]}"; do
  setopt "$opt"
done
unset opt set_opts

# Vi Mode
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' visual-mode
bindkey -M vicmd '^o' edit-command-line
bindkey -M viins '^?' backward-delete-char

bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^H' backward-kill-word

# Shift+Tab cycles completions backwards
zmodload zsh/complist
bindkey '^[[Z' reverse-menu-complete
bindkey -M menuselect '^[[Z' reverse-menu-complete

# Cursor shape: blinking block for insert, static block for normal/visual
_cursor_block_blink() { printf '\e[1 q'; }
_cursor_block_static() { printf '\e[2 q'; }
zle-keymap-select() {
  case $KEYMAP in
    vicmd|visual) _cursor_block_static ;;
    *)            _cursor_block_blink ;;
  esac
}
zle -N zle-keymap-select
zle-line-init() { _cursor_block_blink; }
zle -N zle-line-init

# Ignore completion case
zstyle ':completion:*' matcher-list \
  'm:{a-z}={A-Za-z}' \
  'r:|=*' \
  'l:|=* r:|=*'
zstyle ":completion:*" list-colors "\$\{(s.:.)LS_COLORS\}"
zstyle ":completion:*" menu yes select
zstyle ":completion:*" group-name
zstyle ":completion:*" verbose yes
zstyle ":completion:*:descriptions" format '%F{yellow}%d%f'
zstyle ":completion:*" use-cache on
zstyle ":completion:*" cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' special-dirs false

setopt NUMERIC_GLOB_SORT
setopt GLOB_DOTS

setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_MINUS
setopt PUSHD_SILENT
setopt NO_BEEP
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt HIST_VERIFY
setopt AUTO_CD
setopt AUTO_PARAM_SLASH
setopt AUTO_REMOVE_SLASH
setopt AUTO_LIST

# y: run yazi and cd into the directory it exits in
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

source <(carapace _carapace zsh)

alias -- cat=bat
alias -- eza='eza --icons auto --color always --git'
alias -- find=fd
alias -- ga='git add'
alias -- gb='git branch'
alias -- gc='git commit'
alias -- gco='git checkout'
alias -- gcp='git cherry-pick'
alias -- gd=tuicr
alias -- gds='git diff --staged'
alias -- gl='git plog'
alias -- gp='git push'
alias -- grep=rg
alias -- gs='git status'
alias -- gt='git tag'
alias -- jd='tuicr -r @'
alias -- jdesc='jj describe'
alias -- jl='jj log -r '\''all()'\'''
alias -- jn='jj new'
alias -- js='jj status --no-pager'
alias -- jshow='jj show --no-pager'
alias -- l='eza -l'
alias -- la='eza -a'
alias -- lg=lazygit
alias -- ll='eza -lh'
alias -- lla='eza -la'
alias -- ls=eza
alias -- lt='eza --tree'
alias -- nfzf='nvim $(fzf -m --preview='\''bat --color=always {}'\'')'
alias -- pfzf='fzf --preview='\''bat --color=always {}'\'''
alias -- tree='eza --tree'
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)



source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey "^p" history-substring-search-up
bindkey "^n" history-substring-search-down
