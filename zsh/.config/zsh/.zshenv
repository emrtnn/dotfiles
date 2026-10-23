# Editor
export EDITOR="nvim"
export VISUAL="nvim"

# XDG base directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_BIN_HOME="$HOME/.local/bin"

# SSH agent: gcr-ssh-agent.socket (gcr-4), unless one is already set (e.g. a
# forwarded agent in an SSH login)
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-${XDG_RUNTIME_DIR:-/run/user/$UID}/gcr/ssh}"

# tmux sockets in the runtime dir
export TMUX_TMPDIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

# Global npm installs; Helium is the Chromium for tools that need one
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export CHROME_PATH="/usr/bin/helium-browser"
export PUPPETEER_EXECUTABLE_PATH="/usr/bin/helium-browser"
export PUPPETEER_SKIP_DOWNLOAD="true"

typeset -U path PATH
path=(
  "$HOME/.npm-global/bin"
  "$HOME/.local/share/pnpm/bin"
  "$HOME/.config/emacs/bin"
  "$HOME/.local/bin"
  $path
  "$HOME/.local/share/nvim/mason/bin"
)
