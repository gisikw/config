{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # Agent CLIs move too fast for release channels (26.05 lags them by
    # months); they come from unstable, and `nix flake update` re-pins.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Terminal agent multiplexer (https://herdr.dev). Not in nixpkgs;
    # intentionally does not follow our nixpkgs — it builds with its own
    # pinned toolchain (rust-overlay).
    herdr.url = "github:ogulcancelik/herdr";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, herdr, ... }:
    let
      # One entry per machine, keyed "user@hostname" so that
      # `home-manager switch --flake <repo>` resolves the right config
      # from the environment — no profile sidecar file needed.
      hosts = {
        "gisikw@asg" = {
          system = "aarch64-darwin";
          username = "gisikw";
          module = ./hosts/asg.nix;
        };
        "gisikw@macbook" = {
          system = "aarch64-darwin";
          username = "gisikw";
          module = ./hosts/macbook.nix;
        };
        "dev@ratched" = {
          system = "x86_64-linux";
          username = "dev";
          module = ./hosts/ratched.nix;
        };
      };

      mkHome = { system, username, module }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgsUnstable = import nixpkgs-unstable {
            inherit system;
            # claude-code is the only unfree package we take.
            config.allowUnfreePredicate = pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
          };
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            isDarwin = pkgs.stdenv.isDarwin;
            isLinux = pkgs.stdenv.isLinux;
          };
          modules = [
            ./home
            module
            {
              home.username = username;
              home.homeDirectory =
                if pkgs.stdenv.isDarwin
                then "/Users/${username}"
                else "/home/${username}";

              # Flake-input packages live here rather than in ./home so that
              # homeManagerModules.default stays usable from other flakes.
              home.packages = [ herdr.packages.${system}.default ]
                # Agent CLIs + ccusage (usage reporting; reads each agent's
                # default log dirs, so no per-tool config is needed).
                ++ (with pkgsUnstable; [
                  claude-code
                  codex
                  opencode
                  pi-coding-agent
                  ccusage
                ]);
            }
          ];
        };
    in {
      homeConfigurations = builtins.mapAttrs (_: mkHome) hosts;

      homeManagerModules.default = import ./home;
    };
}
