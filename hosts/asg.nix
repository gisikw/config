{ ... }:

{
  # Alpine SG work laptop (aarch64-darwin).

  # Container runtime — work projects expect docker; podman fills in.
  imports = [ ../home/podman ];

  # Per-machine git identity; the shared config intentionally sets none.
  programs.git.settings.user = {
    name = "Kevin Gisi";
    email = "kgisi@alpinesg.com";
  };

  # Open Design: daemon (launchd, api on :7457) + bundled static SPA at
  # http://127.0.0.1:5174. Module comes from the open-design flake input.
  # BYOK secrets, if ever needed, go in environmentFile — not here.
  services.open-design = {
    enable = true;
    autoStart = true;
    webFrontend.enable = true;
    # The portal proxy (home/portal) also serves the SPA as
    # http://design.localhost; the daemon's same-origin gate needs to
    # know that origin or it 403s the SPA's writes.
    webFrontend.allowedOrigins = [ "http://design.localhost" ];
  };
}
