{ config, pkgs, ... }:

# Podman standing in for Docker (host-selected; currently just asg).
#
# On darwin the nixpkgs podman package is only the client — `podman
# machine` additionally needs vfkit (the applehv VM runner) and gvproxy
# (VM networking), which podman locates via helper_binaries_dir rather
# than PATH; point it at the home-manager profile where those land.
#
# One-time per machine: `podman machine init && podman machine start`
# (downloads the VM image). `podman machine start` prints the
# DOCKER_HOST export for tools that speak to the Docker API socket
# directly; the `docker` alias covers CLI muscle memory.

{
  home.packages = with pkgs; [
    podman
    podman-compose
    vfkit
    gvproxy
  ];

  xdg.configFile."containers/containers.conf".text = ''
    [engine]
    helper_binaries_dir = ["${config.home.profileDirectory}/bin"]
  '';

  home.shellAliases.docker = "podman";
}
