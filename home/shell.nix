{ lib, ... }:

let
  shellInit = ''
    # Config helper function
    config() {
      git --git-dir="$HOME/.config/.git" --work-tree="$HOME/.config" "''${@:-status}"
    }

    # Data transfer utilities
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

    # Status prompt
    function status_prompt() {
      if [ $? -ne 0 ]; then
        STATUS="red"
      else
        [ $(git status --porcelain=1 2>/dev/null | wc -l) -ne 0 ] && STATUS="yellow" || STATUS="green"
      fi

      { read GROOT; read BRANCH; } < <(git rev-parse --show-toplevel --abbrev-ref HEAD 2>/dev/null)

      CONTEXT="$HOST"
      [ -n "$GROOT" ] && CONTEXT="$CONTEXT/$(basename "$GROOT")"
      [ -n "$BRANCH" ] && [[ "$BRANCH" != "master" && "$BRANCH" != "main" ]] && CONTEXT="$CONTEXT#$BRANCH"

      JOB_COUNT=$(jobs -p | wc -l | tr -d '[:space:]')
      if [ "$JOB_COUNT" -gt 0 ]; then
        JOBS_SEGMENT="^$JOB_COUNT"
      else
        JOBS_SEGMENT=""
      fi

      NEWLINE=$'\n'
      PROMPT="%K{$STATUS}%F{black} $CONTEXT %F{$STATUS}%k''${NEWLINE}%F{$STATUS}''${JOBS_SEGMENT}❯%f "
    }

    precmd() { status_prompt; }

    # Ghostty terminal compatibility
    if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
        export TERM=xterm-256color
    fi
  '';
in {
  programs.zsh = {
    enable = true;
    initContent = shellInit;
  };
}
