# ---------------------------------------------------------------------------
# whonix.nix - Home Manager helpers for the libvirt Whonix VM pair
# ---------------------------------------------------------------------------
{pkgs, ...}: let
  whonix = pkgs.writeShellApplication {
    name = "whonix";
    runtimeInputs = with pkgs; [
      coreutils
      libvirt
      systemd
      sudo
      virt-viewer
    ];
    text = ''
      uri="''${WHONIX_LIBVIRT_URI:-qemu:///system}"
      gateway="''${WHONIX_GATEWAY_VM:-whonix-gw}"
      workstation="''${WHONIX_WORKSTATION_VM:-whonix-ws}"

      virsh_cmd() {
        virsh --connect "$uri" "$@"
      }

      require_domain() {
        if ! virsh_cmd dominfo "$1" >/dev/null 2>&1; then
          echo "Whonix domain '$1' is not defined on $uri." >&2
          echo "On Aegis-Dualis, run the NixOS switch after installing the qcow2 images." >&2
          exit 1
        fi
      }

      state() {
        virsh_cmd domstate "$1" 2>/dev/null | tr -d '\r'
      }

      start_vm() {
        require_domain "$1"
        if [[ "$(state "$1")" == "running" ]]; then
          echo "[running] $1"
        else
          echo "[start] $1"
          virsh_cmd start "$1"
        fi
      }

      shutdown_vm() {
        require_domain "$1"
        if [[ "$(state "$1")" == "shut off" ]]; then
          echo "[stopped] $1"
        else
          echo "[shutdown] $1"
          virsh_cmd shutdown "$1"
        fi
      }

      wait_stopped() {
        local vm="$1" timeout="''${2:-60}"
        while (( timeout > 0 )); do
          [[ "$(state "$vm")" == "shut off" ]] && return 0
          sleep 1
          timeout=$((timeout - 1))
        done
        echo "Timed out waiting for $vm to stop; use 'whonix force-stop' only if necessary." >&2
        return 1
      }

      usage() {
        cat <<'EOF'
      Usage: whonix <command> [vm]

      Commands:
        start             start Gateway, then Workstation
        stop              gracefully stop Workstation, then Gateway
        restart           stop both VMs and start them in safe order
        force-stop        immediately power off Workstation, then Gateway
        status            show domain state and network interfaces
        view [ws|gw]      open a local virt-viewer console
        console [ws|gw]   attach to a serial console
        network [ws|gw]   show a VM's libvirt interfaces
        provision         rerun the NixOS Whonix provision service
      EOF
      }

      select_vm() {
        case "''${1:-ws}" in
          ws|workstation|"$workstation") printf '%s\n' "$workstation" ;;
          gw|gateway|"$gateway") printf '%s\n' "$gateway" ;;
          *) echo "Unknown VM '$1' (use ws or gw)." >&2; exit 2 ;;
        esac
      }

      case "''${1:-help}" in
        start)
          start_vm "$gateway"
          sleep "''${WHONIX_GATEWAY_DELAY:-5}"
          start_vm "$workstation"
          ;;
        stop)
          shutdown_vm "$workstation"
          wait_stopped "$workstation"
          shutdown_vm "$gateway"
          ;;
        restart)
          shutdown_vm "$workstation"
          wait_stopped "$workstation"
          shutdown_vm "$gateway"
          wait_stopped "$gateway"
          start_vm "$gateway"
          sleep "''${WHONIX_GATEWAY_DELAY:-5}"
          start_vm "$workstation"
          ;;
        force-stop)
          require_domain "$workstation"
          require_domain "$gateway"
          [[ "$(state "$workstation")" == "shut off" ]] || virsh_cmd destroy "$workstation"
          [[ "$(state "$gateway")" == "shut off" ]] || virsh_cmd destroy "$gateway"
          ;;
        status)
          for vm in "$gateway" "$workstation"; do
            if virsh_cmd dominfo "$vm" >/dev/null 2>&1; then
              printf '%-14s %s\n' "$vm" "$(state "$vm")"
              virsh_cmd domiflist "$vm"
            else
              printf '%-14s %s\n' "$vm" "undefined"
            fi
            echo
          done
          ;;
        view)
          vm=$(select_vm "''${2:-ws}")
          require_domain "$vm"
          exec virt-viewer --connect "$uri" "$vm"
          ;;
        console)
          vm=$(select_vm "''${2:-ws}")
          require_domain "$vm"
          virsh_cmd console "$vm"
          ;;
        network)
          vm=$(select_vm "''${2:-ws}")
          require_domain "$vm"
          virsh_cmd domiflist "$vm"
          ;;
        provision)
          exec sudo systemctl restart whonix-vm-provision.service
          ;;
        help|-h|--help)
          usage
          ;;
        *)
          usage >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  home.packages = [whonix];

  home.sessionVariables.WHONIX_LIBVIRT_URI = "qemu:///system";

  programs.zsh.shellAliases = {
    wx = "whonix start";
    wxs = "whonix status";
    wxv = "whonix view ws";
    wxvg = "whonix view gw";
    wxstop = "whonix stop";
    wxrestart = "whonix restart";
    wxconsole = "whonix console ws";
    wxgw = "whonix console gw";
    wxnet = "whonix network ws";
  };

  programs.nushell.extraConfig = ''
    alias wx = whonix start
    alias wxs = whonix status
    alias wxv = whonix view ws
    alias wxstop = whonix stop
    alias wxrestart = whonix restart
  '';
}
