# AXe — CLI for HID-level iOS Simulator interaction (tap, swipe, type,
# describe-ui). Prebuilt universal release from cameroncooke/AXe; the binary
# ships with bundled FB frameworks (FBSimulatorControl et al) resolved via
# @executable_path, so the whole tree is installed under libexec and bin/axe
# is an exec shim (a symlink would break framework resolution). Upstream's
# code signature is valid as shipped — no strip, no fixup, or the signature
# breaks and macOS kills the process.
{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "axe";
  version = "1.7.1";

  src = pkgs.fetchurl {
    url = "https://github.com/cameroncooke/AXe/releases/download/v${version}/AXe-macOS-v${version}-universal.tar.gz";
    sha256 = "sha256-JqZACcCaOumAsfG0s3e9Ki3ZbLveJIIZNeRzUstxzGk=";
  };

  sourceRoot = ".";
  dontStrip = true;
  dontFixup = true;
  dontPatchShebangs = true;

  installPhase = ''
    mkdir -p $out/libexec/axe $out/bin
    cp -R axe Frameworks AXe_AXe.bundle $out/libexec/axe/
    printf '#!/bin/bash\nexec "%s/libexec/axe/axe" "$@"\n' "$out" > $out/bin/axe
    chmod 755 $out/bin/axe
  '';

  meta = {
    description = "CLI for interacting with iOS Simulators via accessibility and HID APIs";
    homepage = "https://github.com/cameroncooke/AXe";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
  };
}
