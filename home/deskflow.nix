{ pkgs, lib, ... }:

let
  # nixpkgs ships the darwin build as $out/Deskflow.app, at the top of the
  # output rather than under Applications/, so home-manager's copyApps
  # wouldn't see it. Re-home a copy where copyApps looks.
  deskflow =
    if pkgs.stdenv.isDarwin then
      pkgs.runCommand "deskflow-app-${pkgs.deskflow.version}" { } ''
        mkdir -p $out/Applications
        cp -R ${pkgs.deskflow}/Deskflow.app $out/Applications/
      ''
    else
      pkgs.deskflow;
in
{
  # Deskflow: one keyboard and mouse across machines (the open-source
  # upstream of Synergy). The Mac on the desk is the server (keyboard and
  # mouse plug into it); brain, to its right, is the client. Server and
  # client roles, and the screen layout, are set once in the app's own
  # GUI; they're per-machine state, not config. On darwin, copyApps puts
  # it in ~/Applications/Home Manager Apps, so the Accessibility grant
  # survives rebuilds.
  home.packages = [ deskflow ];
}
