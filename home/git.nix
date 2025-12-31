{ ... }:

{
  programs.git = {
    enable = true;

    settings.alias = {
      co = "checkout";
      up = "!git push origin $(git rev-parse --abbrev-ref HEAD)";
      down = "!git pull origin $(git rev-parse --abbrev-ref HEAD)";
    };
  };
}
