# ---------------------------------------------------------------------------
# whonix.nix - Home Manager helpers for the official libvirt Whonix VM pair
# ---------------------------------------------------------------------------
{pkgs, ...}: let
  whonix = pkgs.writeShellApplication {
    name = "whonix";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      findutils
      gawk
      gnupg
      gnugrep
      gnused
      gnutar
      libvirt
      shadow
      systemd
      virt-viewer
      xz
    ];
    text = ''
      uri="''${WHONIX_LIBVIRT_URI:-qemu:///system}"
      gateway="''${WHONIX_GATEWAY_VM:-Whonix-Gateway}"
      workstation="''${WHONIX_WORKSTATION_VM:-Whonix-Workstation}"
      signing_fingerprint="916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA"

      virsh_cmd() {
        virsh --connect "$uri" "$@"
      }

      run_sudo() {
        local sudo_bin
        if [[ -u /run/wrappers/bin/sudo ]]; then
          sudo_bin=/run/wrappers/bin/sudo
        elif [[ -u /usr/bin/sudo ]]; then
          sudo_bin=/usr/bin/sudo
        else
          echo "No host setuid sudo wrapper was found." >&2
          exit 1
        fi
        "$sudo_bin" "$@"
      }

      hypervisor_ready() {
        virsh_cmd uri >/dev/null 2>&1
      }

      require_hypervisor() {
        if hypervisor_ready; then
          return
        fi

        echo "Cannot connect to libvirt at $uri." >&2
        if command -v systemctl >/dev/null 2>&1 &&
          ! systemctl is-active --quiet libvirtd.service; then
          echo "libvirtd.service is not running. Run: whonix daemon" >&2
        fi
        echo "Then run: whonix doctor" >&2
        exit 1
      }

      domain_exists() {
        virsh_cmd dominfo "$1" >/dev/null 2>&1
      }

      resolve_domains() {
        if [[ -z "''${WHONIX_GATEWAY_VM:-}" ]] &&
          ! domain_exists "$gateway" &&
          domain_exists whonix-gw; then
          gateway=whonix-gw
        fi
        if [[ -z "''${WHONIX_WORKSTATION_VM:-}" ]] &&
          ! domain_exists "$workstation" &&
          domain_exists whonix-ws; then
          workstation=whonix-ws
        fi
      }

      require_domain() {
        if ! domain_exists "$1"; then
          echo "Whonix domain '$1' is not defined on $uri." >&2
          echo "Download and verify the official KVM package, extract it, accept its license," >&2
          echo "then run: whonix import /path/to/extracted-directory" >&2
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
        while ((timeout > 0)); do
          [[ "$(state "$vm")" == "shut off" ]] && return 0
          sleep 1
          timeout=$((timeout - 1))
        done
        echo "Timed out waiting for $vm to stop; use 'whonix force-stop' only if necessary." >&2
        return 1
      }

      select_vm() {
        case "''${1:-ws}" in
          ws | workstation | "$workstation") printf '%s\n' "$workstation" ;;
          gw | gateway | "$gateway") printf '%s\n' "$gateway" ;;
          *)
            echo "Unknown VM '$1' (use ws or gw)." >&2
            exit 2
            ;;
        esac
      }

      report() {
        local label="$1" value="$2"
        printf '%-22s %s\n' "$label" "$value"
      }

      doctor() {
        local failed=0

        if [[ -c /dev/kvm ]]; then
          report "KVM device" "ready"
        else
          report "KVM device" "missing (/dev/kvm)"
          failed=1
        fi

        if hypervisor_ready; then
          report "libvirt $uri" "ready"
          resolve_domains
        else
          report "libvirt $uri" "unavailable"
          if command -v systemctl >/dev/null 2>&1; then
            report "libvirtd.service" "$(systemctl is-active libvirtd.service 2>/dev/null || true)"
          fi
          failed=1
        fi

        if getent group libvirt >/dev/null 2>&1; then
          if id -nG | tr ' ' '\n' | grep -Fxq libvirt; then
            report "libvirt group" "joined"
          else
            report "libvirt group" "not joined (log out after 'whonix daemon')"
          fi
        fi

        if hypervisor_ready; then
          for vm in "$gateway" "$workstation"; do
            if domain_exists "$vm"; then
              report "domain $vm" "$(state "$vm")"
            else
              report "domain $vm" "undefined"
              failed=1
            fi
          done

          for network in Whonix-External Whonix-Internal; do
            if virsh_cmd net-info "$network" >/dev/null 2>&1; then
              report "network $network" \
                "$(virsh_cmd net-info "$network" | awk '/^Active:/ {print $2}')"
            else
              report "network $network" "undefined"
              failed=1
            fi
          done
        fi

        if ((failed)); then
          echo
          echo "Whonix is not ready. Use 'whonix daemon', then import the official KVM package."
          return 1
        fi

        echo
        echo "Whonix is ready."
      }

      daemon_setup() {
        command -v systemctl >/dev/null 2>&1 || {
          echo "systemd is required for automatic libvirt setup." >&2
          exit 1
        }

        echo "[sudo] Enabling and starting libvirtd.service"
        run_sudo systemctl enable --now libvirtd.service

        local added_group=0
        for group in libvirt kvm; do
          if getent group "$group" >/dev/null 2>&1 &&
            ! id -nG | tr ' ' '\n' | grep -Fxq "$group"; then
            echo "[sudo] Adding $USER to the $group group"
            run_sudo usermod --append --groups "$group" "$USER"
            added_group=1
          fi
        done
        if ((added_group)); then
          echo "Log out and back in before using Whonix without sudo."
        fi
      }

      one_match() {
        local description="$1"
        shift
        if (($# != 1)); then
          echo "Expected exactly one $description, found $#." >&2
          exit 1
        fi
        printf '%s\n' "$1"
      }

      verify_archive() {
        local archive="''${1:-}"
        [[ -n "$archive" ]] || {
          echo "Usage: whonix verify /path/to/Whonix-*.libvirt.xz" >&2
          exit 2
        }
        archive="$(realpath "$archive")"
        [[ -s "$archive" ]] || {
          echo "Archive is missing or empty: $archive" >&2
          exit 1
        }

        local filename version signature workdir key fingerprint
        filename="''${archive##*/}"
        version="''${filename#Whonix-LXQt-}"
        version="''${version%.Intel_AMD64.qcow2.libvirt.xz}"
        signature="$archive.asc"

        if [[ ! -s "$signature" ]]; then
          if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Place the matching OpenPGP signature at: $signature" >&2
            exit 1
          fi
          echo "Downloading official signature for Whonix $version"
          curl --fail --location --proto '=https' --tlsv1.2 \
            --output "$signature" \
            "https://download.whonix.org/libvirt/$version/$filename.asc"
        fi

        workdir="$(mktemp --directory)"
        trap 'rm -rf "$workdir"' EXIT
        key="$workdir/derivative.asc"
        mkdir --mode=0700 "$workdir/gnupg"
        curl --fail --location --proto '=https' --tlsv1.2 \
          --output "$key" \
          https://www.whonix.org/keys/derivative.asc

        fingerprint="$(
          gpg --no-options --batch --show-keys --with-colons "$key" |
            awk -F: '$1 == "fpr" { print $10; exit }'
        )"
        if [[ "$fingerprint" != "$signing_fingerprint" ]]; then
          echo "Whonix signing-key fingerprint mismatch." >&2
          echo "Expected: $signing_fingerprint" >&2
          echo "Found:    $fingerprint" >&2
          exit 1
        fi

        gpg --no-options --batch --homedir "$workdir/gnupg" --import "$key" >/dev/null
        gpg --no-options --batch --homedir "$workdir/gnupg" \
          --verify-options show-notations \
          --verify "$signature" "$archive"

        rm -rf "$workdir"
        trap - EXIT
        echo "Verified Whonix archive and signing-key fingerprint: $filename"
      }

      extract_archive() {
        local archive="''${1:-}"
        [[ -n "$archive" ]] || {
          echo "Usage: whonix extract ARCHIVE [DESTINATION]" >&2
          exit 2
        }
        archive="$(realpath "$archive")"
        verify_archive "$archive"

        local filename destination
        filename="''${archive##*/}"
        destination="''${2:-''${XDG_DATA_HOME:-$HOME/.local/share}/whocares/whonix/''${filename%.xz}}"
        mkdir -p "$destination"
        tar --extract --sparse --verbose --file "$archive" --directory "$destination"
        echo
        echo "Extracted Whonix package to: $destination"
        echo "Read the bundled license and follow its acceptance instructions before import."
      }

      import_package() {
        local source_dir="''${1:-''${WHONIX_SOURCE_DIR:-}}"
        [[ -n "$source_dir" ]] || {
          echo "Usage: whonix import /path/to/extracted-directory" >&2
          exit 2
        }
        source_dir="$(realpath "$source_dir")"
        [[ -d "$source_dir" ]] || {
          echo "Not a directory: $source_dir" >&2
          exit 1
        }
        [[ -e "$source_dir/WHONIX_BINARY_LICENSE_AGREEMENT_accepted" ]] || {
          echo "The Whonix binary license has not been accepted in $source_dir." >&2
          echo "Read WHONIX_BINARY_LICENSE_AGREEMENT and follow its acceptance instructions." >&2
          exit 1
        }

        shopt -s nullglob
        local gateway_xml workstation_xml external_xml internal_xml
        local gateway_image workstation_image
        gateway_xml="$(one_match "Gateway XML" "$source_dir"/Whonix-Gateway*.xml)"
        workstation_xml="$(one_match "Workstation XML" "$source_dir"/Whonix-Workstation*.xml)"
        external_xml="$(one_match "external network XML" "$source_dir"/Whonix_external*.xml)"
        internal_xml="$(one_match "internal network XML" "$source_dir"/Whonix_internal*.xml)"
        gateway_image="$(one_match "Gateway qcow2 image" "$source_dir"/Whonix-Gateway*.qcow2)"
        workstation_image="$(one_match "Workstation qcow2 image" "$source_dir"/Whonix-Workstation*.qcow2)"

        daemon_setup

        echo "[sudo] Installing sparse qcow2 images"
        run_sudo mkdir -p /var/lib/libvirt/images
        run_sudo cp --sparse=always "$gateway_image" /var/lib/libvirt/images/Whonix-Gateway.qcow2
        run_sudo cp --sparse=always "$workstation_image" /var/lib/libvirt/images/Whonix-Workstation.qcow2
        run_sudo chown root:root \
          /var/lib/libvirt/images/Whonix-Gateway.qcow2 \
          /var/lib/libvirt/images/Whonix-Workstation.qcow2
        run_sudo chmod 0600 \
          /var/lib/libvirt/images/Whonix-Gateway.qcow2 \
          /var/lib/libvirt/images/Whonix-Workstation.qcow2

        for spec in \
          "Whonix-External:$external_xml" \
          "Whonix-Internal:$internal_xml"; do
          local network="''${spec%%:*}" xml="''${spec#*:}"
          if ! run_sudo virsh --connect "$uri" net-info "$network" >/dev/null 2>&1; then
            run_sudo virsh --connect "$uri" net-define "$xml"
          fi
          run_sudo virsh --connect "$uri" net-autostart "$network"
          if [[ "$(run_sudo virsh --connect "$uri" net-info "$network" | awk '/^Active:/ {print $2}')" != "yes" ]]; then
            run_sudo virsh --connect "$uri" net-start "$network"
          fi
        done

        run_sudo virsh --connect "$uri" define "$gateway_xml"
        run_sudo virsh --connect "$uri" define "$workstation_xml"
        echo
        echo "Official Whonix KVM package imported."
        echo "Log out and back in if your libvirt group membership changed, then run: wx"
      }

      usage() {
        cat <<'EOF'
      Usage: whonix <command> [argument]

      Commands:
        doctor            check KVM, libvirt, domains, and Whonix networks
        daemon            enable libvirt and add the current user to its group
        verify ARCHIVE     verify an official KVM archive and signing-key fingerprint
        extract FILE [DIR] verify and sparsely extract an official KVM archive
        import DIR        import an extracted, verified official KVM package
        start             start Gateway, then Workstation
        stop              gracefully stop Workstation, then Gateway
        restart           stop both VMs and start them in safe order
        force-stop        immediately power off Workstation, then Gateway
        status            show domain state and network interfaces
        view [ws|gw]      open a local virt-viewer console
        console [ws|gw]   attach to a serial console
        network [ws|gw]   show a VM's libvirt interfaces
        provision [DIR]   alias for import; DIR or WHONIX_SOURCE_DIR is required

      Official KVM guide: https://www.whonix.org/wiki/KVM
      EOF
      }

      case "''${1:-help}" in
        doctor)
          doctor
          ;;
        daemon)
          daemon_setup
          ;;
        verify)
          verify_archive "''${2:-}"
          ;;
        extract)
          extract_archive "''${2:-}" "''${3:-}"
          ;;
        import)
          import_package "''${2:-}"
          ;;
        provision)
          import_package "''${2:-}"
          ;;
        start)
          require_hypervisor
          resolve_domains
          start_vm "$gateway"
          sleep "''${WHONIX_GATEWAY_DELAY:-5}"
          start_vm "$workstation"
          ;;
        stop)
          require_hypervisor
          resolve_domains
          shutdown_vm "$workstation"
          wait_stopped "$workstation"
          shutdown_vm "$gateway"
          ;;
        restart)
          require_hypervisor
          resolve_domains
          shutdown_vm "$workstation"
          wait_stopped "$workstation"
          shutdown_vm "$gateway"
          wait_stopped "$gateway"
          start_vm "$gateway"
          sleep "''${WHONIX_GATEWAY_DELAY:-5}"
          start_vm "$workstation"
          ;;
        force-stop)
          require_hypervisor
          resolve_domains
          require_domain "$workstation"
          require_domain "$gateway"
          [[ "$(state "$workstation")" == "shut off" ]] || virsh_cmd destroy "$workstation"
          [[ "$(state "$gateway")" == "shut off" ]] || virsh_cmd destroy "$gateway"
          ;;
        status)
          require_hypervisor
          resolve_domains
          for vm in "$gateway" "$workstation"; do
            if domain_exists "$vm"; then
              printf '%-20s %s\n' "$vm" "$(state "$vm")"
              virsh_cmd domiflist "$vm"
            else
              printf '%-20s %s\n' "$vm" "undefined"
            fi
            echo
          done
          ;;
        view)
          require_hypervisor
          resolve_domains
          vm=$(select_vm "''${2:-ws}")
          require_domain "$vm"
          exec virt-viewer --connect "$uri" "$vm"
          ;;
        console)
          require_hypervisor
          resolve_domains
          vm=$(select_vm "''${2:-ws}")
          require_domain "$vm"
          virsh_cmd console "$vm"
          ;;
        network)
          require_hypervisor
          resolve_domains
          vm=$(select_vm "''${2:-ws}")
          require_domain "$vm"
          virsh_cmd domiflist "$vm"
          ;;
        help | -h | --help)
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
    wxd = "whonix doctor";
    wxsetup = "whonix daemon";
    wxverify = "whonix verify";
    wxextract = "whonix extract";
    wximport = "whonix import";
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
    alias wxd = whonix doctor
    alias wxsetup = whonix daemon
    alias wxverify = whonix verify
    alias wxextract = whonix extract
    alias wximport = whonix import
    alias wxv = whonix view ws
    alias wxstop = whonix stop
    alias wxrestart = whonix restart
  '';
}
