{ config, lib, pkgs, secrets, nixosSystem, ... }:
let
  netopts-script = pkgs.writeShellScript "get-qemu-batman-network-opts" ''
    SOCKET_NET_PORT=57300
    declare -a NETWORK_OPTS
    NETWORK_OPTS+=(-nic hubport,hubid=1,id=n1,model=virtio)
    if ! ${pkgs.iproute}/bin/ss -an \
        | grep -qE 'tcp.*LISTEN.*:'"$SOCKET_NET_PORT"'\s'; then
      # Start first instance
      NETWORK_OPTS+=(-netdev socket,id=netsock,listen=:"$SOCKET_NET_PORT")
      NETWORK_OPTS+=(-netdev hubport,id=h0,hubid=1,netdev=netsock)

      # Connect a hub to the user network for DHCP, TFTP, ...
      NETWORK_OPTS+=(-netdev user,id=m1,tftp=.,hostfwd=::9001-:9000)
      NETWORK_OPTS+=(-netdev hubport,id=h1,hubid=1,netdev=m1)
    else
      # Start subordinate instance
      NETWORK_OPTS+=(-netdev socket,id=netsock,connect=localhost:"$SOCKET_NET_PORT")
      NETWORK_OPTS+=(-netdev hubport,id=h0,hubid=1,netdev=netsock)
    fi
    echo "''${NETWORK_OPTS[@]}"
  '';
  mkVm = hostname: configuration: (nixosSystem {
    system = "x86_64-linux";
    modules = [({ ... }: {
      imports = [ ./base.nix configuration ];
      networking.hostName = hostname;
      virtualisation.qemu.networkingOptions = [ "$(${netopts-script})" ];
    })];
  }).config.system.build.vm;

  vmsModule = {config, ...}: {
    options.vms = with lib.options; mkOption {
      default = {};
      type = lib.types.attrs;
      description = "VMs to provision with their configuration.";
    };

    config = with lib; {
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
  imports = [ ./base.nix vmsModule ];
  virtualisation.memorySize = 1024;
  vms = {
    foo = {};
    bar = {};
    baz = {};
  };
}
