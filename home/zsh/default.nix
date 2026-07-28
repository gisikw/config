{ lib, ... }:

{
  programs.zsh = {
    enable = true;
    initContent = lib.concatMapStrings builtins.readFile [
      ./init.zsh
      ./prompt.zsh
      ./config.zsh
      ./transfer.zsh
    ];
  };
}
