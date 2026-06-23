# Dolphin file management with terminal and Nix workflow integration.
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
  profileBin = "${config.home.profileDirectory}/bin";

  dolphinTerminal = pkgs.writeShellApplication {
    name = "dolphin-terminal";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      target="''${1:-$PWD}"
      if [[ -f "$target" ]]; then
        target="$(dirname -- "$target")"
      fi
      exec "${profileBin}/kitty" --directory "$target"
    '';
  };

  dolphinEditor = pkgs.writeShellApplication {
    name = "dolphin-editor";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      target="''${1:-$PWD}"
      exec "${profileBin}/kitty" --directory "$PWD" "${profileBin}/nvim" "$target"
    '';
  };

  dolphinNixDevelop = pkgs.writeShellApplication {
    name = "dolphin-nix-develop";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      target="''${1:-$PWD}"
      if [[ -f "$target" ]]; then
        target="$(dirname -- "$target")"
      fi

      root="$target"
      while [[ "$root" != "/" && ! -f "$root/flake.nix" ]]; do
        root="$(dirname -- "$root")"
      done

      if [[ ! -f "$root/flake.nix" ]]; then
        root="''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-${configuredFlakeRoot}}}"
      fi

      exec "${profileBin}/kitty" \
        --directory "$root" \
        "${pkgs.zsh}/bin/zsh" -lc 'nix develop; exec zsh'
    '';
  };
in {
  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.kio-admin
    kdePackages.kio-extras
    kdePackages.kio-fuse
    kdePackages.ark
    kdePackages.ffmpegthumbs
    kdePackages.qtimageformats
    dolphinTerminal
    dolphinEditor
    dolphinNixDevelop
  ];

  home.sessionVariables.FILE_MANAGER = "dolphin";

  xdg.configFile."dolphinrc".text = ''
    [DetailsMode]
    PreviewSize=32

    [General]
    BrowseThroughArchives=true
    GlobalViewProps=false
    ShowFullPath=true
    ShowToolTips=true
    ShowZoomSlider=true

    [KFileDialog Settings]
    Show hidden files=true
  '';

  xdg.dataFile."kio/servicemenus/whocares-tools.desktop".text = ''
    [Desktop Entry]
    Type=Service
    MimeType=inode/directory;application/x-nix;
    Actions=OpenKitty;OpenNeovim;NixDevelop;
    X-KDE-ServiceTypes=KonqPopupMenu/Plugin
    X-KDE-Submenu=WHOcares!

    [Desktop Action OpenKitty]
    Name=Open Kitty Here
    Icon=utilities-terminal
    Exec=${dolphinTerminal}/bin/dolphin-terminal %f

    [Desktop Action OpenNeovim]
    Name=Edit in Neovim
    Icon=nvim
    Exec=${dolphinEditor}/bin/dolphin-editor %f

    [Desktop Action NixDevelop]
    Name=Enter Nix Development Shell
    Icon=nix-snowflake
    Exec=${dolphinNixDevelop}/bin/dolphin-nix-develop %f
  '';

  programs.zsh.shellAliases = {
    fm = "dolphin";
    fmh = "dolphin .";
    fma = "dolphin admin:/";
  };

  programs.nushell.extraConfig = ''
    alias fm = dolphin
    alias fmh = dolphin .
    alias fma = dolphin admin:/
  '';

  xdg.mimeApps.defaultApplications."inode/directory" = "org.kde.dolphin.desktop";
}
