# ---------------------------------------------------------------------------
# desktop.nix — Niri / DMS / Qutebrowser integration layer
# ---------------------------------------------------------------------------
{
  config,
  inputs,
  isNixOS ? false,
  lib,
  pkgs,
  ...
}: let
  dmsPkgs = inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system};
  dmsPackage = dmsPkgs.dms-shell;
  quickshellPackage = dmsPkgs.quickshell;

  sessionEnvNames = [
    "DISPLAY"
    "WAYLAND_DISPLAY"
    "XDG_CURRENT_DESKTOP"
    "XDG_SESSION_DESKTOP"
    "XDG_SESSION_TYPE"
    "NIXOS_OZONE_WL"
    "QT_QPA_PLATFORM"
    "QT_QPA_PLATFORMTHEME"
    "QT_STYLE_OVERRIDE"
    "QT_WAYLAND_DISABLE_WINDOWDECORATION"
    "GDK_BACKEND"
    "MOZ_ENABLE_WAYLAND"
    "XCURSOR_THEME"
    "XCURSOR_SIZE"
    "PATH"
  ];

  dmsInitialSession = pkgs.writeText "whocares-dms-session.json" (builtins.toJSON {
    wallpaperPath = "${config.stylix.image}";
    wallpaperPathDark = "${config.stylix.image}";
    wallpaperPathLight = "${config.stylix.image}";
    showThirdPartyPlugins = true;
  });
  dmsInitialSettings = pkgs.writeText "whocares-dms-settings.json" (builtins.toJSON {
    configVersion = 5;
    currentThemeName = "dynamic";
    currentThemeCategory = "system";
    matugenScheme = "scheme-vibrant";
    runUserMatugenTemplates = true;
    iconTheme = "Papirus-Dark";
    cursorSettings = {
      theme = "catppuccin-mocha-dark-cursors";
      size = 24;
      niri = {
        hideWhenTyping = true;
        hideAfterInactiveMs = 3000;
      };
      hyprland = {
        hideOnKeyPress = true;
        hideOnTouch = true;
        inactiveTimeout = 3;
      };
      dwl.cursorHideTimeout = 3000;
    };
    cornerRadius = 12;
    niriLayoutGapsOverride = 8;
    niriLayoutRadiusOverride = 12;
    niriLayoutBorderSize = 2;
    popupTransparency = 0.97;
    dockTransparency = 0.96;
    widgetBackgroundColor = "sch";
    widgetColorMode = "default";
    controlCenterTileColorMode = "primary";
    buttonColorMode = "primary";
    blurEnabled = true;
    blurForegroundLayers = true;
    blurLayerOutlineOpacity = 0.18;
    blurBorderColor = "primary";
    blurBorderOpacity = 0.35;
    wallpaperFillMode = "Fill";
    blurredWallpaperLayer = true;
    blurWallpaperOnOverview = true;
    animationSpeed = 1;
    syncComponentAnimationSpeeds = true;
    fontFamily = "Noto Sans";
    monoFontFamily = "JetBrainsMono Nerd Font";
    fontWeight = 500;
    fontScale = 1.0;
  });

  whocaresDesktopHealth = pkgs.writeShellApplication {
    name = "whocares-desktop-health";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      ok=1

      check_cmd() {
        if command -v "$1" >/dev/null 2>&1; then
          printf 'ok: %s -> %s\n' "$1" "$(command -v "$1")"
        else
          printf 'missing: %s\n' "$1" >&2
          ok=0
        fi
      }

      check_file() {
        if [[ -e "$1" ]]; then
          printf 'ok: %s\n' "$1"
        else
          printf 'missing: %s\n' "$1" >&2
          ok=0
        fi
      }

      check_cmd niri
      check_cmd dms
      check_cmd quickshell

      check_file "$HOME/.config/niri/config.kdl"
      check_file "$HOME/.config/niri/hm.kdl"
      check_file "$HOME/.local/state/DankMaterialShell/session.json"

      if systemctl --user is-active --quiet graphical-session.target; then
        printf 'ok: graphical-session.target active\n'
      else
        printf 'warn: graphical-session.target is not active\n' >&2
      fi

      if systemctl --user cat dms.service >/dev/null 2>&1; then
        systemctl --user --no-pager --full status dms.service || true
      else
        printf 'missing: dms.service is not known to user systemd\n' >&2
        ok=0
      fi

      exit "$((1 - ok))"
    '';
  };
