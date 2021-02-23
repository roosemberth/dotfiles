{ config, lib, pkgs, secrets, modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  environment.etc."systemd/network/00-random-mac.link".text = ''
    [Match]
    OriginalName=*

    [Link]
    MACAddressPolicy=random
  '';

  fileSystems."/boot" = { fsType = "vfat"; device = "/dev/sda1"; };
  fileSystems."/".device = "/dev/sda2";

  networking.firewall.allowedUDPPorts = [ 5355 ];
  networking.interfaces.eth0.useDHCP = true;
  networking.useDHCP = false;
  networking.useNetworkd = true;

  nix.package = pkgs.nixUnstable;
  nix.trustedUsers = [ "roos" ];

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  services.journald.console = "/dev/ttyS0";
  services.mingetty.autologinUser = "roos";
  systemd.coredump.enable = true;
  security.pam.loginLimits = [{
    domain = "*"; item = "core"; type = "-"; value = "-1";
  }];

  users.mutableUsers = false;
  users.extraUsers.roos.password = "roos";
  users.extraUsers.roos.isNormalUser = true;
  users.extraUsers.roos.extraGroups = ["wheel"];

  virtualisation.qemu.options = [
    "-device virtio-balloon-pci,id=balloon0,bus=pci.0"
    "-chardev stdio,mux=on,id=char0,signal=off"
    "-mon chardev=char0,mode=readline"
    "-serial chardev:char0"
    "-snapshot"
    "-nographic"
  ];
}
