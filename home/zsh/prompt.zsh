# Status prompt: green/yellow/red block showing host/repo#branch,
# colored by last exit status and git cleanliness.
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

  # Slabs are dark fills (readable as background); the chevron keeps the
  # plain ANSI status color, which is tuned to read as foreground.
  case "$STATUS" in
    green)  SLAB="#2a4c37"; SLABTXT="#cfe4d5" ;;
    yellow) SLAB="#593d24"; SLABTXT="#eddaca" ;;
    red)    SLAB="#5e3836"; SLABTXT="#f2d7d5" ;;
  esac

  NEWLINE=$'\n'
  PROMPT="%K{$SLAB}%F{$SLABTXT} $CONTEXT %f%k${NEWLINE}%F{$STATUS}${JOBS_SEGMENT}❯%f "
}

precmd() { status_prompt; }
