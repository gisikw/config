# config

Personal configuration managed with [Nix Home Manager](https://github.com/nix-community/home-manager).

## Layout

```
flake.nix    # inputs + one homeConfiguration per machine
hosts/       # per-machine modules (git identity, quirks); keyed "user@hostname"
home/        # shared modules: git, tmux, neovim, zsh, ghostty, sway (Linux)
home/zsh/    # zsh module; shell code lives in real .zsh files, not nix strings
```

Packages that come from flake inputs (e.g. herdr) are added in `flake.nix`
itself, so `homeManagerModules.default` stays consumable from other flakes.

Host entries are named `user@hostname` so `home-manager` (and the `config
switch` helper) can resolve the right configuration from the environment —
no profile sidecar file.

## Bootstrap a new machine

1. **Install Nix** via the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
   (flakes enabled by default, clean uninstall path):

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **Clone this repo** (nix can provide git before the system has it):

   ```bash
   nix shell nixpkgs#git -c git clone git@github.com:gisikw/config.git ~/Projects/config
   ```

3. **Add the machine** as a `hosts/` module and a `user@hostname` entry in
   `flake.nix` (skip if it already exists), then apply:

   ```bash
   nix run github:nix-community/home-manager/release-26.05 -- \
     switch -b hm-bak --flake ~/Projects/config#user@hostname
   ```

   After the first run `home-manager` is on PATH and `config switch` does this
   for you.

## Machines

| Name | System | Description |
|------|--------|-------------|
| `gisikw@asg` | aarch64-darwin | Alpine SG work laptop |
| `gisikw@macbook` | aarch64-darwin | Personal MacBook |
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
- **Zsh** - Custom prompt with git status, `config switch` helper, `skyhook`/`skydive` data transfer utils
- **Herdr** - Terminal agent multiplexer ([herdr.dev](https://herdr.dev)), via
  its upstream flake; config ported from the tmux setup (splits, zoom, session
  navigator, theme)
- **Skills** - agent skills fetched straight from their source repos, pinned by
  rev + content hash (the [allium](https://github.com/juxt/allium) suite with
  its CLI built from source, Anthropic's frontend-design), linked into
  `~/.claude/skills` and `~/.agents/skills` so claude/codex/opencode all
  discover them
- **Agent CLIs** - `claude`, `codex`, `opencode`, `pi`, plus `ccusage` for usage
  reporting across all four; pulled from nixpkgs-unstable so `nix flake update`
  tracks their release pace
- **Ghostty** - Terminal configuration
- **Rectangle** (macOS) - window manager with SizeUp's keybindings (halves
  ⌃⌥⌘-arrows, quarters ⌃⌥⇧-arrows, full screen ⌃⌥⌘M, monitors ⌃⌥-arrows),
  configured declaratively; the app ships from the upstream signed .dmg so
  the Accessibility grant survives updates
- **Peck** (macOS) - push-to-toggle dictation in the menu bar: Caps Lock
  (remapped to F18 via hidutil) starts/stops recording (Shift pauses,
  Ctrl cancels), NVIDIA Parakeet transcribes locally (MLX, streaming in
  1s chunks while you talk), and the text is typed into the focused app
- **Sway** - Wayland window manager (Linux only)

## Shell utilities

After applying the configuration:

- `config switch [user@host]` - Apply this flake (defaults to current `user@hostname`)
- `skyhook` - Receive encrypted data via SSH tunnel
- `skydive` - Send encrypted data via SSH tunnel
