{ pkgs, lib, ... }:

{
  # Kev's desk Beelink (x86_64-linux, GNOME). Not a homeConfigurations
  # entry: fort-nix/homestead builds this home into the system through
  # lib.nixosHome, so `nixos-rebuild` applies it.

  # Deskflow client at login. brain autologins (homestead.autoLogin), so
  # after a reboot the session comes up and Deskflow reconnects to the Mac
  # with no keyboard on the box. The GUI (not bare deskflow-core) so the
  # window is there to reconfigure; it starts the core itself when
  # gui/startCoreWithGui is set (below).
  xdg.configFile."autostart/org.deskflow.deskflow.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Deskflow
    Exec=${pkgs.deskflow}/bin/deskflow
    Icon=org.deskflow.deskflow
    X-GNOME-Autostart-enabled=true
  '';

  # Role, server, TLS and the GNOME RemoteDesktop portal's restore token
  # all live in ~/.config/Deskflow/Deskflow.conf, written by the app (the
  # portal grant persists there as client/xdpRestoreToken, so the "allow
  # remote interaction" prompt shouldn't come back each login). It's
  # mutable app state, so it isn't a Nix-managed file; the one key that
  # matters for unattended start is forced on here, if the file exists.
  home.activation.deskflowStartCore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf="$HOME/.config/Deskflow/Deskflow.conf"
    if [ -f "$conf" ]; then
      tmp="$(mktemp)"
      ${pkgs.gawk}/bin/awk '
        BEGIN { insec = 0; done = 0 }
        /^\[/ {
          if (insec && !done) { print "startCoreWithGui=true"; done = 1 }
          insec = ($0 == "[gui]")
        }
        insec && /^startCoreWithGui=/ { print "startCoreWithGui=true"; done = 1; next }
        { print }
        END {
          if (insec && !done) { print "startCoreWithGui=true"; done = 1 }
          if (!done) { print ""; print "[gui]"; print "startCoreWithGui=true" }
        }
      ' "$conf" > "$tmp"
      if ! cmp -s "$tmp" "$conf"; then
        run cp "$tmp" "$conf"
      fi
      rm -f "$tmp"
    fi
  '';
}