in {
  programs.niri =
    {
      settings = {
        prefer-no-csd = true;

        input = {
          keyboard.xkb.layout = "us";
          touchpad = {
            tap = true;
            natural-scroll = true;
            dwt = true;
          };
        };

        layout = {
          gaps = 8;
          border.enable = true;
          focus-ring.enable = false;
        };

        hotkey-overlay.skip-at-startup = true;

        spawn-at-startup = [
          {
            command =
              [
                "${pkgs.systemd}/bin/systemctl"
                "--user"
                "import-environment"
              ]
              ++ sessionEnvNames;
          }
          {
            command =
              [
                "${pkgs.dbus}/bin/dbus-update-activation-environment"
                "--systemd"
              ]
              ++ sessionEnvNames;
          }
        ];
      };
    }
    // lib.optionalAttrs (!isNixOS) {
      enable = true;
    };

  programs.dank-material-shell = {
    enable = true;
    package = dmsPackage;
    quickshell.package = quickshellPackage;
    systemd = {
      enable = true;
      restartIfChanged = true;
      target = "graphical-session.target";
    };
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
    enableClipboardPaste = true;
    session = lib.mkForce {};
    managePluginSettings = false;
    niri = {
      enableKeybinds = false;
      enableSpawn = false;
      includes = {
        enable = true;
        override = true;
        originalFileName = "hm";
        filesToInclude = [
          "alttab"
          "binds"
          "colors"
          "cursor"
          "layout"
          "outputs"
          "windowrules"
          "wpblur"
        ];
      };
    };
  };

  stylix.targets.dank-material-shell.enable = lib.mkForce true;
  stylix.targets.waybar.enable = lib.mkForce false;
  programs.waybar.enable = lib.mkForce false;

  xdg.configFile."DankMaterialShell/settings.json".enable = lib.mkForce false;

  systemd.user.services = {
    dms = {
      Unit = {
        After = lib.mkForce [
          "graphical-session.target"
          "niri.service"
          "xdg-desktop-portal.service"
        ];
        PartOf = lib.mkForce ["graphical-session.target"];
      };
      Service = {
        Environment = [
          "PATH=${config.home.profileDirectory}/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin"
          "QSG_RHI_BACKEND=opengl"
          "QT_QPA_PLATFORM=wayland"
          "QT_QPA_PLATFORMTHEME=qt6ct"
          "QT_STYLE_OVERRIDE=kvantum"
          "XCURSOR_THEME=catppuccin-mocha-dark-cursors"
          "XCURSOR_SIZE=24"
          "XDG_CURRENT_DESKTOP=niri"
          "XDG_SESSION_DESKTOP=niri"
          "XDG_SESSION_TYPE=wayland"
        ];
        Restart = lib.mkForce "on-failure";
        RestartSec = "2s";
        StartLimitBurst = 5;
        StartLimitIntervalSec = 30;
      };
    };

    swayidle = {
      Unit = {
        Description = "Wayland idle manager";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.swayidle}/bin/swayidle -w";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    cliphist-watch = {
      Unit = {
        Description = "Wayland clipboard history watcher";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };

  home.activation.prepareDmsNiriIncludes = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    dms_dir="$HOME/.config/niri/dms"
    $DRY_RUN_CMD mkdir -p "$dms_dir"
    for name in alttab binds colors cursor layout outputs windowrules wpblur; do
      if [[ ! -e "$dms_dir/$name.kdl" ]]; then
        $DRY_RUN_CMD touch "$dms_dir/$name.kdl"
      fi
    done
  '';

  home.activation.prepareDmsMutableState = lib.hm.dag.entryAfter ["writeBoundary"] ''
    dms_config_dir="$HOME/.config/DankMaterialShell"
    dms_state_dir="$HOME/.local/state/DankMaterialShell"
    dms_settings="$dms_config_dir/settings.json"
    dms_session="$dms_state_dir/session.json"

    $DRY_RUN_CMD mkdir -p \
      "$dms_config_dir/plugins" \
      "$dms_config_dir/plugins/.repos" \
      "$dms_state_dir/plugins"

    if [[ -L "$dms_session" ]]; then
      target="$(${pkgs.coreutils}/bin/readlink "$dms_session" || true)"
      case "$target" in
        /nix/store/*)
          $DRY_RUN_CMD rm "$dms_session"
          ;;
      esac
    fi

    if [[ ! -e "$dms_session" ]]; then
      $DRY_RUN_CMD install -m 0644 ${dmsInitialSession} "$dms_session"
    fi

    if [[ -L "$dms_settings" ]]; then
      target="$(${pkgs.coreutils}/bin/readlink "$dms_settings" || true)"
      case "$target" in
        /nix/store/*)
          $DRY_RUN_CMD rm "$dms_settings"
          ;;
      esac
    fi

    if [[ ! -e "$dms_settings" ]]; then
      $DRY_RUN_CMD install -m 0644 ${dmsInitialSettings} "$dms_settings"
    fi
  '';

  home.sessionVariables = {
    BROWSER = "qutebrowser";
    FILE_MANAGER = "dolphin";
    QSG_RHI_BACKEND = "opengl";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    XCURSOR_THEME = "catppuccin-mocha-dark-cursors";
    XCURSOR_SIZE = "24";
  };

  home.packages = with pkgs; [
    whocaresDesktopHealth
    matugen
    glib
    dconf
    papirus-icon-theme
    adwaita-icon-theme
    hicolor-icon-theme
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    kdePackages.qtstyleplugin-kvantum
  ];

  programs.qutebrowser = {
    enable = true;
    settings = {
      tabs = {tabs_are_windows = false;};
      colors = {
        statusbar.normal = {
          bg = lib.mkForce "#09000d";
          fg = lib.mkForce "#ffd6f4";
        };
        tabs = {
          bar.bg = lib.mkForce "#09000d";
          odd = {
            bg = lib.mkForce "#120018";
            fg = lib.mkForce "#ffd6f4";
          };
          even = {
            bg = lib.mkForce "#21001f";
            fg = lib.mkForce "#ffd6f4";
          };
          selected = {
            odd = {
              bg = lib.mkForce "#ff2bd6";
              fg = lib.mkForce "#050006";
            };
            even = {
              bg = lib.mkForce "#a855f7";
              fg = lib.mkForce "#050006";
            };
          };
        };
      };
    };
  };
}
