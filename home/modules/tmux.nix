# ---------------------------------------------------------------------------
# tmux.nix — Autonomous tmux + custom scratchpad (Nix-managed plugins)
#
# • continuum: auto-save + restore sessions across reboots
# • scratchpad: popup toggle (Alt+`) + persistent window (prefix + `)
# • custom WHOcares! hot-pink / black / red / purple status theme
# ---------------------------------------------------------------------------
{pkgs, ...}: let
  tmuxBin = "${pkgs.tmux}/bin/tmux";
  theme = {
    bg = "#050006";
    bgAlt = "#120018";
    panel = "#21001f";
    pink = "#ff2bd6";
    pinkSoft = "#ff8ce6";
    red = "#ff1744";
    purple = "#a855f7";
    text = "#ffd6f4";
    muted = "#8e4f80";
  };

  scratchToggle = pkgs.writeShellScriptBin "tmux-scratch" ''
    set -euo pipefail
    if [ "$(tmux display -p '#{popup_is_visible}')" = "1" ]; then
      exec ${tmuxBin} dismiss-popup
    fi
    exec ${tmuxBin} display-popup \
      -d "#{pane_current_path}" \
      -E -w 88% -h 72% -x C -y C \
      ${pkgs.zsh}/bin/zsh
  '';

  scratchBig = pkgs.writeShellScriptBin "tmux-scratch-big" ''
    set -euo pipefail
    if [ "$(tmux display -p '#{popup_is_visible}')" = "1" ]; then
      exec ${tmuxBin} dismiss-popup
    fi
    exec ${tmuxBin} display-popup \
      -d "#{pane_current_path}" \
      -E -w 96% -h 92% -x C -y C \
      ${pkgs.zsh}/bin/zsh
  '';

  tmuxMain = pkgs.writeShellScriptBin "tmux-main" ''
    set -euo pipefail
    if ${tmuxBin} has-session -t main 2>/dev/null; then
      exec ${tmuxBin} attach -t main
    fi
    exec ${tmuxBin} new-session -s main -c "$HOME"
  '';

  tmuxOps = pkgs.writeShellScriptBin "tmux-ops" ''
    set -euo pipefail
    root="''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-$HOME/WHOcares!}}"
    if [[ ! -d "$root" ]]; then
      root="$HOME"
    fi

    if ${tmuxBin} has-session -t ops 2>/dev/null; then
      exec ${tmuxBin} attach -t ops
    fi

    ${tmuxBin} new-session -d -s ops -n guide -c "$root" \
      ${pkgs.zsh}/bin/zsh -lc 'fastfetch; echo; whocares-guide 2>/dev/null || daily; exec zsh'
    ${tmuxBin} new-window -t ops:2 -n git -c "$root" \
      ${pkgs.zsh}/bin/zsh -lc 'git status --short --branch; echo; exec zsh'
    ${tmuxBin} new-window -t ops:3 -n nix -c "$root" \
      ${pkgs.zsh}/bin/zsh -ic 'daily; echo; exec zsh'
    ${tmuxBin} new-window -t ops:4 -n logs -c "$root" \
      ${pkgs.zsh}/bin/zsh -lc 'journalctl -b -p warning..alert; echo; exec zsh'
    ${tmuxBin} select-window -t ops:1
    exec ${tmuxBin} attach -t ops
  '';

  tmuxServerStart = pkgs.writeShellScript "tmux-server-start" ''
    if ! ${tmuxBin} has-session -t main 2>/dev/null; then
      ${tmuxBin} new-session -A -d -s main -c "$HOME"
    fi
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
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-boot 'on'
          set -g @continuum-save-interval '5'
        '';
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
      # ── Terminal / Kitty integration ─────────────────────────────────────
      set -g default-terminal "tmux-256color"
      set -as terminal-features ",*:RGB"
      set -as terminal-features ",xterm-kitty:RGB"
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

      # ── Hot-pink / black / red / purple terminal theme ──────────────────
      set -g status-style "bg=${theme.bg},fg=${theme.text}"
      set -g status-left-length 80
      set -g status-right-length 140
      set -g status-left "#[fg=${theme.bg},bg=${theme.pink},bold] #S #[fg=${theme.pink},bg=${theme.bgAlt}]"
      set -g status-right "#[fg=${theme.muted},bg=${theme.bg}] %Y-%m-%d #[fg=${theme.purple},bold]%H:%M #[fg=${theme.bg},bg=${theme.red},bold] #h "
      set -g window-status-format "#[fg=${theme.muted},bg=${theme.bg}] #I:#W "
      set -g window-status-current-format "#[fg=${theme.bg},bg=${theme.purple},bold] #I:#W "
      set -g pane-border-style "fg=${theme.panel}"
      set -g pane-active-border-style "fg=${theme.pink}"
      set -g message-style "fg=${theme.text},bg=${theme.panel},bold"
      set -g mode-style "fg=${theme.bg},bg=${theme.pink},bold"
      set -g clock-mode-colour "${theme.pink}"

      # ── Prefix highlight ─────────────────────────────────────────────────
      set -g @prefix_highlight_fg "${theme.bg}"
      set -g @prefix_highlight_bg "${theme.pink}"
      set -g @prefix_highlight_copy_mode_attr "fg=${theme.bg}, bg=${theme.red}"
      set -g @prefix_highlight_output_prefix "  "
      set -g @prefix_highlight_output_suffix " "

      # ── SessionX ─────────────────────────────────────────────────────────
      set -g @sessionx-bind 'o'
      set -g @sessionx-preview-enabled 'on'
      set -g @sessionx-zoxide-mode 'on'

      # ── FZF tmux ─────────────────────────────────────────────────────────
      set -g @tmux-fzf-launch-key 'f'
      set -g @tmux-fzf-apply-key 'tab'

      # ── Extrakto (fuzzy copy) ────────────────────────────────────────────
      set -g @extrakto_key 'e'
      set -g @extrakto_insert_key 'Tab'

      # ── Thumbs (quick hint picker) ───────────────────────────────────────
      set -g @thumbs-key F

      # ── Resurrect / continuum ────────────────────────────────────────────
      set -g @resurrect-capture-pane-contents 'on'
      set -g @resurrect-strategy-vim 'session'
      set -g @resurrect-strategy-nvim 'session'
      set -g @resurrect-save 'S'

      # ── Scratchpad (popup + persistent window) ───────────────────────────
      # Alt+`  → toggle floating popup scratchpad (works from any pane)
      bind-key -n M-` run-shell "tmux-scratch"
      # Alt+Shift+` → large popup scratchpad
      bind-key -n M-S-` run-shell "tmux-scratch-big"
      # prefix + ` → persistent scratch window (survives popup dismiss)
      bind-key '`' if-shell "[ '#{window_name}' = 'scratch' ]" \
        "select-window -l" \
        "if-shell \"tmux list-windows -F '#{window_name}' | grep -qx scratch\" \
          'select-window -t :scratch' \
          'new-window -n scratch -c \"#{pane_current_path}\"'"

      # ── Splits / navigation ──────────────────────────────────────────────
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # ── Quick session attach ─────────────────────────────────────────────
      bind m run-shell "tmux attach -t main 2>/dev/null || tmux new-session -ds main -c '#{pane_current_path}'"
      bind O run-shell "tmux-ops"
      bind g display-popup -d "#{pane_current_path}" -E -w 92% -h 84% -x C -y C "whocares-guide | ${pkgs.less}/bin/less -R"
      bind D display-popup -d "#{pane_current_path}" -E -w 92% -h 84% -x C -y C "${pkgs.zsh}/bin/zsh -ic 'daily | ${pkgs.less}/bin/less -R'"

      # ── Reload / misc ────────────────────────────────────────────────────
      bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded"
      bind Tab last-window
      bind B break-pane -d
    '';
  };

  # Boot tmux server on graphical login; continuum restores the last layout.
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
    scratch = "tmux-scratch";
    tguide = "bat --style=plain ~/.local/share/aegis/tmux-poweruser.md";
  };

  xdg.dataFile."aegis/tmux-poweruser.md".text = ''
    # tmux — Aegis-Dualis reference

    Prefix: **Ctrl+Space**

    ## Autonomous mode
    - Server starts at login (`tmux-server` user service)
    - Continuum saves every 5 min + restores on boot
    - Resurrect captures pane contents (`Ctrl+Space Ctrl+s` save, `Ctrl+r` restore)
    - `tm` / `tmux-main` attaches or creates the main session

    ## Scratchpad
    | Key | Action |
    |-----|--------|
    | `Alt+\`` | Toggle popup scratchpad (88×72%, centered) |
    | `Alt+Shift+\`` | Large popup scratchpad (96×92%) |
    | `Ctrl+Space \`` | Persistent scratch **window** (toggle) |
    | `scratch` | CLI toggle popup from shell |

    ## Navigation
    | Key | Action |
    |-----|--------|
    | `Ctrl+Space \|` | split horizontal |
    | `Ctrl+Space -` | split vertical |
    | `Ctrl+Space o` | session picker (sessionx) |
    | `Ctrl+Space f` | fzf tmux launcher |
    | `Ctrl+Space g` | popup quick guide |
    | `Ctrl+Space D` | popup daily Nix guide |
    | `Ctrl+Space O` | attach/open ops dashboard session |
    | `Ctrl+Space m` | attach/create `main` |
    | `tm` / `tmux-main` | attach or create main session |
    | `td` / `tmux-ops` | hot-pink ops dashboard session |
  '';
}
