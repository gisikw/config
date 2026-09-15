{ config, lib, herdrBrowserSrc ? null, pkgs, ... }:

{
  # Read-only symlink: herdr's in-app settings UI (and onboarding flow)
  # write to this file, so those in-app edits will fail — change settings
  # here instead and `herdr server reload-config`.
  xdg.configFile."herdr/config.toml".source = ./config.toml;

  # herdr-browser paints a real Chromium into a pane, streamed over CDP.
  # It declares no runtime dependencies and none are implied — every import
  # in its tree is relative, node: or bun: — and all of its mutable state
  # lands under $HERDR_PLUGIN_STATE_DIR. So bun runs the checkout in place,
  # read-only, straight out of the store: no build step, no `bun install`,
  # nothing to vendor.
  #
  # Chrome itself is deliberately not declared. The plugin probes PATH and
  # the usual macOS app bundles, and pinning a nixpkgs chromium would mean
  # a second browser on machines that already have one.
  home.packages = lib.optionals (herdrBrowserSrc != null) [ pkgs.bun ];

  # Plugins live in herdr's own registry (~/.config/herdr/plugins.json),
  # not in config.toml — upstream expects `herdr plugin install`. herdr
  # rewrites that registry itself as it revalidates manifests, so assert a
  # single entry into it rather than symlinking the file from the store;
  # that also leaves room for plugins installed by hand.
  #
  # `link` is keyed by plugin id and overwrites the recorded path, which is
  # what makes this idempotent as the store path churns. It writes the
  # registry directly and does not need — or start — a running server.
  #
  # After installPackages, not writeBoundary: the herdr binary comes from a
  # flake input by way of home.packages, and the activation PATH does not
  # include the profile.
  home.activation.herdrBrowserPlugin = lib.mkIf (herdrBrowserSrc != null)
    (lib.hm.dag.entryAfter [ "installPackages" ] ''
      herdrBin="${config.home.profileDirectory}/bin/herdr"
      if [ -x "$herdrBin" ]; then
        run "$herdrBin" plugin link ${herdrBrowserSrc} --enabled > /dev/null \
          || warnEcho "herdr-browser: plugin link failed"
      fi
    '');
}
