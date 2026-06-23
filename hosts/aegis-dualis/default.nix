{
  hostName ? "Aegis-Dualis",
  lib,
  pkgs,
  userName ? "malachi",
  ...
}: let
  kittyDesktop = pkgs.makeDesktopItem {
    name = "kitty";
    desktopName = "Kitty";
    genericName = "Terminal Emulator";
    comment = "WHOcares neon Kitty terminal";
    exec = "${pkgs.kitty}/bin/kitty %U";
    icon = "kitty";
    categories = [
      "System"
      "TerminalEmulator"
    ];
    mimeTypes = ["x-scheme-handler/terminal"];
    startupNotify = true;
    extraConfig = {
      Keywords = "shell;prompt;command;commandline;terminal;tmux;WHOcares;";
      X-TerminalArgExec = "-e";
      X-TerminalArgTitle = "--title";
    };
  };
in {
  imports = lib.optional (builtins.pathExists ./whonix-vms.nix) ./whonix-vms.nix;

  networking.hostName = lib.mkDefault hostName;

  catppuccin = {
    enable = false;
    autoEnable = false;
  };
  system.stateVersion = "25.05";

  fileSystems."/" = lib.mkDefault {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  boot.loader.grub.enable = lib.mkDefault false;

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
  programs.virt-manager.enable = true;

  environment.variables = {
    TERMINAL = "kitty";
    XDG_TERMINAL = "kitty";
    BROWSER = "qutebrowser";
    FILE_MANAGER = "dolphin";
  };

  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = ["kitty.desktop"];
      niri = ["kitty.desktop"];
      GNOME = ["kitty.desktop"];
      KDE = ["kitty.desktop"];
    };
  };

  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "libvirtd" "kvm" "input" "video" "audio"];
  };

  environment.systemPackages = with pkgs; [
    kitty
    kittyDesktop
    tmux
    fastfetch
    zsh
    git
    nh
    home-manager
    libvirt
    qemu_kvm
    virt-manager
    virt-viewer
    swtpm
  ];
}
