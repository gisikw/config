{ pkgs, ... }:

{
  # Fonts installed via home.packages get copied into ~/Library/Fonts
  # by home-manager's darwin support, so macOS apps can see them.
  home.packages = [
    pkgs.nerd-fonts.proggy-clean-tt
  ];

  # System Settings > Sound > "Play user interface sound effects", off.
  # This is what silences the screenshot shutter — and everything else:
  # macOS 26 has no screenshot-only setting. The widely-cited
  # `com.apple.screencapture disable-sound` is not a key that
  # /usr/sbin/screencapture reads (the binary has no such string), and
  # com.apple.systemsound is not the domain the GUI writes. Key, domain
  # and type below were read back off a real toggle of the switch.
  targets.darwin.defaults.NSGlobalDomain."com.apple.sound.uiaudio.enabled" = 0;
}
