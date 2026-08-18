if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi


HISTSIZE=1000000
SAVEHIST=1000000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
