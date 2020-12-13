{ config, lib, pkgs, secrets, nixosSystem, home-manager, ... }:
let
  base = {...}: {
    imports = [ ./base.nix ];
    services.sshd.enable = true;
    #networking.firewall.enable = false;
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
          imports = [ base home-manager ../../modules configuration ];
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

  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

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

  vms = let
    network = {
      foo = {
        ipv6 = [ { address = "fdf1::1"; prefixLength = 128; } ];
        addr = "foo";
        peeringport = 12913;
        keys = {
          private = "oGJb4BGu0RszZqjiP0rGKq7UMw3ezEPmuoYcgmXiQGQ=";
          public = "3isW0b/MOb9CIGluevGUNnXzfLv3qTtG795HnlGmaXw=";
        };
      };
      bar = {
        ipv6 = [ { address = "fdf2::1"; prefixLength = 128; } ];
        addr = "bar";
        peeringport = 12914;
        keys = {
          private = "QK/uo2fPmNFDgXT+FoMlTR+OzvovjWAT30z7aUI7PkQ=";
          public = "Emd5dTlYBI8lekywF//bEWHn/Yr+Ljoffik1POW1xVI=";
        };
      };
      baz = {
        ipv6 = [ { address = "fdf3::1"; prefixLength = 128; } ];
        addr = "baz";
        peeringport = 12915;
        keys = {
          private = "+Io7dND17QTHyGLHndyLvQQ8q1b0fvnXGz7o2i95s0E=";
          public = "5vtgp8LBkLubNXQWomKEm8nmf2q1XlVlS0ETBOVfwSI=";
        };
      };
    };
  in {
    foo = {
      roos.wireguard-new.core-net.network = network;
    };
    bar = {
      roos.wireguard-new.core-net.network = network;
    };
    baz = {
      roos.wireguard-new.core-net.network = network;
    };
  };
}
