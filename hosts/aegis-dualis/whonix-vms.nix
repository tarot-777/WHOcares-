# ---------------------------------------------------------------------------
# whonix-vms.nix — NixOS module (NOT a Home Manager module)
#
# Declarative Whonix Gateway + Workstation VM definitions via libvirt.
#
# Prerequisites:
#   1. whonix-gw.qcow2 and whonix-ws.qcow2 in /var/lib/libvirt/images/
#      Download: https://www.whonix.org/wiki/KVM
#      Verify GPG signatures before placing images.
#   2. whonix-bridge.service creates the isolated virbr-whonix L2 bridge.
#
# First-run bootstrap (after NixOS switch):
#   virsh define /etc/libvirt/qemu/whonix-gw.xml
#   virsh define /etc/libvirt/qemu/whonix-ws.xml
#   virsh start whonix-gw
# ---------------------------------------------------------------------------
{pkgs, ...}: {
  # ── Isolated L2 bridge between Gateway and Workstation ────────────────────
  # No host IP or NAT is assigned. The Workstation reaches the network only
  # through the Gateway's internal NIC.
  systemd.services.whonix-bridge = {
    description = "Create the isolated Whonix libvirt bridge";
    wantedBy = ["multi-user.target"];
    before = ["libvirtd.service" "whonix-vm-provision.service"];
    path = [pkgs.iproute2];
    script = ''
      set -euo pipefail
      if ! ip link show virbr-whonix >/dev/null 2>&1; then
        ip link add name virbr-whonix type bridge
      fi
      ip link set dev virbr-whonix up
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # ── Drop XML definitions into the libvirt QEMU config dir ─────────────────
  environment.etc."libvirt/qemu/whonix-gw.xml" = {
    mode = "0640";
    text = ''
      <domain type='kvm'>
        <name>whonix-gw</name>
        <uuid>aaaaaaaa-0001-0001-0001-aaaaaaaaaaaa</uuid>
        <memory unit='MiB'>512</memory>
        <currentMemory unit='MiB'>512</currentMemory>
        <vcpu placement='static'>1</vcpu>
        <os firmware='efi'>
          <type arch='x86_64' machine='q35'>hvm</type>
          <boot dev='hd'/>
        </os>
        <features>
          <acpi/><apic/>
          <!-- Prevent hypervisor ID from leaking to guest -->
          <kvm><hidden state='on'/></kvm>
        </features>
        <cpu mode='host-passthrough' check='none' migratable='on'/>
        <clock offset='utc'>
          <timer name='rtc' tickpolicy='catchup'/>
          <timer name='hpet' present='no'/>
          <!-- No TSC — avoids timing-based fingerprinting -->
          <timer name='tsc' present='no'/>
        </clock>
        <devices>
          <emulator>/run/current-system/sw/bin/qemu-system-x86_64</emulator>
          <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2' cache='writeback' io='threads'/>
            <source file='/var/lib/libvirt/images/whonix-gw.qcow2'/>
            <target dev='vda' bus='virtio'/>
          </disk>
          <!-- External NIC — Tor connects outbound through this -->
          <interface type='network'>
            <mac address='52:54:00:a1:b2:c3'/>
            <source network='default'/>
            <model type='virtio'/>
            <driver name='vhost'/>
          </interface>
          <!-- Internal NIC — connected to virbr-whonix -->
          <interface type='bridge'>
            <mac address='52:54:00:d4:e5:f6'/>
            <source bridge='virbr-whonix'/>
            <model type='virtio'/>
          </interface>
          <serial type='pty'><target type='isa-serial' port='0'/></serial>
          <console type='pty'><target type='serial' port='0'/></console>
          <!-- Minimal SPICE display — local only, no clipboard bridge -->
          <video>
            <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1'/>
          </video>
          <graphics type='spice' autoport='yes' listen='127.0.0.1'>
            <listen type='address' address='127.0.0.1'/>
            <image compression='off'/>
          </graphics>
          <memballoon model='virtio'/>
          <rng model='virtio'>
            <backend model='random'>/dev/urandom</backend>
          </rng>
        </devices>
      </domain>
    '';
  };

  environment.etc."libvirt/qemu/whonix-ws.xml" = {
    mode = "0640";
    text = ''
      <domain type='kvm'>
        <name>whonix-ws</name>
        <uuid>bbbbbbbb-0002-0002-0002-bbbbbbbbbbbb</uuid>
        <memory unit='MiB'>2048</memory>
        <currentMemory unit='MiB'>2048</currentMemory>
        <vcpu placement='static'>2</vcpu>
        <os firmware='efi'>
          <type arch='x86_64' machine='q35'>hvm</type>
          <boot dev='hd'/>
        </os>
        <features>
          <acpi/><apic/>
          <kvm><hidden state='on'/></kvm>
        </features>
        <cpu mode='host-passthrough' check='none' migratable='on'/>
        <clock offset='utc'>
          <timer name='rtc' tickpolicy='catchup'/>
          <timer name='hpet' present='no'/>
          <timer name='tsc' present='no'/>
        </clock>
        <devices>
          <emulator>/run/current-system/sw/bin/qemu-system-x86_64</emulator>
          <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2' cache='writeback' io='threads'/>
            <source file='/var/lib/libvirt/images/whonix-ws.qcow2'/>
            <target dev='vda' bus='virtio'/>
          </disk>
          <!-- Only NIC: virbr-whonix. All traffic → GW → Tor -->
          <interface type='bridge'>
            <mac address='52:54:00:11:22:33'/>
            <source bridge='virbr-whonix'/>
            <model type='virtio'/>
          </interface>
          <serial type='pty'><target type='isa-serial' port='0'/></serial>
          <console type='pty'><target type='serial' port='0'/></console>
          <video>
            <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1'/>
          </video>
          <graphics type='spice' autoport='yes' listen='127.0.0.1'>
            <listen type='address' address='127.0.0.1'/>
            <image compression='off'/>
          </graphics>
          <memballoon model='virtio'/>
          <rng model='virtio'>
            <backend model='random'>/dev/urandom</backend>
          </rng>
        </devices>
      </domain>
    '';
  };

  # ── Provision service: define + autostart both VMs once libvirtd is up ─────
  systemd.services.whonix-vm-provision = {
    description = "Define and autostart Whonix VMs in libvirt";
    wantedBy = ["multi-user.target"];
    after = ["libvirtd.service" "whonix-bridge.service"];
    requires = ["libvirtd.service" "whonix-bridge.service"];
    path = [pkgs.libvirt];
    script = ''
      set -euo pipefail
      for vm in whonix-gw whonix-ws; do
        if ! virsh --connect qemu:///system dominfo "$vm" &>/dev/null; then
          echo "[whonix-provision] Defining $vm..."
          virsh --connect qemu:///system define /etc/libvirt/qemu/$vm.xml
        fi
      done
      # GW autostarts; WS is started manually or with `wx`.
      virsh --connect qemu:///system autostart whonix-gw
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
