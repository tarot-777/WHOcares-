{
  lib,
  pkgs,
  ...
}: {
  imports = lib.optional (builtins.pathExists ./whonix-vms.nix) ./whonix-vms.nix;

  networking.hostName = "Aegis-Dualis";
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

  users.users.malachi = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "libvirtd" "kvm" "input" "video" "audio"];
  };

  environment.systemPackages = with pkgs; [
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
