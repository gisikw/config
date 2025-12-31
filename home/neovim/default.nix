{ ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  xdg.configFile."nvim/init.lua".source = ./init.lua;
}
