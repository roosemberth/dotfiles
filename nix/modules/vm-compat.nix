# Compatibility layer to allow building a system derivation on a vm.
# This is needed because not all config options are compatible with a VM.
#
# More importantly, this file should not be imported from the system
# derivation.
{ lib, modulesPath, ... }: with lib;
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  config = {
    programs.sway.extraSessionCommands = ''
      export WLR_RENDERER_ALLOW_SOFTWARE=1
    '';

    # Fails assertion because of missing btrfs filesystems
    services.btrfs.autoScrub.enable = mkVMOverride false;

    # Avoid mishaphs
    roos.wireguard.enable = mkVMOverride false;

    virtualisation.qemu.options = [
      "-device virtio-balloon-pci,id=balloon0,bus=pci.0"
      "-chardev stdio,mux=on,id=char0,signal=off"
      "-mon chardev=char0,mode=readline"
      "-serial chardev:char0"
      "-snapshot"
      "-vga cirrus"
    ];
  };
}
