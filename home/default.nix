{ config, lib, pkgs, isDarwin ? false, isLinux ? false, ... }:

{
  imports = [
    ./git.nix
    ./tmux.nix
    ./neovim.nix
    ./shell.nix
    ./ghostty.nix
  ] ++ lib.optionals isLinux [
    ./linux.nix
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
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  programs.home-manager.enable = true;
}
