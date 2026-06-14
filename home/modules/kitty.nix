# ---------------------------------------------------------------------------
# kitty.nix — Default terminal for Aegis-Dualis (Niri + Wayland)
#
# Power-user defaults: remote control, hints kitten, splits, huge scrollback,
# shell integration, clipboard, URL detection, broadcast input.
# Theme: Catppuccin Mocha via catppuccin.kitty (configured in home.nix).
# ---------------------------------------------------------------------------
{
  config,
  pkgs,
  isNixOS ? false,
  ...
}: let
  mocha = {
    base = "#1e1e2e";
    text = "#cdd6f4";
    mauve = "#cba6f7";
    surface0 = "#313244";
  };

  # On the current Arch host the pacman kitty build is preferred. On NixOS,
  # use nixpkgs so the system has a complete declarative closure.
  systemKitty = pkgs.symlinkJoin {
    name = "kitty-system";
    paths = [
      (pkgs.writeShellScriptBin "kitty" ''
        exec /usr/bin/kitty "$@"
      '')
      (pkgs.writeShellScriptBin "kitten" ''
        exec /usr/bin/kitten "$@"
      '')
    ];
  };

  kittyPackage =
    if isNixOS
    then pkgs.kitty
    else systemKitty;

  profileBin = "${config.home.profileDirectory}/bin";

  kittyFramework = pkgs.writeShellApplication {
    name = "kitty-framework";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      root="''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-$PWD}}"
      if [[ ! -f "$root/flake.nix" ]]; then
        root="$PWD"
      fi

      case "''${1:-shell}" in
        shell)
          exec ${kittyPackage}/bin/kitty --directory "$root"
          ;;
        develop)
          exec ${kittyPackage}/bin/kitty --directory "$root" \
            ${pkgs.zsh}/bin/zsh -lc 'nix develop; exec zsh'
          ;;
        check)
          exec ${kittyPackage}/bin/kitty --directory "$root" \
            ${pkgs.zsh}/bin/zsh -lc '"${profileBin}/hm-check"; exec zsh'
          ;;
        switch)
          exec ${kittyPackage}/bin/kitty --directory "$root" \
            ${pkgs.zsh}/bin/zsh -lc '"${profileBin}/hm"; exec zsh'
          ;;
        *)
          echo "Usage: kitty-framework [shell|develop|check|switch]" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  catppuccin.kitty.enable = true;

  programs.kitty = {
    enable = true;
    package = kittyPackage;
    shellIntegration.enableZshIntegration = true;
    settings = {
      # ── Identity / Wayland ───────────────────────────────────────────────
      linux_display_server = "wayland";
      term = "xterm-kitty";
      shell = "${pkgs.zsh}/bin/zsh";

      # ── Font ─────────────────────────────────────────────────────────────
      font_family = "JetBrainsMono Nerd Font";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      font_size = 14.0;
      adjust_line_height = 0;
      adjust_column_width = 0;
      disable_ligatures = "never";

      # ── Colors (Catppuccin module overrides palette; keep cursor/window) ─
      foreground = mocha.text;
      background = mocha.base;
      selection_foreground = mocha.base;
      selection_background = mocha.mauve;
      cursor = mocha.mauve;
      cursor_text_color = mocha.base;
      cursor_shape = "beam";
      cursor_beam_thickness = 2.0;
      cursor_blink_interval = 0.5;

      # ── Window chrome ────────────────────────────────────────────────────
      hide_window_decorations = "yes";
      window_padding_width = 10;
      window_margin_width = 0;
      background_opacity = 0.92;
      dynamic_background_opacity = true;
      background_blur = 0;
      confirm_os_window_close = 0;
      remember_window_size = true;
      initial_window_width = 1280;
      initial_window_height = 800;
      wayland_titlebar_color = "system";

      # ── Tabs ───────────────────────────────────────────────────────────────
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      tab_bar_min_tabs = 1;
      tab_bar_edge = "top";
      active_tab_font_style = "bold";
      inactive_tab_font_style = "medium";
      tab_activity_symbol = " ░";
      tab_title_template = "{index}: {title}";

      # ── Scrollback / performance ─────────────────────────────────────────
      scrollback_lines = 100000;
      scrollback_pager = "bat --style=plain --paging=always --color=always";
      wheel_scroll_min_lines = 1;
      wheel_scroll_multiplier = 3.0;
      touch_scroll_multiplier = 2.0;
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = true;
      enable_audio_bell = false;
      visual_bell_duration = 0.0;

      # ── Clipboard / URLs (recon logs, paste payloads safely) ─────────────
      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";
      select_by_word_characters = "@-./_~?&=%+:#";
      url_style = "curly";
      url_color = "#b4befe";
      open_url_with = "default";
      detect_urls = true;
      underline_hyperlinks = "always";

      # ── Remote control (automation, broadcast, icat) ───────────────────────
      allow_remote_control = "yes";
      listen_on = "unix:@kitty-aegis";
      env = "TERM=xterm-kitty";

      # ── Mouse ──────────────────────────────────────────────────────────────
      mouse_hide_wait = 3.0;
      focus_follows_mouse = "no";
      pointer_shape_when_grabbed = "arrow";

      # ── Advanced ───────────────────────────────────────────────────────────
      shell_integration = "enabled";
      allow_hyperlinks = true;
      paste_actions = "quote-urls-at-prompt,confirm";
      kitty_mod = "ctrl+shift";
    };

    extraConfig = ''
      # ── Sessions ─────────────────────────────────────────────────────────
      map ctrl+shift+enter new_window
      map ctrl+shift+t new_tab
      map ctrl+shift+q close_tab
      map ctrl+shift+w close_window
      map ctrl+shift+right next_tab
      map ctrl+shift+left previous_tab
      map ctrl+shift+. move_tab_forward
      map ctrl+shift+, move_tab_backward

      # ── Layout ───────────────────────────────────────────────────────────
      map ctrl+shift+n new_os_window
      map ctrl+shift+backslash launch --location=hsplit
      map ctrl+shift+d launch --location=vsplit
      map ctrl+shift+f move_window_forward
      map ctrl+shift+b move_window_backward

      # ── Font / zoom ──────────────────────────────────────────────────────
      map ctrl+shift+equal change_font_size all +1.0
      map ctrl+shift+minus change_font_size all -1.0
      map ctrl+shift+0 change_font_size all 0

      # ── Scrollback ───────────────────────────────────────────────────────
      map ctrl+shift+h show_scrollback
      map ctrl+shift+g show_last_command_output
      map ctrl+shift+delete clear_terminal reset active scrollback active

      # ── Search kitten (scrollback grep) ──────────────────────────────────
      map ctrl+f launch --location=hsplit --allow-remote-control kitty +kitten search.py @active-kitty-window-id
      map ctrl+shift+f launch --location=hsplit --allow-remote-control kitty +kitten search.py @active-kitty-window-id

      # ── Kittens (hints, broadcast) ───────────────────────────────────────
      map ctrl+shift+e kitten hints --type path --copy
      map ctrl+shift+o kitten hints --type url
      map ctrl+shift+p kitten hints --type hash --copy
      map ctrl+shift+y kitten hints --type line --copy
      map ctrl+shift+a kitten broadcast --match-tab active

      # ── Quick spawn (operator workflow) ──────────────────────────────────
      map ctrl+shift+alt+b launch --type=window --cwd=current btop
      map ctrl+shift+alt+y launch --type=window --cwd=current yazi
      map ctrl+shift+alt+f launch --type=window --cwd=current lazygit
      map ctrl+shift+alt+n launch --type=window --cwd=current nvim
      map ctrl+shift+alt+t launch --type=window --cwd=current tmux new -As main
      map ctrl+shift+alt+r launch --type=tab --tab-title=WHOcares kitty-framework shell
      map ctrl+shift+alt+d launch --type=tab --tab-title=Nix-develop kitty-framework develop
      map ctrl+shift+alt+c launch --type=tab --tab-title=HM-check kitty-framework check
      map ctrl+shift+alt+s launch --type=tab --tab-title=HM-switch kitty-framework switch

      # ── Scroll / zoom (extra bindings) ─────────────────────────────────────
      map ctrl+plus change_font_size all +1.0
      map ctrl+equal change_font_size all +1.0
      map ctrl+minus change_font_size all -1.0
      map ctrl+0 change_font_size all 0
      map page_up scroll_page_up
      map page_down scroll_page_down
      map ctrl+c copy_or_interrupt
    '';
  };

  # Prefer kitty when spawning terminals from apps (fuzzel, niri, etc.)
  home.file.".local/bin/x-terminal-emulator".source = "${kittyPackage}/bin/kitty";

  # Kitty terminfo for tmux/ssh sessions
  home.sessionVariables = {
    TERMINAL = "kitty";
    KITTY_CONFIG_DIRECTORY = "${config.xdg.configHome}/kitty";
    KITTY_LISTEN_ON = "unix:@kitty-aegis";
  };

  # kitty/kitten come from pacman on Arch and nixpkgs on NixOS.
  home.packages = [kittyFramework];

  programs.zsh.shellAliases = {
    k = "kitty";
    ktmux = "kitty -e tmux new -As main";
    icat = "kitten icat";
    kdiff = "kitten diff";
    kbroadcast = "kitten broadcast";
    kclone = "kitten clone-in-kitty";
    kssh = "kitten ssh";
    ka = "kitty-framework shell";
    kdev = "kitty-framework develop";
    kcheck = "kitty-framework check";
  };

  programs.nushell.extraConfig = ''
    alias k = kitty
    alias icat = ^kitten icat
    alias kdiff = ^kitten diff
    alias ka = kitty-framework shell
    alias kdev = kitty-framework develop
    alias kcheck = kitty-framework check
  '';

  xdg.dataFile."aegis/kitty-poweruser.md".text = ''
    # Kitty — Aegis-Dualis power-user reference

    ## Launch
    - `Mod+T` — new kitty (Niri)
    - `kitty` / `k` — default shell
    - `kitty -e btop` — one-shot command

    ## Kittens
    | Key / Cmd | Action |
    |-----------|--------|
    | `Ctrl+Shift+E` | hints → copy paths |
    | `Ctrl+Shift+O` | hints → open URLs |
    | `Ctrl+Shift+P` | hints → copy hashes |
    | `Ctrl+Shift+Y` | hints → copy line |
    | `Ctrl+Shift+A` | broadcast input to all panes in tab |
    | `icat file.png` | inline image preview |
    | `kdiff a b` | side-by-side diff |
    | `kclone` | clone session to new window |

    ## Quick spawn
    | Key | Action |
    |-----|--------|
    | `Ctrl+Shift+Alt+B` | btop |
    | `Ctrl+Shift+Alt+Y` | yazi |
    | `Ctrl+Shift+Alt+F` | lazygit |
    | `Ctrl+Shift+Alt+N` | nvim |
    | `Ctrl+Shift+Alt+R` | framework terminal |
    | `Ctrl+Shift+Alt+D` | `nix develop` tab |
    | `Ctrl+Shift+Alt+C` | Home Manager build tab |
    | `Ctrl+Shift+Alt+S` | Home Manager switch tab |
  '';
}
