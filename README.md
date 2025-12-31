# ~/.config

Personal configuration managed with [Nix Home Manager](https://github.com/nix-community/home-manager).

## Setup

### 1. Install Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

This uses the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer), which enables flakes by default and provides a cleaner uninstall path than the official installer.

### 2. Clone this repo

The repo can live anywhere, but `~/.config` keeps things tidy and lets the `config` shell alias work out of the box:

```bash
git clone git@github.com:gisikw/config.git ~/.config
```

### 3. Apply the configuration

```bash
nix run home-manager -- switch --flake ~/.config#gisikw@macbook
```

This bootstraps home-manager and applies the configuration in one step. After the first run, `home-manager` will be in your PATH:

```bash
home-manager switch --flake ~/.config#gisikw@macbook
```

## Available configurations

| Name | System | Description |
|------|--------|-------------|
| `gisikw@macbook` | aarch64-darwin | Personal MacBook |
| `gisikw@calendly` | aarch64-darwin | Work MacBook |
| `dev@ratched` | x86_64-linux | Homelab dev sandbox |

## Using as a flake input

From another flake (e.g., a NixOS configuration):

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager";
    dotfiles.url = "github:gisikw/config";
  };

  outputs = { nixpkgs, home-manager, dotfiles, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      # ...
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.dev = {
            imports = [ dotfiles.homeManagerModules.default ];
          };
        }
      ];
    };
  };
}
```

## What's included

- **Git** - Aliases: `co` (checkout), `up` (push current branch), `down` (pull current branch)
- **Tmux** - Prefix `C-a`, vi mode, FZF session switching, monokai-inspired status bar
- **Neovim** - Full Lua config with lazy.nvim, LSP, Treesitter, Telescope
- **Zsh** - Custom prompt with git status, `config` helper, `skyhook`/`skydive` data transfer utils
- **Ghostty** - Terminal configuration
- **Sway** - Wayland window manager (Linux only)

## Shell utilities

After applying the configuration:

- `config` - Shorthand for git operations on this repo (`config status`, `config add .`, etc.)
- `skyhook` - Receive encrypted data via SSH tunnel
- `skydive` - Send encrypted data via SSH tunnel
