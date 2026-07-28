# PATH additions
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Homebrew (Darwin only, but harmless if missing)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Shell settings
export EDITOR="nvim"
ulimit -n 32768
stty icrnl

# Vi mode with history search
bindkey -v
bindkey '^R' history-incremental-search-backward

# Completion
autoload -Uz compinit && compinit

# Ghostty terminal compatibility
if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
  export TERM=xterm-256color
fi
