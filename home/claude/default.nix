{ lib, pkgs, ... }:

# User-level Claude Code defaults (settings.json), written to two dirs:
#
#   ~/.claude        — the live config dir. Both Claude Code (/config,
#     /fast, /effort) and claude-code-router (managed gateway entries)
#     rewrite this file at runtime, so switch must not reset it wholesale
#     (it did, on 2026-07-29, and yanked routing/auth out from under
#     running sessions). Instead we deep-merge on every switch:
#       backfill  — applied only where a key is absent; runtime wins.
#       overwrite — enforced invariants; declared value wins, but the
#                   merge is recursive so sibling keys (e.g. CCR's env
#                   entries) survive.
#   ~/.claude-direct — the recovery CLAUDE_CONFIG_DIR used by
#     `claude-direct` (flake.nix). Nothing else manages it, so it IS
#     reset to the full declared state on every switch.

let
  settingsFormat = pkgs.formats.json { };

  # Seed values only — Claude Code and CCR adjust these at runtime.
  backfill = {
    permissions.defaultMode = "auto";
    spinnerTipsEnabled = false;
    theme = "dark";
    model = "claude-fable-5[1m]";
  };

  # Always enforced on switch.
  overwrite = {
    autoCompactEnabled = false;
    env = {
      # The binary is nix-managed; the self-updater could only fight it.
      DISABLE_AUTOUPDATER = "1";
      DISABLE_TELEMETRY = "1";
      DISABLE_ERROR_REPORTING = "1";
    };
  };

  backfillFile =
    settingsFormat.generate "claude-settings-backfill.json" backfill;
  overwriteFile =
    settingsFormat.generate "claude-settings-overwrite.json" overwrite;
  fullFile = settingsFormat.generate "claude-settings.json"
    (lib.recursiveUpdate backfill overwrite);
in {
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeMergeSettings() {
      ${pkgs.jq}/bin/jq -s '.[0] * .[1] * .[2]' \
        ${backfillFile} "$HOME/.claude/settings.json" ${overwriteFile} \
        > "$HOME/.claude/settings.json.new"
      chmod 600 "$HOME/.claude/settings.json.new"
      mv "$HOME/.claude/settings.json.new" "$HOME/.claude/settings.json"
    }
    run mkdir -p "$HOME/.claude" "$HOME/.claude-direct"
    if [ -f "$HOME/.claude/settings.json" ]; then
      run claudeMergeSettings
    else
      run install -m 600 ${fullFile} "$HOME/.claude/settings.json"
    fi
    run install -m 600 ${fullFile} "$HOME/.claude-direct/settings.json"
  '';
}
