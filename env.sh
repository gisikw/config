export EDITOR=nvim

config() {
  git --git-dir="$HOME/.config/.git" --work-tree="$HOME/.config" "${@:-status}"
}

skyhook() {
  local host="kevingisi.com"
  local port="8675"
  local password
  password=$(openssl rand -base64 24)

  >&2 echo "On the sending machine, append the following: "
  >&2 echo " | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:'$password' > /dev/tcp/$host/$port"
  >&2 echo ""

  ssh $host "trap 'kill 0' EXIT; exec nc -l -p '$port' -q 1" | openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass pass:"$password"
}

skydive() {
  local host="kevingisi.com"
  local port="8675"
  local password
  password=$(openssl rand -base64 24)

  >&2 echo "On the receiving machine, run the following: "
  >&2 echo "cat < /dev/tcp/$host/$port | openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass pass:'$password'"
  >&2 echo ""

  openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$password" | ssh $host "trap 'kill 0' EXIT; exec nc -l -p '$port' -q 1"
}

function get_named_color() {
  case $1 in
    31) echo "red" ;;
    32) echo "green" ;;
    33) echo "yellow" ;;
    36) echo "cyan" ;;
    *) echo "default" ;;
  esac
}

function status_prompt() {
  # Determine status color
  if [ $? -ne 0 ]; then
    STATUS="red"
  else
    [ $(git status --porcelain=1 2>/dev/null | wc -l) -ne 0 ] && STATUS="yellow" || STATUS="green"
  fi

  # Git context
  { read GROOT; read BRANCH; } < <(git rev-parse --show-toplevel --abbrev-ref HEAD 2>/dev/null)

  # Build context string: host[/repo][#branch]
  CONTEXT="$HOST"
  [ -n "$GROOT" ] && CONTEXT="$CONTEXT/$(basename "$GROOT")"
  [ -n "$BRANCH" ] && [[ "$BRANCH" != "master" && "$BRANCH" != "main" ]] && CONTEXT="$CONTEXT#$BRANCH"

  # Background job count
  JOB_COUNT=$(jobs -p | wc -l | tr -d '[:space:]')
  if [ "$JOB_COUNT" -gt 0 ]; then
    JOBS_SEGMENT="^$JOB_COUNT"
  else
    JOBS_SEGMENT=""
  fi

  # Final prompt
  NEWLINE=$'\n'
  PROMPT="%K{$STATUS}%F{black} $CONTEXT %F{$STATUS}%k${NEWLINE}%F{$STATUS}${JOBS_SEGMENT}❯%f "
}

# Hook into prompt
if [[ $ZSH_NAME ]]; then
  precmd() { status_prompt; }
else
  PROMPT_COMMAND=status_prompt
fi

# Not everybody has terminfo support for ghostty yet
if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
    export TERM=xterm-256color
fi
