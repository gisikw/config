# Apply this machine's home-manager configuration.
config() {
  if [[ "$1" == "switch" ]]; then
    shift
    home-manager switch --flake "$HOME/Projects/config#${1:-$USER@$(hostname -s)}"
  else
    echo "usage: config switch [user@host]" >&2
    echo "" >&2
    echo "Applies the home-manager flake at ~/Projects/config" >&2
    echo "(defaults to the current user@hostname)." >&2
    echo "For repo operations, use git in ~/Projects/config." >&2
    return 1
  fi
}
