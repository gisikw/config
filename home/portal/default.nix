{ lib, pkgs, ... }:

# Friendly loopback names for local web UIs, so ports don't have to be
# memorized: http://ccr.localhost instead of http://127.0.0.1:3458.
#
# /etc/hosts can't express ports (and standalone home-manager can't
# write it anyway), so this is a tiny caddy on 127.0.0.1:80 that
# reverse-proxies per hostname. Browsers resolve *.localhost to
# loopback on their own — no resolver changes needed. For curl, use
# `curl -H "Host: ccr.localhost" 127.0.0.1`. macOS allows unprivileged
# binds below 1024, which is why this can be a plain user agent;
# that's also why the module is darwin-only.
#
# Add an entry here whenever a new local service grows a UI.

let
  portals = {
    ccr = 3458; # claude-code-router management UI (flake.nix)
    design = 5174; # open-design web frontend (services.open-design)
  };

  caddyfile = pkgs.writeText "portal.Caddyfile" ''
    {
      auto_https off
      admin off
      persist_config off
    }
    ${lib.concatStrings (lib.mapAttrsToList (name: port: ''
      http://${name}.localhost:80 {
        reverse_proxy 127.0.0.1:${toString port} {
          # Loopback services allowlist the Host header (ccr 403s
          # otherwise); present the address they expect. Browser
          # Origin checks are each service's own business — see
          # open-design's allowedOrigins in hosts/*.nix.
          header_up Host 127.0.0.1:${toString port}
        }
      }
    '') portals)}
  '';
in {
  launchd.agents.portal = {
    enable = true;
    config = {
      Label = "local.portal";
      ProgramArguments = [
        (lib.getExe pkgs.caddy)
        "run"
        "--config"
        "${caddyfile}"
        "--adapter"
        "caddyfile"
      ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
