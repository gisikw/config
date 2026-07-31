{ config, lib, pkgs, isDarwin ? false, isLinux ? false, ... }:

let
  # frogmouth is a Textual app. All three knobs below are read from the
  # environment when textual.constants is imported, so wrap the binary rather
  # than exporting them from the session — any other Textual TUI is untouched.
  #   TEXTUAL_ANIMATIONS=none   scroll jumps to its destination, uneased
  #   TEXTUAL_SMOOTH_SCROLL=0   no sub-cell (pixel-level) scrolling
  #   TEXTUAL_THEME=monokai     one of Textual's built-in themes
  #
  # frogmouth 0.9.1 predates Textual's theme system: it still assigns the
  # long-removed App.dark, which lands as an inert attribute here, so nothing
  # of its own competes with TEXTUAL_THEME. Its f10 light/dark toggle is
  # already a no-op against this Textual for the same reason.
  frogmouth = pkgs.symlinkJoin {
    name = "frogmouth-${pkgs.frogmouth.version}";
    paths = [ pkgs.frogmouth ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/frogmouth \
        --set TEXTUAL_ANIMATIONS none \
        --set TEXTUAL_SMOOTH_SCROLL 0 \
        --set TEXTUAL_THEME monokai
    '';
  };
in
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

  home.packages = (with pkgs; [
    devenv
    fd
    fzf
    gh
    jira-cli-go # binary is `jira`; acli (flake.nix) covers Confluence
    ripgrep
    tldr
  ]) ++ [
    # De-animated above. <leader>m in neovim opens the current file in it.
    frogmouth
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
