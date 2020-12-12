{ config, lib, pkgs, secrets, nixosSystem, ... }:
let
  base = {...}: {
    imports = [ ./base.nix ];
    services.sshd.enable = true;
    networking.firewall.enable = false;
  };

  nestedVMs = {config, ...}: {
    options.vms = with lib.options; mkOption {
      default = {};
      type = lib.types.attrs;
      description = "VMs to provision with their configuration.";
    };

    config = with lib; let
      mkVm = hostname: configuration: (nixosSystem {
        system = "x86_64-linux";
        modules = [({ ... }: {
          imports = [ base configuration ];
          networking.hostName = hostname;
          virtualisation.qemu.networkingOptions = [
            "-nic bridge,id=n1,br=vms,model=virtio"
          ];
        })];
      }).config.system.build.vm;
    in mkIf (config.vms != {}) {
      environment.etc."qemu/bridge.conf".text = "allow vms";
      systemd.services = mapAttrs' (name: cfg: nameValuePair "vm@${name}" {
        script = "${mkVm name cfg}/bin/run-${name}-vm";
        serviceConfig.Restart = "on-failure";
        serviceConfig.Slice = "machine.slice";
        wantedBy = [ "machines.target" ];
        wants = [ "network.target" ];
        after = [ "network.target" ];
        restartIfChanged = true;
      }) config.vms;
    };
  };
in
{
  imports = [ base nestedVMs ];

  boot.kernel.sysctl."net.ipv6.conf.vms.forwarding" = 1;

  networking.bridges.vms.interfaces = [];
  networking.interfaces.vms.ipv6.addresses = [
    { address = "2001:db8::1"; prefixLength = 48; }
  ];
  networking.hostName = "batman-hyp";
  networking.interfaces.eth0.useDHCP = true;
  networking.useDHCP = false;

  services.radvd.enable = true;
  services.radvd.config = ''
    interface vms {
      AdvSendAdvert on;
      prefix 2001:db8::/64;
    };
  '';

  virtualisation.memorySize = 1024;
  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::60022-:22"
  ];

  vms = {
    foo = { };
    bar = { };
    baz = { };
  };
}
