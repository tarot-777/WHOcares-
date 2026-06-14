# Niri and DankMaterialShell session integration.
{
  config,
  inputs,
  isNixOS ? false,
  lib,
  pkgs,
  ...
}: let
  dmsSystemPackage = pkgs.writeShellScriptBin "dms" ''
    set -e
    export PATH="/usr/bin:/usr/local/bin:${lib.makeBinPath [pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused]}:$PATH"

    if [[ -x /usr/bin/dms ]]; then
      exec /usr/bin/dms "$@"
    elif [[ -x /usr/local/bin/dms ]]; then
      exec /usr/local/bin/dms "$@"
    fi

    echo "dms: install DankMaterialShell at /usr/bin/dms or /usr/local/bin/dms" >&2
    exit 127
  '';

  quickshellSystemPackage = pkgs.writeShellScriptBin "quickshell" ''
    if [[ ! -x /usr/bin/quickshell ]]; then
      echo "quickshell: expected the Arch package at /usr/bin/quickshell" >&2
      exit 127
    fi
    exec /usr/bin/quickshell "$@"
  '';

  dmsPackage =
    if isNixOS
    then inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell
    else dmsSystemPackage;

  quickshellPackage =
    if isNixOS
    then pkgs.quickshell
    else quickshellSystemPackage;
in {
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
  };

  # Preserve the user's existing DMS settings and plugins.
  programs.dank-material-shell.managePluginSettings = false;
  stylix.targets.dank-material-shell.enable = lib.mkForce false;
  stylix.targets.waybar.enable = lib.mkForce false;
  programs.waybar.enable = lib.mkForce false;

  xdg.configFile = lib.mkIf (!isNixOS) {
    "niri/config.kdl".source = ../config/niri/config.kdl;
    "niri/binds.kdl".source = ../config/niri/binds.kdl;
  };

  systemd.user.services = {
    dms.Service = {
      Environment = [
        "PATH=/usr/bin:/usr/local/bin:${config.home.profileDirectory}/bin"
        "QSG_RHI_BACKEND=opengl"
      ];
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

  home.activation.prepareDmsNiriIncludes = lib.mkIf (!isNixOS) (
    lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      dms_dir="$HOME/.config/niri/dms"
      $DRY_RUN_CMD mkdir -p "$dms_dir"
      for name in alttab binds colors cursor layout outputs windowrules wpblur; do
        if [[ ! -e "$dms_dir/$name.kdl" ]]; then
          $DRY_RUN_CMD touch "$dms_dir/$name.kdl"
        fi
      done
    ''
  );

  # Set Qutebrowser as the default browser for a power‑user experience.  This
  # overrides the previous default of Firefox and ensures that the system uses
  # Qutebrowser when opening links.  See `programs.qutebrowser` below for
  # feature configuration.
  home.sessionVariables = {
    BROWSER = "qutebrowser";
    FILE_MANAGER = "thunar";
    QSG_RHI_BACKEND = "opengl";
  };

  # Enable Qutebrowser and provide a minimal configuration.  Qutebrowser is
  # keyboard‑driven and integrates well with Vim workflows, making it ideal
  # for users who rely on AI and LLM tools within terminal editors.  The
  # settings attribute set here can be extended with custom keybindings,
  # appearance tweaks or additional defaults as needed.  For example, the
  # following ensures that new tabs open in the same window and applies a
  # dark tab bar color.  Adjust these settings or add more entries from
  # `https://qutebrowser.org/doc/help/settings.html` to suit your preferences.
  programs.qutebrowser = {
    enable = true;
    settings = {
      # Treat tabs as belonging to one window rather than spawning new
      # windows by default.
      tabs = {tabs_are_windows = false;};
      colors = {
        tabs = {bar = {bg = "#1e1e2e";};};
      };
    };
  };
}
