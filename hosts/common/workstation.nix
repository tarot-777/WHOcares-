{
  hostName ? "workstation",
  lib,
  pkgs,
  userName ? "malachi",
  ...
}: {
  networking.hostName = lib.mkDefault hostName;
  system.stateVersion = "25.05";

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  fileSystems."/" = lib.mkOptionDefault {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=4G" "mode=755"];
  };

  hardware.enableRedistributableFirmware = lib.mkDefault true;
  networking.networkmanager.enable = lib.mkDefault true;
  services.fwupd.enable = lib.mkDefault true;
  services.printing.enable = lib.mkDefault true;

  time.timeZone = lib.mkDefault "America/Denver";

  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [
      "audio"
      "input"
      "kvm"
      "libvirtd"
      "networkmanager"
      "video"
      "wheel"
    ];
  };

  programs.zsh.enable = lib.mkDefault true;
  virtualisation.libvirtd.enable = lib.mkDefault true;
  programs.virt-manager.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    fastfetch
    git
    home-manager
    kitty
    nh
    pciutils
    tmux
    usbutils
  ];
}
