{ pkgs, lib, ... }:

let
  version = "1.27.0";

  # On darwin, nixpkgs' deskflow is broken: wrapQtAppsHook wraps every
  # executable in the bundle, including the macdeployqt'd framework
  # dylibs (Frameworks/QtWidgets.framework/.../QtWidgets becomes a wrapper
  # executable), so dyld refuses it at launch ("cannot link against a
  # main executable"). Use upstream's signed, notarized release instead,
  # fetched and pinned here. Linux (brain) stays on nixpkgs.
  dmg = {
    aarch64-darwin = {
      arch = "arm64";
      hash = "sha256-3SHnnlZjFDlCFJBtMzjFBdM3r1NvxYDAIu4/rf+tDJc=";
    };
    x86_64-darwin = {
      arch = "x86_64";
      hash = "sha256-iso8d6Gxa5o9a4o4Dl44oOar9tJBuzLc88+LZ6u/9dg=";
    };
  }.${pkgs.stdenv.hostPlatform.system};

  deskflowDarwin = pkgs.stdenvNoCC.mkDerivation {
    pname = "deskflow-app";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/deskflow/deskflow/releases/download/v${version}/deskflow-${version}-macos-${dmg.arch}.dmg";
      inherit (dmg) hash;
    };
    nativeBuildInputs = [ pkgs._7zz ];
    unpackPhase = ''
      7zz x -y -odmg $src >/dev/null
    '';
    installPhase = ''
      mkdir -p $out/Applications
      cp -R dmg/Deskflow/Deskflow.app $out/Applications/
    '';
    # Leave the signed bundle byte-for-byte as shipped: no strip, no
    # patching, or the code signature stops matching.
    dontFixup = true;
  };
in
{
  # Deskflow: one keyboard and mouse across machines (the open-source
  # upstream of Synergy). The Mac on the desk is the server (keyboard and
  # mouse plug into it); brain, to its right, is the client. Server and
  # client roles, and the screen layout, are set once in the app's own
  # GUI; they're per-machine state, not config. On darwin, copyApps puts
  # it in ~/Applications/Home Manager Apps, so the Accessibility grant
  # survives rebuilds.
  home.packages = [
    (if pkgs.stdenv.isDarwin then deskflowDarwin else pkgs.deskflow)
  ];
}
