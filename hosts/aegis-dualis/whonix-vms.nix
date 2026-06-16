# ---------------------------------------------------------------------------
# whonix-vms.nix - host prerequisites for the official Whonix KVM package
#
# VM and network XML comes from Whonix itself. Keeping those definitions
# upstream-owned avoids silently diverging from Whonix's security defaults.
# Import an extracted and verified package with:
#
#   whonix import /path/to/extracted-directory
# ---------------------------------------------------------------------------
_: {
  systemd.tmpfiles.rules = [
    "d /var/lib/libvirt/images 0711 root root -"
  ];
}
