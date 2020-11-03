{ config, pkgs, lib, secrets, hmlib, ... }: with lib;
let
  gnome-vm-config = { config, pkgs, ... }: {
    environment.systemPackages = with pkgs; [ teams ];
    networking.firewall.enable = false;
    networking.hostName = "gnome-eivd";
    nixpkgs.config.allowUnfree = true;  # :(
    security.sudo.enable = true;
    security.sudo.wheelNeedsPassword = false;
    services = {
      openssh.enable = true;
      openssh.forwardX11 = true;
      xserver.enable = true;
      xserver.desktopManager.gnome3.enable = true;
      xserver.displayManager.gdm.enable = true;
      xserver.displayManager.autoLogin.enable = true;
      xserver.displayManager.autoLogin.user = "roos";
    };
    users.users.roos = {
      uid = 1000;
      password = "roos";  # FIXME
      isNormalUser = true;
      extraGroups = [ "input" "wheel" ];
    };
  };
in {
  options.roos.eivd.enable =
    mkEnableOption "Stuff required during my studies at HEIG-VD";

  config = mkIf config.roos.eivd.enable {
    networking.bridges.containers.interfaces = [];
    networking.bridges.containers.rstp = true;

    containers."eivd-mysql" = {
      bindMounts.eivd-mysql-data.mountPoint = "/var/lib/mysql";
      bindMounts.eivd-mysql-data.hostPath = "/var/lib/eivd-mysql/mysql";
      bindMounts.eivd-mysql-data.isReadOnly = false;
      config = {
        services.mysql.enable = true;
        services.mysql.package = pkgs.mariadb;
      };
      ephemeral = true;
      hostBridge = "containers";
      privateNetwork = true;
    };

    roos.sConfig = {
      home.packages = with pkgs; [
        # POO1
        (maven.override { jdk = openjdk14; })
        openjdk14
      ];
    };

    roos.gConfig = {
      home.packages = with pkgs; [ teams ];
    };

    roos.gConfigFn = userCfg: let
      vm-images-dir = "${userCfg.xdg.dataHome}/vms";
      gnome-eivd-virtualisation-settings = {
        memorySize = 2048;
        diskImage = "${vm-images-dir}/gnome-eivd.qcow2";
        graphics = false;  # Disable default graphics options
        cores = 4;
        qemu.options = [
          "-chardev spicevmc,id=vdagent,name=vdagent"
          "-chardev stdio,mux=on,id=char0,signal=off"
          "-device virtio-serial"
          "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
          "-mon chardev=char0,mode=readline"  # Monitor -> mux
          "-serial chardev:char0"  # Serial console -> mux
          "-vga cirrus"
          "-spice port=5900,addr=localhost,disable-ticketing"
        ];
      };
      gnome-vm = import (<nixpkgs/nixos/lib/eval-config.nix>) {
        system = pkgs.system;
        modules = [
          gnome-vm-config
          { config.virtualisation = gnome-eivd-virtualisation-settings; }
          <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
        ];
      };
    in {
      home.packages = [ gnome-vm.config.system.build.vm ];
      home.activation.vms = 
      let tooldir = "${pkgs.ensure-nodatacow-btrfs-subvolume}/bin";
      in hmlib.dag.entryBetween
        [ "linkGeneration" ] [ "installPackages" ] ''
          "${tooldir}/ensure-nodatacow-btrfs-subvolume" "${vm-images-dir}"
        '';
    };

    systemd.services.eivd-mysql = {
      description = "Prepare paths used by MySQL in the eivd container.";
      requiredBy = [ "container@eivd-mysql.service" ];
      before = [ "container@eivd-mysql.service" ];
      path = with pkgs; [
        btrfs-progs
        e2fsprogs
        gawk
        utillinux
      ];
      environment.TARGET = "/var/lib/eivd-mysql/mysql";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let tool = "${pkgs.ensure-nodatacow-btrfs-subvolume}";
        in "${tool}/bin/ensure-nodatacow-btrfs-subvolume";
      };
    };
  };
}
