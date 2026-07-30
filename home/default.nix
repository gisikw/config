{ config, lib, pkgs, isDarwin ? false, isLinux ? false, ... }:

{
  imports = [
    ./claude
    ./git.nix
    ./tmux.nix
    ./herdr
    ./skills
    ./neovim
    ./zsh
    ./ghostty
  ] ++ lib.optionals isLinux [
    ./sway
  ] ++ lib.optionals isDarwin [
    ./darwin.nix
    ./portal
    ./rectangle
    ./peck
  ];

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    fd
    fzf
    gh
    ripgrep
    tldr
  ];

  # On Linux, home-manager provides nix and enables flakes at the user level.
  # On macOS, Determinate Nix owns the installation (and already enables
  # flakes); installing pkgs.nix there would shadow it with an older binary.
  nix = lib.mkIf isLinux {
    package = lib.mkDefault pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  programs.home-manager.enable = true;
}
