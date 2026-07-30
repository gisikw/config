{ ... }:

{
  programs.git = {
    enable = true;

    # Personal scaffolding dropped into other people's repos — a flake or
    # devenv for a dev shell, a justfile for local tasks — kept out of
    # their diffs. Written to ~/.config/git/ignore, which git reads by
    # default.
    #
    # Caveat: this also applies in repos where these files ARE the project.
    # Already-tracked files are unaffected (this repo's own flake.nix is
    # fine), but starting a new flake needs `git add -f flake.nix`.
    ignores = [
      "flake.nix"
      "flake.lock"
      "justfile"
      "devenv.nix"
      "devenv.yaml"
      "devenv.lock"
      ".devenv*"
      ".envrc"
      ".direnv/"
    ];

    settings.alias = {
      co = "checkout";
      up = "!git push origin $(git rev-parse --abbrev-ref HEAD)";
      down = "!git pull origin $(git rev-parse --abbrev-ref HEAD)";
    };
  };
}
