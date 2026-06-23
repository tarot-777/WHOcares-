# ---------------------------------------------------------------------------
# profiles.nix — Core package orchestration and environment profiles
#
# Hardware-aware tooling including strictly enforced Python environment
# management via 'uv', multi-shell layers (zsh/nushell), high-performance
# rendering environments (Alacritty/Ghostty), and AMD diagnostic suites.
# ---------------------------------------------------------------------------
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
    full.enable = mkEnableOption "Full WHOcares feature set orchestration";
    graphics.enable = mkEnableOption "Hardware-accelerated graphics tools";
    office.enable = mkEnableOption "Administrative and office tools";
    vms.enable = mkEnableOption "Virtualization and containerization suites";
    rocm.enable = mkEnableOption "AMD ROCm compute and diagnostic tools";
    browser = mkOption {
      type = types.enum ["brave" "firefox" "qutebrowser"];
      default = "brave";
    };
  };

  config.home.packages =
    [
      # Core orchestration layer
      pkgs.${cfg.browser}
      pkgs.uv # Exclusive Python package and environment manager
      pkgs.zsh
      pkgs.nushell
      pkgs.alacritty
      pkgs.ghostty
    ]
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
      pkgs.rocmPackages.rocminfo
      pkgs.amdgpu_top # Tactical hardware monitoring for Polaris/RX series
      pkgs.radeontop
    ];
}
