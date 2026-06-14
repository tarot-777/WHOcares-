{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.whycare.profiles;
in {
  options.whycare.profiles = {
    full.enable = mkEnableOption "full WHOcares feature set";
    graphics.enable = mkEnableOption "graphics tools";
    office.enable = mkEnableOption "office tools";
    vms.enable = mkEnableOption "VM tools";
    rocm.enable = mkEnableOption "ROCm tools";
    browser = mkOption {
      type = types.enum ["brave" "firefox"];
      default = "brave";
    };
  };

  config.home.packages =
    [pkgs.${cfg.browser}]
    ++ optionals (cfg.full.enable || cfg.graphics.enable) [
      pkgs.inkscape
      pkgs.gimp
      pkgs.imagemagick
      pkgs.blender
    ]
    ++ optionals (cfg.full.enable || cfg.office.enable) [
      pkgs.libreoffice
      pkgs.thunderbird
    ]
    ++ optionals (cfg.full.enable || cfg.vms.enable) [
      pkgs.qemu_kvm
      pkgs.virt-manager
      pkgs.virt-viewer
      pkgs.libvirt
      pkgs.swtpm
      pkgs.distrobox
      pkgs.lazydocker
      pkgs.nerdctl
    ]
    ++ optionals (cfg.full.enable || cfg.rocm.enable) [
      pkgs.clinfo
      pkgs.rocminfo
    ];
}
