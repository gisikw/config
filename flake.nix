{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      mkHome = { system, username }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            isDarwin = pkgs.stdenv.isDarwin;
            isLinux = pkgs.stdenv.isLinux;
          };
          modules = [
            ./home
            {
              home.username = username;
              home.homeDirectory =
                if pkgs.stdenv.isDarwin
                then "/Users/${username}"
                else "/home/${username}";
            }
          ];
        };
    in {
      homeConfigurations = {
        "gisikw@macbook" = mkHome {
          system = "aarch64-darwin";
          username = "gisikw";
        };
        "gisikw@calendly" = mkHome {
          system = "aarch64-darwin";
          username = "gisikw";
        };
        "dev@ratched" = mkHome {
          system = "x86_64-linux";
          username = "dev";
        };
      };

      homeManagerModules.default = import ./home;
    };
}
