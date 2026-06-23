# ---------------------------------------------------------------------------
# tmux.nix — Autonomous multiplexer payload
#
# Hardened termcap overrides for Alacritty/Ghostty, optimized popups, and
# session persistence.
# ---------------------------------------------------------------------------
{
  config,
  flakeRoot ? null,
  pkgs,
  ...
}: let
  configuredFlakeRoot =
    if flakeRoot == null
    then "${config.home.homeDirectory}/WHOcares"
    else flakeRoot;

  tmuxBin = "${pkgs.tmux}/bin/tmux";
  theme = {
    bg = "#050006";
    bgAlt = "#120018";
    panel = "#21001f";
    pink = "#ff2bd6";
    red = "#ff1744";
    purple = "#a855f7";
    text = "#ffd6f4";
    muted = "#8e4f80";
  };

  # Script payload generator with hardened exception handling
  mkTmuxScript = name: body:
    pkgs.writeShellScriptBin name ''
      set -euo pipefail
      ${body}
    '';

  scratchToggle = mkTmuxScript "tmux-scratch" ''
    [ "$(${tmuxBin} display -p '#{popup_is_visible}')" = "1" ] && exec ${tmuxBin} dismiss-popup
    exec ${tmuxBin} display-popup -d "#{pane_current_path}" -E -w 88% -h 72% -x C -y C ${pkgs.zsh}/bin/zsh
  '';

  scratchBig = mkTmuxScript "tmux-scratch-big" ''
    [ "$(${tmuxBin} display -p '#{popup_is_visible}')" = "1" ] && exec ${tmuxBin} dismiss-popup
    exec ${tmuxBin} display-popup -d "#{pane_current_path}" -E -w 96% -h 92% -x C -y C ${pkgs.zsh}/bin/zsh
  '';

  tmuxMain = mkTmuxScript "tmux-main" ''
    ${tmuxBin} has-session -t main 2>/dev/null && exec ${tmuxBin} attach -t main
    exec ${tmuxBin} new-session -s main -c "$HOME"
  '';

  tmuxOps = mkTmuxScript "tmux-ops" ''
    root="''${WHOCARES_FLAKE:-${configuredFlakeRoot}}"
    [ ! -d "$root" ] && root="$HOME"
    ${tmuxBin} has-session -t ops 2>/dev/null && exec ${tmuxBin} attach -t ops

    ${tmuxBin} new-session -d -s ops -n guide -c "$root" ${pkgs.zsh}/bin/zsh -lc 'fastfetch; echo; whocares-guide 2>/dev/null || daily; exec zsh'
    ${tmuxBin} new-window -t ops:2 -n git -c "$root" ${pkgs.zsh}/bin/zsh -lc 'git status --short --branch; echo; exec zsh'
    ${tmuxBin} new-window -t ops:3 -n nix -c "$root" ${pkgs.zsh}/bin/zsh -ic 'daily; echo; exec zsh'
    ${tmuxBin} new-window -t ops:4 -n logs -c "$root" ${pkgs.zsh}/bin/zsh -lc 'journalctl -b -p warning..alert; echo; exec zsh'
    ${tmuxBin} select-window -t ops:1
    exec ${tmuxBin} attach -t ops
  '';

  tmuxServerStart = pkgs.writeShellScript "tmux-server-start" ''
    ! ${tmuxBin} has-session -t main 2>/dev/null && ${tmuxBin} new-session -A -d -s main -c "$HOME"
  '';

  tmuxServerStop = pkgs.writeShellScript "tmux-server-stop" ''
    ${tmuxBin} kill-server 2>/dev/null || true
  '';
in {
  home.packages = [scratchToggle scratchBig tmuxMain tmuxOps];

  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    historyLimit = 100000;
    keyMode = "vi";
    prefix = "C-Space";
    escapeTime = 0;
    mouse = true;
    sensibleOnTop = false;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      {
        plugin = continuum;
        extraConfig = "set -g @continuum-restore 'on'\nset -g @continuum-boot 'on'\nset -g @continuum-save-interval '5'";
      }
      copycat
      open
      vim-tmux-navigator
      extrakto
      mode-indicator
      prefix-highlight
      tmux-fzf
      tmux-sessionx
      pain-control
      tmux-thumbs
    ];

    extraConfig = ''
      set -g default-terminal "tmux-256color"
      set -as terminal-features ",*:RGB"
      set -as terminal-overrides ",alacritty:RGB,ghostty:RGB"
      set -g allow-passthrough on
      set -g focus-events on
      set -g status-position top
      set -g base-index 1
      set -g pane-base-index 1
      set -g renumber-windows on
      set -g detach-on-destroy off
      set -g set-clipboard on
      set -g automatic-rename on
      set -g aggressive-resize on

      set -g status-style "bg=${theme.bg},fg=${theme.text}"
      set -g status-left-length 80
      set -g status-right-length 140
      set -g status-left "#[fg=${theme.bg},bg=${theme.pink},bold] #S #[fg=${theme.pink},bg=${theme.bgAlt}]"
      set -g status-right "#[fg=${theme.muted},bg=${theme.bg}] %Y-%m-%d #[fg=${theme.purple},bold]%H:%M #[fg=${theme.bg},bg=${theme.red},bold] #h "
      set -g window-status-format "#[fg=${theme.muted},bg=${theme.bg}] #I:#W "
      set -g window-status-current-format "#[fg=${theme.bg},bg=${theme.purple},bold] #I:#W "
      set -g pane-border-style "fg=${theme.panel}"
      set -g pane-active-border-style "fg=${theme.pink}"

      bind-key -n M-` run-shell "tmux-scratch"
      bind-key -n M-S-` run-shell "tmux-scratch-big"

      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind m run-shell "tmux attach -t main 2>/dev/null || tmux new-session -ds main -c '#{pane_current_path}'"
      bind O run-shell "tmux-ops"
      bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded"
    '';
  };

  systemd.user.services.tmux-server = {
    Unit = {
      Description = "Tmux server (continuum restore)";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = tmuxServerStart;
      ExecStop = tmuxServerStop;
      RemainAfterExit = true;
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  programs.zsh.shellAliases = {
    t = "tmux";
    ta = "tmux attach -t";
    tl = "tmux list-sessions";
    ts = "tmux new-session -s";
    tm = "tmux-main";
    td = "tmux-ops";
  };
}
