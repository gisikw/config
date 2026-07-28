{ pkgs, ... }:

{
  # Fonts installed via home.packages get copied into ~/Library/Fonts
  # by home-manager's darwin support, so macOS apps can see them.
  home.packages = [
    pkgs.nerd-fonts.proggy-clean-tt
  ];
}
