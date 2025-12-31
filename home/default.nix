{ config, lib, pkgs, isDarwin ? false, isLinux ? false, ... }:

{
  imports = [
    ./git.nix
    ./tmux.nix
    ./neovim
    ./shell.nix
    ./ghostty
  ] ++ lib.optionals isLinux [
    ./sway
  ] ++ lib.optionals isDarwin [
    ./darwin.nix
  ];

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    fzf
    ripgrep
    tldr
  ];

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  programs.home-manager.enable = true;
}
