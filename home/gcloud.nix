{ pkgs, ... }:

# gcloud insists on a system python, which is not a thing this machine
# has on PATH — deliberately. So `gcloud` here is a wrapper that realizes
# google-cloud-sdk (python and all) into an ephemeral `nix shell` and
# forwards the args; the SDK's closure never joins the profile and stays
# garbage-collectable. First run pays the fetch, after that it's cached.
#
# path:${pkgs.path} pins the wrapper to this flake's nixpkgs rather than
# the registry's floating one, so the SDK version moves with flake.lock.
# Credentials land in ~/.config/gcloud as usual, so ADC
# (`gcloud auth application-default login`) survives across invocations.
#
# If gsutil/bq ever earn a spot, they're in the same package — add
# wrappers here, same shape.
{
  home.packages = [
    (pkgs.writeShellScriptBin "gcloud" ''
      exec nix shell path:${pkgs.path}#google-cloud-sdk --command gcloud "$@"
    '')
  ];
}
