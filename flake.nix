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
    # Open Design (https://open-design.ai) — local-first design tool
    # driven by the agent CLIs on PATH. Ships its own home-manager
    # module; like herdr it builds against its own pinned nixpkgs.
    # Enabled per-host via services.open-design.
    open-design.url = "github:nexu-io/open-design";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, herdr, open-design, ... }:
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
            open-design.homeManagerModules.default
            module
            {
              # Upstream's daemon build lists the node-gyp toolchain
              # (python3/gnumake/pkg-config) but misses Apple libtool,
              # which the better-sqlite3 static-archive step needs on
              # darwin. Graft cctools in until fixed upstream.
              services.open-design.package =
                nixpkgs.lib.mkIf pkgs.stdenv.isDarwin
                  (open-design.packages.${system}.daemon.overrideAttrs (old: {
                    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.cctools ];
                  }));
            }
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
