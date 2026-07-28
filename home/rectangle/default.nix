{ lib, pkgs, ... }:

# Rectangle (https://rectangleapp.com), configured to mirror SizeUp's
# keybindings (read straight out of SizeUp's plist before the switch).
#
# The app ships from the upstream release .dmg rather than nixpkgs: the
# nixpkgs build is ad-hoc signed, so macOS would revoke its Accessibility
# grant on every store-path change. The Developer-ID-signed copy at a
# stable path in ~/Applications keeps the permission across updates.

let
  version = "0.98";

  app = pkgs.stdenvNoCC.mkDerivation {
    pname = "rectangle-app";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/rxhanson/Rectangle/releases/download/v${version}/Rectangle${version}.dmg";
      hash = "sha256-ziYT1PFxMAFB0dQeIrqxdyaybVH/JsaE6sNXvXuarYY=";
    };

    nativeBuildInputs = [ pkgs.undmg ];
    sourceRoot = ".";

    # Any binary rewriting would break the Developer ID signature.
    dontFixup = true;

    installPhase = ''
      mkdir -p $out
      cp -R Rectangle.app $out/
    '';
  };

  # NSEvent modifier-flag sums, as Rectangle stores them.
  ctrlAltCmd = 1835008; # ⌃⌥⌘
  ctrlAltShift = 917504; # ⌃⌥⇧
  ctrlAlt = 786432; # ⌃⌥

  key = keyCode: modifierFlags: { inherit keyCode modifierFlags; };

  # A present-but-empty dict shadows Rectangle's built-in default for an
  # action (its dictionary transformer returns no shortcut), i.e. unbound.
  unbound = { };
in
{
  home.activation.installRectangle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    installed=$(/usr/bin/defaults read \
      "$HOME/Applications/Rectangle.app/Contents/Info.plist" \
      CFBundleShortVersionString 2>/dev/null || echo none)
    if [ "$installed" != "${version}" ]; then
      run /usr/bin/pkill -x Rectangle || true
      run rm -rf "$HOME/Applications/Rectangle.app"
      run /usr/bin/ditto "${app}/Rectangle.app" "$HOME/Applications/Rectangle.app"
      run /usr/bin/open -a "$HOME/Applications/Rectangle.app"
    fi
  '';

  targets.darwin.defaults."com.knollsoft.Rectangle" = {
    launchOnLogin = true;
    SUEnableAutomaticChecks = false; # updates come from this module

    # SizeUp muscle memory: halves.
    leftHalf = key 123 ctrlAltCmd;
    rightHalf = key 124 ctrlAltCmd;
    topHalf = key 126 ctrlAltCmd;
    bottomHalf = key 125 ctrlAltCmd;

    # Quarters (SizeUp's odd-but-ingrained arrows: UL=←, UR=↑, LL=↓, LR=→).
    topLeft = key 123 ctrlAltShift;
    topRight = key 126 ctrlAltShift;
    bottomLeft = key 125 ctrlAltShift;
    bottomRight = key 124 ctrlAltShift;

    # Full screen + monitor hopping.
    maximize = key 46 ctrlAltCmd; # M
    previousDisplay = key 123 ctrlAlt;
    nextDisplay = key 124 ctrlAlt;

    # Everything else Rectangle binds out of the box is explicitly off so
    # no stray hotkeys appear (its ⌃⌥-arrow and ⌃⌥⌘-arrow defaults would
    # collide with the bindings above).
    restore = unbound;
    center = unbound;
    maximizeHeight = unbound;
    smaller = unbound;
    larger = unbound;
    firstThird = unbound;
    centerThird = unbound;
    lastThird = unbound;
    firstTwoThirds = unbound;
    lastTwoThirds = unbound;
  };
}
