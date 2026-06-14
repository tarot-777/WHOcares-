{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.whycare.shell;

  banner = pkgs.writeShellScriptBin "whycare-banner" ''
    set -euo pipefail
    host=$(${pkgs.coreutils}/bin/cat /proc/sys/kernel/hostname 2>/dev/null || echo unknown)
    echo ""
    echo "  WHOcares! - $host"
    echo "  ------------------------------------------"
    echo "  hm        -> Home Manager switch"
    echo "  hm-check  -> Home Manager build"
    echo "  whocares  -> NixOS rebuild"
    echo "  wx        -> start Whonix"
    echo "  wxs       -> Whonix status"
    echo "  wxd       -> Whonix readiness check"
    echo ""
  '';
in {
  options.whycare = {
    enableFullPower = mkEnableOption "heavy WHOcares packages";
    shell.enable = mkEnableOption "WHOcares shell extras";
  };

  config = mkIf cfg.enable {
    home.packages = [banner];

    programs.zsh.initContent = mkAfter ''
      if [[ -o interactive ]] && [[ -z "''${WHYCARE_BANNER_SHOWN:-}" ]]; then
        export WHYCARE_BANNER_SHOWN=1
        whycare-banner
      fi
    '';
  };
}
