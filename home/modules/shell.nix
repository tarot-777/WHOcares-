{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.whycare.shell;

  fastfetchConfig = pkgs.writeText "whocares-fastfetch.jsonc" (builtins.toJSON {
    logo = {
      type = "small";
      padding = {
        top = 1;
        right = 2;
      };
    };
    display = {
      separator = "  ";
      color = "magenta";
      keyWidth = 12;
    };
    modules = [
      "title"
      {
        type = "custom";
        key = "Framework";
        format = "WHOcares!";
      }
      {
        type = "custom";
        key = "Daily";
        format = "guide | daily | hmb | hms | nfc | osb | oss | wxd";
      }
      "separator"
      "os"
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "wm"
      "terminal"
      "cpu"
      "gpu"
      "memory"
      "disk"
      "localip"
    ];
  });

  guideText = pkgs.writeText "whocares-guide.txt" ''
    WHOcares! quick guide
    =====================

    First commands
      guide, aliases     show this guide
      daily, ndaily      Nix/Home Manager/NixOS daily workflow guide
      zpl                show Nix-managed Zsh plugin inventory
      awesome, tcheck    tool inventory and PATH audit

    Navigation and editing
      cfg, dots          jump to the configured WHOcares! flake
      whocares-cd        jump to the nearest flake root
      whocares-edit      open the nearest flake root in $EDITOR
      mkcd DIR           create and enter a directory
      cdf                fuzzy directory jump
      git-root           jump to the current Git repository root

    Nix and Home Manager
      nfc                nix flake check --no-build --show-trace
      nfmt, naudit       format, then audit with Deadnix and Statix
      nhealth            flake outputs plus Home Manager build
      hmb, hmc           Home Manager build
      hms                Home Manager switch
      hmu                update flake inputs, then Home Manager switch
      nup, ngc           update inputs, collect old generations
      nfind, nopt        package and option search

    NixOS host
      target             print path:<flake>#<host>
      osb                nixos-rebuild build
      ost                nixos-rebuild test
      osboot             nixos-rebuild boot
      oss, os            nixos-rebuild switch
      osdry              nixos-rebuild dry-build
      osvm               nixos-rebuild build-vm

    System logs
      bootlog            warning-or-worse logs from current boot
      userlog            warning-or-worse user-service logs from current boot
      sc, scu            systemctl / systemctl --user
      jc, jcu            journalctl / journalctl --user

    Default apps
      terminal           Kitty through xdg-terminal-exec and kitty.desktop
      dashboard          WHOcares Terminal Dashboard launcher
      browser            Qutebrowser for http, https, html, xhtml
      files              Dolphin for directories
      editor             Neovim inside Kitty for text, code, json, nix, shell
      media              Celluloid/mpv for audio and video
      images             imv for png, jpeg, webp

    Kitty
      k                  launch Kitty
      ka                 Kitty at the framework root
      kdev               Kitty tab running nix develop
      kcheck             Kitty tab running Home Manager build
      kswitch            Kitty tab running Home Manager switch
      kdash              hot-pink ops dashboard
      ktmux              Kitty running tmux main
      ktops              Kitty attached to the tmux ops dashboard
      icat, kdiff        Kitty image preview and diff kittens
      khints, kclip      hints and clipboard kittens
      kgrep, kssh        hyperlinked grep and SSH kittens
      ktheme, kunicode   theme browser and Unicode picker
      ktransfer, kkeys   transfer files and inspect key codes

    tmux
      tm, td             main session and ops dashboard session
      scratch            centered popup scratchpad
      tguide             tmux guide
      Prefix             Ctrl+Space
      Alt+`              popup scratchpad
      Alt+Shift+`        large popup scratchpad
      Prefix+o           session picker
      Prefix+f           tmux-fzf launcher
      Prefix+e           fuzzy extract/copy
      Prefix+F           tmux-thumbs hints

    Full references
      ~/.local/share/aegis/kitty-poweruser.md
      ~/.local/share/aegis/tmux-poweruser.md
      ~/.local/share/aegis/whocares-guide.txt
  '';

  guide = pkgs.writeShellScriptBin "whocares-guide" ''
    exec ${pkgs.coreutils}/bin/cat ${guideText}
  '';

  banner = pkgs.writeShellScriptBin "whycare-banner" ''
    set -euo pipefail
    host=$(${pkgs.coreutils}/bin/cat /proc/sys/kernel/hostname 2>/dev/null || echo unknown)
    root="''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-/home/malachi/WHOcares!}}"
    hotpink=$'\033[38;2;255;43;214m'
    red=$'\033[38;2;255;23;68m'
    purple=$'\033[38;2;168;85;247m'
    dim=$'\033[38;2;142;79;128m'
    reset=$'\033[0m'

    ${pkgs.fastfetch}/bin/fastfetch --config ${fastfetchConfig} || true

    printf '%s\n' \
      "" \
      "  ''${hotpink}WHOcares!''${reset} :: ''${purple}$host''${reset}" \
      "  ''${dim}root:''${reset} $root" \
      "  ''${red}------------------------------------------------------------''${reset}" \
      "  ''${hotpink}guide''${reset}   -> aliases, functions, Kitty, tmux quick reference" \
      "  ''${hotpink}daily''${reset}   -> Nix, Home Manager, and NixOS shortcut guide" \
      "  ''${purple}hmb''${reset}     -> Home Manager build        ''${purple}hms''${reset}    -> Home Manager switch" \
      "  ''${purple}nfc''${reset}     -> flake check, no build     ''${purple}hmu''${reset}    -> update inputs + switch" \
      "  ''${red}osb''${reset}     -> NixOS build               ''${red}ost''${reset}    -> NixOS test" \
      "  ''${red}oss''${reset}     -> NixOS switch              ''${red}osboot''${reset} -> NixOS boot entry" \
      "  ''${hotpink}kdash''${reset}   -> Kitty ops dashboard       ''${hotpink}td''${reset}     -> tmux ops dashboard" \
      "  ''${purple}wx''${reset}      -> start Whonix              ''${purple}wxd''${reset}    -> Whonix readiness check" \
      ""
  '';
in {
  options.whycare = {
    enableFullPower = mkEnableOption "heavy WHOcares packages";
    shell.enable = mkEnableOption "WHOcares shell extras";
  };

  config = mkIf cfg.enable {
    home.packages = [
      banner
      guide
      pkgs.fastfetch
    ];

    xdg.configFile."fastfetch/config.jsonc".source = fastfetchConfig;
    xdg.dataFile."aegis/whocares-guide.txt".source = guideText;

    programs.zsh.initContent = mkAfter ''
      if [[ -o interactive ]] && [[ -z "''${WHYCARE_BANNER_SHOWN:-}" ]]; then
        export WHYCARE_BANNER_SHOWN=1
        whycare-banner
      fi
    '';
  };
}
