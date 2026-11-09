{ lib, ... }:

# Workaround for home-manager release-26.05's setupLaunchAgents, which
# stops a changed or removed agent with `launchctl bootout --wait`.
# macOS before 26 has no --wait, so launchctl reads it as the target
# ("Unrecognized target specifier"), the old agent stays loaded, and the
# bootstrap that follows fails with I/O error 5. Fixed upstream on master
# (nix-community/home-manager#9587: --wait only on macOS 26+), not yet on
# release-26.05.
#
# This runs just before setupLaunchAgents and boots out, without --wait,
# every agent home-manager is about to replace or remove, then waits for
# it to be gone. home-manager's own bootout still prints its warning, but
# its bootstrap then succeeds. Delete this module once release-26.05 has
# the fix.
{
  home.activation.bootoutChangedAgents =
    lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
      _bo_new="$(readlink -m "$newGenPath/LaunchAgents")"
      _bo_old=""
      if [[ -n "''${oldGenPath:-}" ]]; then
        _bo_old="$(readlink -m "$oldGenPath/LaunchAgents")"
      fi
      _bo_dst="$HOME/Library/LaunchAgents"
      if [[ -d "$_bo_old" && -d "$_bo_dst" ]]; then
        for _bo_src in "$_bo_old"/*.plist; do
          [[ -e "$_bo_src" ]] || continue
          _bo_file="''${_bo_src##*/}"
          _bo_label="''${_bo_file%.plist}"
          [[ -f "$_bo_dst/$_bo_file" ]] || continue
          # Unchanged agents are left alone, as home-manager does.
          if [[ -e "$_bo_new/$_bo_file" ]] && cmp -s "$_bo_new/$_bo_file" "$_bo_dst/$_bo_file"; then
            continue
          fi
          verboseEcho "Booting out changed/removed agent gui/$UID/$_bo_label"
          run /bin/launchctl bootout "gui/$UID/$_bo_label" 2>/dev/null || true
          for _bo_i in $(seq 50); do
            /bin/launchctl print "gui/$UID/$_bo_label" >/dev/null 2>&1 || break
            sleep 0.1
          done
        done
      fi
      unset _bo_new _bo_old _bo_dst _bo_src _bo_file _bo_label _bo_i
    '';
}
