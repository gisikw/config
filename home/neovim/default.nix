{ ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  xdg.configFile."nvim/init.lua".source = ../nvim/init.lua;
}
