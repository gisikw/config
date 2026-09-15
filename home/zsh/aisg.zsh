# Claude Code through the ASG LiteLLM gateway (litellm.alpinesg.co).
#
# The gateway speaks the Anthropic Messages format natively, but registers
# models under provider-prefixed names the harness doesn't know, and its
# built-in model discovery drops most of them — so instead of pinning one,
# pull the live catalog from /v1/models and pick with fzf. --model accepts
# arbitrary IDs, so non-claude-shaped names work fine.
# Expects a bare gateway token in ~/.aisg. Written to travel: no nix-isms,
# just curl/jq/fzf/claude on PATH — paste it into any zshrc/bashrc.
aisg() {
  local dep missing=()
  for dep in curl jq fzf claude; do
    command -v "$dep" > /dev/null || missing+=("$dep")
  done
  if (( ${#missing[@]} )); then
    echo "aisg: missing: ${missing[*]} — install those first (brew/nix/whatever you've got)" >&2
    return 1
  fi
  if [[ ! -r "$HOME/.aisg" ]]; then
    echo "aisg: no token at ~/.aisg — drop the LiteLLM key in there first" >&2
    echo "(bare token, no quotes; trailing newline is fine)" >&2
    return 1
  fi
  local token model
  token="$(tr -d '[:space:]' < "$HOME/.aisg")"

  model=$(curl -sSf -m 5 -H "Authorization: Bearer $token" \
      "https://litellm.alpinesg.co/v1/models" \
    | jq -r '.data[].id' \
    | fzf --prompt='aisg model> ' --height='~40%' --reverse) || {
    echo "aisg: no model picked (gateway unreachable, empty catalog, or ^C)" >&2
    return 1
  }

  ANTHROPIC_BASE_URL="https://litellm.alpinesg.co" \
  ANTHROPIC_AUTH_TOKEN="$token" \
  ANTHROPIC_SMALL_FAST_MODEL="vertex_ai/claude-sonnet-5@default" \
  claude --model "$model" "$@"
}
