{ pkgs, lib, isDarwin ? false, ... }:

let
  baseConfig = ''
    set -g pane-base-index 1
    set -g renumber-windows on
    set -g allow-passthrough on
    set-option -g terminal-overrides ",xterm*:Tc"
    set -g focus-events on
  '';

  statusAndBorders = ''
    set-option -g status-position top
    set -g popup-border-style fg="#7cd5f1"
    set -g popup-border-lines rounded
    set -g pane-border-style fg="#7cd5f1"
    set -g pane-active-border-style fg="#7cd5f1"
    set -g status-style bg='#1d2528',fg='#7cd5f1'
    set -g message-style bg='#7cd5f1',fg='#1d2528'
    set -g window-status-format ""
    set -g window-status-current-format ""
    set -g status-left "#[bg=#7cd5f1,fg=#1d2528 bold] #(basename #{session_path}) #[default]#[bg=#3a4449,fg=#7cd5f1] #{} #{window_name} #{} #[bg=#1d2528,fg=#3a4449]"
    set -g status-left-length 40
    set -g status-right "#[fg=#3a4449]#[bg=#3a4449] #(tmux lsw -F \
      '##{?window_active,#[bg='#7cd5f1]#[fg='#1d2528'],#[bg='#3a4449']#[fg='#7cd5f1]} ##I ' | ${pkgs.findutils}/bin/xargs) "
    set -g status-right-length 40
  '';

  navigation = ''
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R
    bind-key -r H resize-pane -L 5
    bind-key -r J resize-pane -D 5
    bind-key -r K resize-pane -U 5
    bind-key -r L resize-pane -R 5
  '';

  fastRefreshHooks = ''
    set-hook -g after-select-window 'refresh-client -S'
    set-hook -g after-select-pane 'refresh-client -S'
    set-hook -g after-resize-pane 'refresh-client -S'
    set-hook -g after-split-window 'refresh-client -S'
    set-hook -g after-kill-pane 'refresh-client -S'
  '';

  keybindings = ''
    bind | split-window -h
    bind - split-window -v
    bind ` resize-pane -Z
    bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"
    bind t run-shell "tmux display -p 'stty cols #{pane_width} rows #{pane_height}' | ${pkgs.findutils}/bin/xargs -I{} tmux send-keys -l -- '{}'"
  '';

  fzfSessionSwitching = ''
    bind \\ display-popup -w 80% -h 80% -E "
      tmux list-sessions -F '#{?session_attached,,#{session_name}:::#{session_path}}' |
      ${pkgs.gnused}/bin/sed '/^$/d' |
      ${pkgs.gawk}/bin/awk -F ':::' '{split(\$2, parts, \"/\"); print \$1 \":::\" parts[length(parts)]}' |
      ${pkgs.fzf}/bin/fzf --reverse --header jump-to-session --with-nth=2 --delimiter=::: \
        --preview 'tmux capture-pane -p -e -t {1}' |
      ${pkgs.coreutils}/bin/cut -d ':' -f1 |
      ${pkgs.findutils}/bin/xargs tmux switch-client -t
    "
  '';

  # Host switching: { prev host, } next host
  # Works with tm wrapper - exit codes signal navigation
  hostSwitching = ''
    bind-key "}" detach-client -E "exit 10"
    bind-key "{" detach-client -E "exit 11"
  '';

  # PageUp/PageDown navigation - auto-enter copy mode
  # -u: scroll up one page on entry
  pageNavigation = ''
    bind-key -n PPage copy-mode -u
    bind-key -n NPage run ""
    bind-key -T copy-mode-vi NPage send-keys -X page-down \; if-shell -F "#{==:#{scroll_position},0}" "send-keys -X cancel" ""
  '';

  # Copy mode styling to match theme
  copyModeStyle = ''
    set -g mode-style bg=#7cd5f1,fg=#1d2528
    set -g copy-mode-match-style bg=#3a4449,fg=#7cd5f1
    set -g copy-mode-current-match-style bg=#7cd5f1,fg=#1d2528
  '';

in {
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    terminal = "tmux-256color";

    # On Darwin, use homebrew's tmux (nix tmux has PTY issues)
    # This creates a dummy package that doesn't install anything
    package = lib.mkIf isDarwin (pkgs.runCommand "tmux-homebrew" {} ''
      mkdir -p $out/bin
      echo '#!/bin/sh' > $out/bin/tmux
      echo 'exec /opt/homebrew/bin/tmux "$@"' >> $out/bin/tmux
      chmod +x $out/bin/tmux
    '');

    extraConfig = baseConfig + statusAndBorders + navigation + fastRefreshHooks + keybindings + fzfSessionSwitching + hostSwitching + pageNavigation + copyModeStyle;
  };
}
