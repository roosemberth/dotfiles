{ config, pkgs, lib, ... }:
let
  secrets = import ../secrets.nix { inherit lib; };
in
{
  imports = [
    ./Dvergr-static.nix
    ../modules
    ../lib
  ];

  boot.cleanTmpDir = true;
  boot.kernelModules = [ "kvm-intel" ];
  environment.systemPackages = (with pkgs; [
    cacert curl git hdparm htop iotop tmux vim wget
    python37Packages.glances
  ]);

  hardware = {
    bluetooth.enable = true;
    bluetooth.package = pkgs.bluezFull;
    pulseaudio.enable = true;
    pulseaudio.extraModules = [ pkgs.pulseaudio-modules-bt ];
    pulseaudio.package = pkgs.pulseaudioFull;

    cpu.intel.updateMicrocode = true;

    opengl.enable = true;
    opengl.extraPackages = with pkgs; [ vaapiIntel vaapiVdpau libvdpau-va-gl intel-media-driver ];
  };

  # Enable YAMA restrictions
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;

  networking.hostName = "Dvergr";
  roos = {
    dvergr.network.enable = true;
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      packageOverrides = pkgs: {
        vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
        mymopidy = with pkgs; buildEnv {
          name = "mopidy-with-extensions-${mopidy.version}";
          paths = lib.closePropagation (with pkgs; [mopidy-spotify mopidy-iris]);
          pathsToLink = [ "/${python.sitePackages}" ];
          buildInputs = [ makeWrapper ];
          postBuild = ''
            makeWrapper ${mopidy}/bin/mopidy $out/bin/mopidy \
            --prefix PYTHONPATH : $out/${python.sitePackages}
          '';
        };
      };
    };
  };

  programs = {
    bash.enableCompletion = true;
    mtr.enable = true;
  };

  security.sudo.enable = true;

  environment.variables = {
    XDG_CACHE_HOME="\${HOME}/.local/var/cache";
    XDG_CONFIG_HOME="\${HOME}/.local/etc";
    XDG_DATA_HOME="\${HOME}/.local/var/lib";
    XDG_LIB_HOME="\${HOME}/.local/lib";
    XDG_LOG_HOME="\${HOME}/.local/var/log";

    GNUPGHOME="\${XDG_DATA_HOME}/gnupg/";
    ZDOTDIR="\${XDG_CONFIG_HOME}/zsh/default";
  };

  services = {
    logind.extraConfig = "HandlePowerKey=ignore";
    nginx.enable = true;
    nginx.virtualHosts = {
      localhost.default = true;
      # Default redirect to HTTPs (e.g. socat rec.la testing).
      localhost.extraConfig = "return 301 https://$host$request_uri;";

      "dvergr.r.orbstheorem.ch" = {
        root = "/Storage/tmp/shared/";
        locations."/".extraConfig =
          "return 307 /public-web/;";
        locations."/public-web".extraConfig = "autoindex on;";
      };
    };
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    postgresql = {
      enable = true;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        local all all trust
        host all all ::1/128 trust
        host all all 10.13.255.0/24 trust
      '';
    };
  };

  system = {
    stateVersion = "19.09";
    autoUpgrade.enable = true;
  };

  time.timeZone = "Europe/Zurich";

  users = {
    mutableUsers = false;
    users.roosemberth = {
      uid = 1000;
      description = "Roosemberth Palacios";
      hashedPassword = secrets.users.roosemberth.hashedPassword;
      isNormalUser = true;
      extraGroups = ["docker" "libvirtd" "networkmanager" "wheel"];
      openssh.authorizedKeys.keys = [ secrets.users.roosemberth.sshPubKey ];
      packages = with pkgs; ([
      ] ++ [ # Nix
        nix-bundle nix-index nix-prefetch-scripts nix-zsh-completions
      ] ++ [ # Media
        beets mpc_cli mpd ncmpcpp pamix pavucontrol
      ] ++ [ # Core & utils
        entr nmap screen socat stow tcpdump openssl ranger
        nethogs cpufrequtils lsof pciutils usbutils
        file docker moreutils
      ] ++ [ # Other
        zip unzip jq khal tree pv fortune
        bluez taskwarrior timewarrior gnupg pass-otp zsh-completions
      ]);
      shell = pkgs.zsh;
    };
    motd = with config; ''
      Welcome to ${networking.hostName}

      - This machine is managed by NixOS
      - All changes are futile

      OS:      NixOS ${system.nixos.release} (${system.nixos.codeName})
      Version: ${system.nixos.version}
      Kernel:  ${boot.kernelPackages.kernel.version}
    '';
  };

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
}
