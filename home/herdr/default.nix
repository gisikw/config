{ ... }:

{
  # Read-only symlink: herdr's in-app settings UI (and onboarding flow)
  # write to this file, so those in-app edits will fail — change settings
  # here instead and `herdr server reload-config`.
  xdg.configFile."herdr/config.toml".source = ./config.toml;
}
