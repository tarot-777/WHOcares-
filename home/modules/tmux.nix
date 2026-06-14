# ---------------------------------------------------------------------------
# tmux.nix — Autonomous tmux + custom scratchpad (Nix-managed plugins)
#
# • continuum: auto-save + restore sessions across reboots
# • scratchpad: popup toggle (Alt+`) + persistent window (prefix + `)
# • Catppuccin theme via catppuccin.tmux (home.nix)
# ---------------------------------------------------------------------------
{pkgs, ...}: let
  tmuxBin = "${pkgs.tmux}/bin/tmux";

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
in {
  home.packages = [scratchToggle scratchBig tmuxMain];

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

      # ── Prefix highlight (catppuccin colors) ─────────────────────────────
      set -g @prefix_highlight_fg "#1e1e2e"
      set -g @prefix_highlight_bg "#cba6f7"
      set -g @prefix_highlight_copy_mode_attr "fg=#1e1e2e, bg=#a6e3a1"
      set -g @prefix_highlight_output_prefix "  "
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
      Type = "forking";
      ExecStart = "${tmuxBin} new-session -d -s main -c %h";
      ExecStop = "${tmuxBin} kill-server";
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
    scratch = "tmux-scratch";
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
    | `Ctrl+Space m` | attach/create `main` |
    | `tm` / `tmux-main` | attach or create main session |
  '';
}
