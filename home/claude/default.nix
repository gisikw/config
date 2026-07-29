{ lib, pkgs, ... }:

# User-level Claude Code defaults (settings.json), written to two dirs:
#
#   ~/.claude        — the live config dir. SEED-ONLY: written when the
#     file is absent. Both Claude Code (/config, /fast, /effort) and
#     claude-code-router (managed gateway entries) rewrite this file at
#     runtime, so resetting it on switch would yank routing/auth out
#     from under running sessions (it did, on 2026-07-29).
#   ~/.claude-direct — the recovery CLAUDE_CONFIG_DIR used by
#     `claude-direct` (flake.nix). Nothing else manages it, so it IS
#     reset to the declared state on every switch.

let
  settingsFormat = pkgs.formats.json { };

  settings = settingsFormat.generate "claude-settings.json" {
    permissions.defaultMode = "auto";
    spinnerTipsEnabled = false;
    theme = "dark";
    model = "claude-fable-5[1m]";
    env = {
      # The binary is nix-managed; the self-updater could only fight it.
      DISABLE_AUTOUPDATER = "1";
      DISABLE_TELEMETRY = "1";
      DISABLE_ERROR_REPORTING = "1";
    };
  };
in {
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.claude" "$HOME/.claude-direct"
    if [ ! -f "$HOME/.claude/settings.json" ]; then
      run install -m 600 ${settings} "$HOME/.claude/settings.json"
    fi
    run install -m 600 ${settings} "$HOME/.claude-direct/settings.json"
  '';
}
