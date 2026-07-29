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

          # claude-code-router v3, packaged locally from the npm tarball
          # (nixpkgs is stuck on 2.0.0).
          ccrPackage = pkgs.callPackage ./pkgs/claude-code-router { };

          # `claude` goes through claude-code-router (ccr), a local model
          # gateway that can retarget Claude Code at other providers. v3
          # is configured in its web UI (`ccr ui`, management on :3458):
          # add a provider + model, create a client key under API Keys,
          # then drop that key into ~/.claude-code-router/claude.env as
          #   ANTHROPIC_BASE_URL=http://127.0.0.1:3456
          #   ANTHROPIC_AUTH_TOKEN=<client key>
          # While that file exists the wrapper adopts its env (the
          # gateway itself runs as a boot service; see launchd/systemd
          # below); without it claude runs direct.
          claudeBin = "${pkgsUnstable.claude-code}/bin/claude";
          claudeRouted = pkgs.writeShellScriptBin "claude" ''
            env_file="$HOME/.claude-code-router/claude.env"
            if [ -f "$env_file" ]; then
              set -a; . "$env_file"; set +a
            fi
            exec ${claudeBin} "$@"
          '';
          # Recovery mode: ccr injects managed gateway settings into
          # ~/.claude/settings.json, so bypassing the router takes more
          # than skipping claude.env — claude-direct runs from its own
          # sparse config dir (reset to declared state by home/claude on
          # every switch) and scrubs any gateway env inherited from the
          # shell. Login state is gated by the .claude.json state file,
          # not the Keychain item alone, so seed it from the primary
          # copy on first run to start authenticated.
          claudeDirect = pkgs.writeShellScriptBin "claude-direct" ''
            unset ANTHROPIC_BASE_URL ANTHROPIC_API_BASE_URL \
              CLAUDE_AGENT_API_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY
            export CLAUDE_CONFIG_DIR="$HOME/.claude-direct"
            if [ ! -f "$CLAUDE_CONFIG_DIR/.claude.json" ] && [ -f "$HOME/.claude.json" ]; then
              mkdir -p "$CLAUDE_CONFIG_DIR"
              cp "$HOME/.claude.json" "$CLAUDE_CONFIG_DIR/.claude.json"
            fi
            exec ${claudeBin} "$@"
          '';
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

              # The ccr gateway + management UI as a boot service.
              # `ccr serve` is upstream's documented foreground mode for
              # process supervision. On a machine where no provider is
              # configured yet, serve exits at ccr's provider gate and
              # the supervisor throttles the respawns — bootstrap once
              # with `ccr ui`, then it stays healthy.
              launchd.agents.ccr = nixpkgs.lib.mkIf pkgs.stdenv.isDarwin {
                enable = true;
                config = {
                  Label = "com.musistudio.ccr";
                  ProgramArguments = [ "${ccrPackage}/bin/ccr" "serve" "--no-open" ];
                  RunAtLoad = true;
                  KeepAlive = true;
                  StandardOutPath =
                    "/Users/${username}/.claude-code-router/logs/serve.out.log";
                  StandardErrorPath =
                    "/Users/${username}/.claude-code-router/logs/serve.err.log";
                };
              };
              systemd.user.services.ccr = nixpkgs.lib.mkIf pkgs.stdenv.isLinux {
                Unit.Description = "claude-code-router gateway + management UI";
                Install.WantedBy = [ "default.target" ];
                Service = {
                  ExecStart = "${ccrPackage}/bin/ccr serve --no-open";
                  Restart = "on-failure";
                  RestartSec = 3;
                };
              };

              # Flake-input packages live here rather than in ./home so that
              # homeManagerModules.default stays usable from other flakes.
              home.packages = [
                herdr.packages.${system}.default
                claudeRouted # wraps pkgsUnstable.claude-code; see above
                claudeDirect
                ccrPackage
              ]
                # Agent CLIs + ccusage (usage reporting; reads each agent's
                # default log dirs, so no per-tool config is needed).
                ++ (with pkgsUnstable; [
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
