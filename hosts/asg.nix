{ ... }:

{
  # Alpine SG work laptop (aarch64-darwin).

  # Per-machine git identity; the shared config intentionally sets none.
  programs.git.settings.user = {
    name = "Kevin Gisi";
    email = "kgisi@alpinesg.com";
  };
}
